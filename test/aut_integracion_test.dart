// Prácticas 13 y 14 · Pruebas de integración entre componentes de la app (AUT-04, AUT-05).
//
// Aquí no se simula el cliente HTTP: la cadena real de la app
//   ApiRepository → FitPulseApi → ApiClient → package:http → socket TCP
// habla con un servidor HTTP de verdad levantado en 127.0.0.1 dentro de la prueba,
// que responde como la API de FitPulse (o falla a propósito). Así se valida lo que
// viaja por la red (método, ruta, encabezados, JSON), cómo se interpreta la respuesta
// y que el token quede guardado (LocalStore).
//
// La prueba contra la API real (Node + MariaDB) está en api_real_test.dart y la
// ejecuta la integración continua.
import 'dart:convert';
import 'dart:io';

import 'package:fitpulse_mobile/api/api_client.dart';
import 'package:fitpulse_mobile/api/fitpulse_api.dart';
import 'package:fitpulse_mobile/data/repository.dart';
import 'package:fitpulse_mobile/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// Servidor HTTP mínimo en un puerto libre de 127.0.0.1.
class FakeApi {
  late HttpServer _server;
  final requests = <({String method, String path, Map<String, String> headers, Object? body})>[];
  Future<void> Function(HttpRequest req, Object? body)? handler;

  String get baseUrl => 'http://127.0.0.1:${_server.port}/api';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((req) async {
      final raw = await utf8.decodeStream(req);
      final body = raw.isEmpty ? null : jsonDecode(raw);
      final headers = <String, String>{};
      req.headers.forEach((k, v) => headers[k] = v.join(','));
      requests.add((method: req.method, path: req.uri.path, headers: headers, body: body));
      await handler!(req, body);
    });
  }

  Future<void> stop() => _server.close(force: true);
}

Future<void> reply(HttpRequest req, int status, Object? json) async {
  req.response.statusCode = status;
  req.response.headers.contentType = ContentType.json;
  if (json != null) req.response.write(jsonEncode(json));
  await req.response.close();
}

void main() {
  late FakeApi server;

  setUp(() async {
    server = FakeApi();
    await server.start();
  });
  tearDown(() => server.stop());

  test('AUT-04 la app envía el inicio de sesión al servicio, recibe una respuesta válida y guarda el token', () async {
    server.handler = (req, body) => reply(req, 200, {
          'token': 'jwt-de-prueba',
          'user': {'id': 'u1', 'name': 'Ana López', 'email': 'ana@correo.com'},
        });
    final store = LocalStore.memory();
    final repo = ApiRepository(FitPulseApi(ApiClient(baseUrl: server.baseUrl)), store);

    final user = await repo.login('  ANA@correo.com ', 'fitpulse123');

    final r = server.requests.single;
    expect(r.method, 'POST');
    expect(r.path, '/api/auth/login');
    expect(r.headers['content-type'], contains('application/json'));
    expect(r.body, {'email': 'ana@correo.com', 'password': 'fitpulse123'}, reason: 'correo normalizado antes de enviarlo');
    expect(user.email, 'ana@correo.com');
    expect(store.token, 'jwt-de-prueba', reason: 'token persistido para la siguiente apertura');
  });

  test('AUT-04 las solicitudes siguientes llevan el token y la zona horaria del teléfono', () async {
    server.handler = (req, body) => req.uri.path == '/api/auth/login'
        ? reply(req, 200, {'token': 'jwt-2', 'user': {'id': 'u1', 'name': 'Ana', 'email': 'ana@correo.com'}})
        : reply(req, 200, [
            {'id': 's1', 'type': 'running', 'started_at': '2026-11-17T14:00:00.000Z', 'duration_sec': 1800, 'distance_km': 5, 'calories': 300},
          ]);
    final api = FitPulseApi(ApiClient(baseUrl: server.baseUrl));
    final repo = ApiRepository(api, LocalStore.memory());
    await repo.login('ana@correo.com', 'fitpulse123');
    final sessions = await repo.sessions();

    final get = server.requests.last;
    expect(get.path, '/api/sessions');
    expect(get.headers['authorization'], 'Bearer jwt-2');
    expect(get.headers['x-timezone-offset'], isNotNull);
    expect(sessions.single.km, 5);
  });

  test('AUT-05 contraseña incorrecta: la API responde 401 y la app muestra su mensaje sin cerrar otra sesión', () async {
    var expired = 0;
    server.handler = (req, body) => reply(req, 401, {'error': 'Correo o contraseña incorrectos'});
    final client = ApiClient(baseUrl: server.baseUrl)..onUnauthorized = () => expired++;
    final repo = ApiRepository(FitPulseApi(client), LocalStore.memory());

    await expectLater(repo.login('ana@correo.com', 'mala-clave'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401).having((e) => e.message, 'message', 'Correo o contraseña incorrectos')));
    expect(expired, 0, reason: 'un 401 en /auth no es una sesión vencida');
  });

  test('AUT-05 el servidor no responde: la app corta a tiempo con un mensaje claro', () async {
    server.handler = (req, body) async {
      await Future<void>.delayed(const Duration(seconds: 3)); // nunca a tiempo
      await reply(req, 200, {});
    };
    final client = ApiClient(baseUrl: server.baseUrl, timeout: const Duration(milliseconds: 400));
    final sw = Stopwatch()..start();
    await expectLater(client.get('/sessions'), throwsA(isA<ApiException>()
        .having((e) => e.timedOut, 'timedOut', true)
        .having((e) => e.message, 'message', 'El servidor tardó demasiado en responder. Intenta de nuevo.')));
    expect(sw.elapsedMilliseconds, lessThan(2500), reason: 'no espera la respuesta tardía');
  });

  test('AUT-05 servidor apagado (conexión rechazada): error de red controlado', () async {
    final url = server.baseUrl;
    await server.stop();
    final client = ApiClient(baseUrl: url, retry: RetryPolicy.none);
    await expectLater(client.get('/health'), throwsA(isA<ApiException>()
        .having((e) => e.isNetwork, 'isNetwork', true)
        .having((e) => e.message, 'message', 'No se pudo conectar con el servidor. Revisa tu conexión.')));
    server = FakeApi();
    await server.start(); // para el tearDown
  });

  test('AUT-05 un 503 pasajero se reintenta y la escritura con clave no se duplica', () async {
    var calls = 0;
    server.handler = (req, body) {
      calls++;
      return calls == 1 ? reply(req, 503, {'error': 'reiniciando'}) : reply(req, 201, {'id': 'srv-1', 'type': 'running'});
    };
    final client = ApiClient(baseUrl: server.baseUrl, sleep: (_) async {});
    final res = await FitPulseApi(client).createSession({'type': 'running', 'duration_sec': 600}, idempotencyKey: 'clave-aut05-1');

    expect(res['id'], 'srv-1');
    expect(server.requests.length, 2);
    expect(server.requests.map((r) => r.headers['idempotency-key']).toSet(), {'clave-aut05-1'});
  });
}
