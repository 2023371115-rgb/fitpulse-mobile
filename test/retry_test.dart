// Práctica 12 · Reintento con espera progresiva (exponential backoff) e idempotencia en ApiClient.
//
// Se usa un servidor simulado (MockClient) y un "sleep" falso que solo anota las esperas,
// así las pruebas son instantáneas y deterministas.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fitpulse_mobile/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

typedef Responder = Future<http.Response> Function(http.Request req, int n);

({ApiClient api, List<Duration> waits, List<http.Request> calls}) client(Responder respond, {RetryPolicy retry = const RetryPolicy()}) {
  final waits = <Duration>[];
  final calls = <http.Request>[];
  final api = ApiClient(
    baseUrl: 'http://fitpulse.test/api',
    httpClient: MockClient((req) {
      calls.add(req);
      return respond(req, calls.length);
    }),
    retry: retry,
    sleep: (d) async => waits.add(d),
    random: Random(1),
  );
  return (api: api, waits: waits, calls: calls);
}

http.Response json(Object body, int status) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  group('R1 política de espera (exponential backoff con jitter)', () {
    test('cada espera duplica la anterior, ±25 %, con tope en maxDelay', () {
      const p = RetryPolicy(baseDelay: Duration(milliseconds: 400), maxDelay: Duration(seconds: 4));
      final rnd = Random(7);
      for (final (attempt, base) in [(1, 400), (2, 800), (3, 1600), (4, 3200), (5, 4000), (6, 4000)]) {
        final ms = p.delay(attempt, rnd).inMilliseconds;
        expect(ms, inInclusiveRange((base * 0.75).floor(), (base * 1.25).ceil()), reason: 'intento $attempt');
      }
    });
  });

  group('R2 GET se reintenta ante fallos transitorios', () {
    test('503, 502 y luego 200 → éxito con 2 reintentos y esperas crecientes', () async {
      final c = client((req, n) async => n == 1 ? json({}, 503) : n == 2 ? json({}, 502) : json({'ok': true}, 200));
      final r = await c.api.get('/sessions');
      expect(r, {'ok': true});
      expect(c.calls.length, 3);
      expect(c.waits.length, 2);
      expect(c.waits[1] > c.waits[0], isTrue);
      expect(c.api.retries, 2);
    });

    test('sin conexión (SocketException) y luego 200 → se recupera solo (RES-06)', () async {
      final c = client((req, n) async => n == 1 ? throw const SocketException('sin red') : json([], 200));
      expect(await c.api.get('/sessions'), []);
      expect(c.calls.length, 2);
    });

    test('si el fallo persiste se rinde tras maxRetries y muestra el error (RES-04)', () async {
      final c = client((req, n) async => json({'error': 'db'}, 500));
      await expectLater(c.api.get('/sessions'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 500)));
      expect(c.calls.length, 4); // 1 + 3 reintentos
    });

    test('no se pasa del presupuesto total de espera', () async {
      final c = client((req, n) async => json({}, 503), retry: const RetryPolicy(maxRetries: 10, budget: Duration(seconds: 3)));
      await expectLater(c.api.get('/x'), throwsA(isA<ApiException>()));
      final total = c.waits.fold(Duration.zero, (a, b) => a + b);
      expect(total <= const Duration(seconds: 3), isTrue, reason: 'esperó $total');
    });

    test('401 no se reintenta y avisa que la sesión expiró (RES-05)', () async {
      var expired = 0;
      final c = client((req, n) async => json({'error': 'invalid token'}, 401));
      c.api
        ..token = 'viejo'
        ..onUnauthorized = () => expired++;
      await expectLater(c.api.get('/sessions'), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)));
      expect(c.calls.length, 1);
      expect(expired, 1);
    });

    test('403 y 404 no se reintentan', () async {
      for (final code in [403, 404, 400]) {
        final c = client((req, n) async => json({'error': 'no'}, code));
        await expectLater(c.api.get('/admin'), throwsA(isA<ApiException>()));
        expect(c.calls.length, 1, reason: 'HTTP $code');
      }
    });

    test('timeout no se reintenta: el error se muestra a los 15 s y no a los 60 (RES-03)', () async {
      final api = ApiClient(baseUrl: 'http://x/api', httpClient: MockClient((r) => Future.delayed(const Duration(milliseconds: 200), () => json({}, 200))),
          timeout: const Duration(milliseconds: 20), sleep: (d) async {});
      await expectLater(api.get('/sessions'), throwsA(isA<ApiException>().having((e) => e.timedOut, 'timedOut', true)));
      expect(api.retries, 0);
    });
  });

  group('R3 escrituras: solo se reintentan con Idempotency-Key (RES-02 / RES-07)', () {
    test('POST sin clave NO se reintenta (podría duplicar el registro)', () async {
      final c = client((req, n) async => n == 1 ? throw const SocketException('se cayó') : json({'id': 'x'}, 201));
      await expectLater(c.api.post('/tickets', {'title': 'a'}), throwsA(isA<ApiException>()));
      expect(c.calls.length, 1);
    });

    test('POST con clave se reintenta y manda la MISMA clave en cada intento', () async {
      final c = client((req, n) async => n < 3 ? json({}, 502) : json({'id': 's1'}, 201));
      final r = await c.api.post('/sessions', {'type': 'running'}, 'clave-123456');
      expect(r, {'id': 's1'});
      expect(c.calls.map((r) => r.headers['Idempotency-Key']).toSet(), {'clave-123456'});
      expect(c.calls.length, 3);
    });

    test('409 "en proceso" se espera y reintenta; la respuesta repetida trae el mismo registro (RES-08)', () async {
      final c = client((req, n) async => n == 1
          ? json({'error': 'en proceso', 'code': 'IDEMPOTENCY_IN_PROGRESS'}, 409)
          : http.Response(jsonEncode({'ticket': {'id': 't1'}}), 201, headers: {'idempotent-replayed': 'true'}));
      final r = await c.api.post('/tickets', {'title': 'a'}, 'clave-abcdef');
      expect(r, {'ticket': {'id': 't1'}});
      expect(c.calls.length, 2);
    });

    test('un 409 que no es de idempotencia no se reintenta', () async {
      final c = client((req, n) async => json({'error': 'ya existe'}, 409));
      await expectLater(c.api.post('/auth/register', {'email': 'a'}, 'clave-abcdef'), throwsA(isA<ApiException>()));
      expect(c.calls.length, 1);
    });

    test('las claves nuevas son únicas y con formato aceptado por el servidor', () {
      final keys = List.generate(200, (_) => ApiClient.newIdempotencyKey());
      expect(keys.toSet().length, 200);
      expect(keys.every((k) => RegExp(r'^[A-Za-z0-9_-]{8,80}$').hasMatch(k)), isTrue);
    });
  });
}
