// Práctica 11 · Pruebas white box de la aplicación móvil.
//
// Cada grupo prueba un método crítico. Los casos salen de su grafo de flujo de
// control (caminos independientes), de la cobertura de condiciones y de valores
// límite. Los identificadores (P1, C1, L1...) son los mismos del reporte.
//
//   flutter test --coverage --branch-coverage test/whitebox_test.dart
import 'dart:convert';
import 'dart:io';

import 'package:fitpulse_mobile/api/api_client.dart';
import 'package:fitpulse_mobile/utils/format.dart';
import 'package:fitpulse_mobile/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Cliente de prueba: responde lo que indique [handler] y guarda la última petición.
class _Recorder {
  http.Request? last;
  MockClient client(Future<http.Response> Function(http.Request r) handler) => MockClient((r) {
        last = r;
        return handler(r);
      });
}

http.Response _json(Object body, int status) =>
    http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json'});

Matcher _apiError({int? status, String? message}) => isA<ApiException>()
    .having((e) => e.statusCode, 'statusCode', status)
    .having((e) => e.message, 'message', message ?? anything);

void main() {
  // ───────── M1 · Validators.range (validación) ─────────
  group('M1 Validators.range', () {
    // Caminos independientes (V(G) = 4)
    test('P1 opcional y vacío → válido (sin más evaluación)', () {
      expect(Validators.range('', 30, 250, 'peso', optional: true), isNull);
    });
    test('P2 texto no numérico → "Escribe tu ..."', () {
      expect(Validators.range('abc', 30, 250, 'peso'), 'Escribe tu peso');
    });
    test('P3 número fuera de rango → "Valor entre ..."', () {
      expect(Validators.range('20', 30, 250, 'peso'), 'Valor entre 30 y 250');
    });
    test('P4 número dentro del rango → válido', () {
      expect(Validators.range('70', 30, 250, 'peso'), isNull);
    });

    // Cobertura de condiciones: cada condición atómica toma verdadero y falso
    test('C1 optional=true, vacío solo con espacios=true', () {
      expect(Validators.range('   ', 30, 250, 'peso', optional: true), isNull);
    });
    test('C2 optional=true, vacío=false → se valida el número', () {
      expect(Validators.range('300', 30, 250, 'peso', optional: true), 'Valor entre 30 y 250');
    });
    test('C3 optional=false (no se evalúa vacío) y campo vacío → obligatorio', () {
      expect(Validators.range('', 1000, 50000, 'meta'), 'Escribe tu meta');
    });
    test('C4 n < lo verdadero / n > hi verdadero / ambos falsos', () {
      expect(Validators.range('29', 30, 250, 'peso'), isNotNull);
      expect(Validators.range('251', 30, 250, 'peso'), isNotNull);
      expect(Validators.range('31', 30, 250, 'peso'), isNull);
    });
    test('C5 valor nulo (v == null) se trata como vacío', () {
      expect(Validators.range(null, 30, 250, 'peso', optional: true), isNull);
      expect(Validators.range(null, 30, 250, 'peso'), 'Escribe tu peso');
    });

    // Valores límite
    test('L1 límites exactos son válidos (30 y 250)', () {
      expect(Validators.range('30', 30, 250, 'peso'), isNull);
      expect(Validators.range('250', 30, 250, 'peso'), isNull);
    });
    test('L2 justo fuera de los límites (29.99 y 250.01)', () {
      expect(Validators.range('29.99', 30, 250, 'peso'), 'Valor entre 30 y 250');
      expect(Validators.range('250.01', 30, 250, 'peso'), 'Valor entre 30 y 250');
    });
    test('L3 decimal con dos puntos no es número', () {
      expect(Validators.range('70.5.1', 30, 250, 'peso'), 'Escribe tu peso');
    });
    test('L4 espacios alrededor de un número válido', () {
      expect(Validators.range(' 70 ', 30, 250, 'peso'), isNull);
    });
    test('D-08 "NaN" no debería aceptarse como número', () {
      expect(Validators.range('NaN', 30, 250, 'peso'), isNotNull);
    }, skip: 'Defecto D-08: num.tryParse("NaN") devuelve NaN y ninguna comparación con NaN es verdadera');
  });

  group('M1b Validators.email / password / passwordScore', () {
    test('email: vacío, largo, formato inválido y válido', () {
      expect(Validators.email(null), 'Escribe tu correo electrónico');
      expect(Validators.email('   '), 'Escribe tu correo electrónico');
      expect(Validators.email('${'a' * 110}@correo.com'), 'Máximo 120 caracteres');
      expect(Validators.email('ana@correo'), 'Correo no válido');
      expect(Validators.email('ana correo@x.com'), 'Correo no válido');
      expect(Validators.email(' ana@correo.com '), isNull);
    });
    test('email: límite de 120 caracteres', () {
      final at120 = '${'a' * 109}@correo.com'; // 109 + 11 = 120
      expect(at120.length, 120);
      expect(Validators.email(at120), isNull);
      expect(Validators.email('a$at120'), 'Máximo 120 caracteres');
    });
    test('password: vacío, 7, 8, 72 y 73 caracteres', () {
      expect(Validators.password(null), 'Escribe tu contraseña');
      expect(Validators.password('        '), 'Escribe tu contraseña');
      expect(Validators.password('a' * 7), 'Mínimo 8 caracteres');
      expect(Validators.password('a' * 8), isNull);
      expect(Validators.password('a' * 72), isNull);
      expect(Validators.password('a' * 73), 'Máximo 72 caracteres');
    });
    test('passwordScore: 0 a 4 según los criterios cumplidos', () {
      expect(Validators.passwordScore(''), 0);
      expect(Validators.passwordScore('abcdefgh'), 1);
      expect(Validators.passwordScore('Abcdefgh'), 2);
      expect(Validators.passwordScore('Abcdefg1'), 3);
      expect(Validators.passwordScore('Abcdef1!'), 4);
      expect(Validators.passwordScore('A1!'), 3); // corta pero con mayúscula, número y símbolo
    });
  });

  // ───────── M2 · Fmt.number y Fmt.pace (procesamiento) ─────────
  group('M2 Fmt.number', () {
    test('P1 un dígito: el ciclo corre una vez y nunca pone coma', () => expect(Fmt.number(7), '7'));
    test('P2 tres dígitos: condición (len - i) % 3 == 0 nunca se cumple con i > 0', () => expect(Fmt.number(999), '999'));
    test('P3 cuatro dígitos: una coma', () => expect(Fmt.number(7240), '7,240'));
    test('P4 negativo: rama value < 0', () => expect(Fmt.number(-1500), '-1,500'));
    test('L1 límites 999 → 1000 y millones', () {
      expect(Fmt.number(1000), '1,000');
      expect(Fmt.number(1234567), '1,234,567');
    });
    test('L2 redondeo que agrega un dígito (999.6 → 1,000)', () => expect(Fmt.number(999.6), '1,000'));
    test('L3 cero', () => expect(Fmt.number(0), '0'));
    test('D-09 un negativo que redondea a cero no debería mostrar "-0"', () {
      expect(Fmt.number(-0.4), '0');
    }, skip: 'Defecto D-09: se revisa value < 0 antes de redondear y devuelve "-0"');
  });

  group('M2b Fmt.pace', () {
    // Una decisión con tres condiciones: null || isInfinite || isNaN
    test('C1 null → "--"', () => expect(Fmt.pace(null), '--'));
    test('C2 infinito (distancia 0) → "--"', () => expect(Fmt.pace(double.infinity), '--'));
    test('C3 NaN → "--"', () => expect(Fmt.pace(double.nan), '--'));
    test('P2 ritmo normal 5.866 min/km → 5:52', () => expect(Fmt.pace(5.866), '5:52'));
    test('L1 segundos que redondean a 60 pasan al siguiente minuto', () => expect(Fmt.pace(5.999), '6:00'));
    test('L2 cero y menos de un minuto', () {
      expect(Fmt.pace(0), '0:00');
      expect(Fmt.pace(0.5), '0:30');
    });
  });

  // ───────── M3 · ApiClient._send (comunicación con el servidor) ─────────
  group('M3 ApiClient._send', () {
    late _Recorder rec;
    setUp(() => rec = _Recorder());

    ApiClient client(Future<http.Response> Function(http.Request r) handler, {Duration? timeout}) =>
        ApiClient(baseUrl: 'http://servidor/api//', httpClient: rec.client(handler), timeout: timeout ?? const Duration(seconds: 2));

    test('P1 GET 200 con JSON: devuelve los datos y manda token y zona horaria', () async {
      final api = client((_) async => _json({'ok': true}, 200))..token = 'abc';
      expect(await api.get('/sessions', query: {'limit': '20'}), {'ok': true});
      expect(rec.last!.url.toString(), 'http://servidor/api/sessions?limit=20');
      expect(rec.last!.headers['Authorization'], 'Bearer abc');
      expect(rec.last!.headers.containsKey('X-Timezone-Offset'), isTrue);
    });
    test('P2 POST 201: el cuerpo viaja como JSON y sin token no hay Authorization', () async {
      final api = client((r) async => _json({'id': 'x', 'recibido': jsonDecode(r.body)}, 201));
      final res = await api.post('/tickets', {'title': 'Falla'});
      expect(res['recibido'], {'title': 'Falla'});
      expect(rec.last!.method, 'POST');
      expect(rec.last!.headers.containsKey('Authorization'), isFalse);
    });
    test('P3 PUT, PATCH y DELETE pasan por su rama del switch', () async {
      final api = client((r) async => _json({'m': r.method}, 200));
      expect((await api.put('/x', {}))['m'], 'PUT');
      expect((await api.patch('/x', {}))['m'], 'PATCH');
      expect((await api.delete('/x'))['m'], 'DELETE');
      expect(rec.last!.body, isEmpty); // DELETE sin cuerpo: body == null
    });
    test('P4 respuesta 2xx vacía → null', () async {
      expect(await client((_) async => http.Response('', 204)).delete('/x'), isNull);
    });
    test('P5 respuesta 2xx con JSON inválido o bytes no UTF-8 → null (FormatException)', () async {
      expect(await client((_) async => http.Response('<html>', 200)).get('/x'), isNull);
      expect(await client((_) async => http.Response.bytes([0xff, 0xfe, 0x7b], 200)).get('/x'), isNull);
    });
    test('P6 401 con token en ruta protegida: avisa sesión vencida y usa el mensaje del servidor', () async {
      var avisos = 0;
      final api = client((_) async => _json({'error': 'invalid token'}, 401))
        ..token = 'viejo'
        ..onUnauthorized = () => avisos++;
      await expectLater(api.get('/sessions'), throwsA(_apiError(status: 401, message: 'invalid token')));
      expect(avisos, 1);
    });
    test('P7 401 en /auth/ con token: no cierra la sesión (contraseña incorrecta)', () async {
      var avisos = 0;
      final api = client((_) async => _json({'error': 'Credenciales incorrectas.'}, 401))
        ..token = 'abc'
        ..onUnauthorized = () => avisos++;
      await expectLater(api.post('/auth/login', {}), throwsA(_apiError(status: 401, message: 'Credenciales incorrectas.')));
      expect(avisos, 0);
    });
    test('P8 401 sin token y sin mensaje → mensaje genérico', () async {
      var avisos = 0;
      final api = client((_) async => http.Response('', 401))..onUnauthorized = () => avisos++;
      await expectLater(api.get('/sessions'), throwsA(_apiError(status: 401, message: 'Tu sesión expiró. Vuelve a iniciar sesión.')));
      expect(avisos, 0);
    });
    test('P9 401 con token pero sin onUnauthorized registrado (operador ?.) no falla', () async {
      final api = client((_) async => http.Response('', 401))..token = 'abc';
      await expectLater(api.get('/sessions'), throwsA(_apiError(status: 401)));
    });
    test('P10 500: oculta el detalle técnico del servidor', () async {
      final api = client((_) async => _json({'error': 'ER_PARSE_ERROR near 5.5'}, 500));
      await expectLater(api.get('/sessions'), throwsA(_apiError(status: 500, message: 'Ocurrió un problema en el servidor. Intenta más tarde.')));
    });
    test('P11 4xx con mensaje del servidor (404)', () async {
      await expectLater(client((_) async => _json({'error': 'Sesion no encontrada'}, 404)).get('/sessions/x'),
          throwsA(_apiError(status: 404, message: 'Sesion no encontrada')));
    });
    test('C1 data es Map pero error no es String → mensaje genérico', () async {
      await expectLater(client((_) async => _json({'error': 5}, 400)).get('/x'),
          throwsA(_apiError(status: 400, message: 'No se pudo completar la solicitud.')));
    });
    test('C2 data no es Map (lista) → mensaje genérico', () async {
      await expectLater(client((_) async => _json(['a'], 409)).get('/x'),
          throwsA(_apiError(status: 409, message: 'No se pudo completar la solicitud.')));
    });
    test('L1 límites del rango 2xx: 199 y 300 son error, 200 y 299 éxito', () async {
      expect(await client((_) async => _json({'a': 1}, 200)).get('/x'), {'a': 1});
      expect(await client((_) async => _json({'a': 1}, 299)).get('/x'), {'a': 1});
      await expectLater(client((_) async => _json({}, 199)).get('/x'), throwsA(_apiError(status: 199)));
      await expectLater(client((_) async => _json({}, 300)).get('/x'), throwsA(_apiError(status: 300)));
    });
    test('L2 límite de errores de servidor: 499 muestra el mensaje, 500 no', () async {
      await expectLater(client((_) async => _json({'error': 'Demasiadas solicitudes'}, 499)).get('/x'),
          throwsA(_apiError(status: 499, message: 'Demasiadas solicitudes')));
      await expectLater(client((_) async => _json({'error': 'detalle interno'}, 500)).get('/x'),
          throwsA(_apiError(status: 500, message: 'Ocurrió un problema en el servidor. Intenta más tarde.')));
    });
    test('E1 tiempo de espera agotado → ApiException sin código', () async {
      final api = client((_) => Future.delayed(const Duration(milliseconds: 300), () => _json({}, 200)), timeout: const Duration(milliseconds: 50));
      await expectLater(api.get('/x'), throwsA(_apiError(status: null, message: 'El servidor tardó demasiado en responder. Intenta de nuevo.')));
    });
    test('E2 sin red (SocketException) → error de red', () async {
      final api = client((_) => throw const SocketException('Network is unreachable'));
      await expectLater(api.get('/x'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', isTrue)));
    });
    test('E3 conexión cortada (ClientException)', () async {
      await expectLater(client((_) => throw http.ClientException('Connection closed')).post('/tickets', {}),
          throwsA(_apiError(status: null, message: 'No se pudo conectar con el servidor. Revisa tu conexión.')));
    });
    test('E4 certificado inválido (HandshakeException)', () async {
      await expectLater(client((_) => throw const HandshakeException('bad cert')).get('/x'),
          throwsA(_apiError(status: null, message: 'No se pudo establecer una conexión segura con el servidor.')));
    });
    test('D-07 una URL de servidor mal escrita debería dar ApiException', () async {
      final api = ApiClient(baseUrl: 'http://[mal', httpClient: rec.client((_) async => _json({}, 200)));
      await expectLater(api.get('/x'), throwsA(isA<ApiException>()));
    }, skip: 'Defecto D-07: Uri.parse se ejecuta antes del try y la FormatException llega sin convertir a la pantalla');
  });
}
