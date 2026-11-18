// Prácticas 13 y 14 · Pruebas unitarias automatizadas (AUT-01, AUT-02, AUT-03).
//
// Cada grupo cubre lo que pide la práctica: entrada válida, entrada vacía o nula,
// valores fuera de rango, resultado esperado y manejo de excepciones. Los casos
// marcados "Regresión D-xx" convierten en prueba un defecto de la Práctica 11, para
// que la integración continua avise si vuelve a aparecer.
import 'dart:io';

import 'package:fitpulse_mobile/api/api_client.dart';
import 'package:fitpulse_mobile/api/api_config.dart';
import 'package:fitpulse_mobile/utils/format.dart';
import 'package:fitpulse_mobile/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient clientWith(Future<http.Response> Function(http.Request) handler, {String baseUrl = 'http://fitpulse.test/api'}) =>
    ApiClient(baseUrl: baseUrl, httpClient: MockClient(handler), retry: RetryPolicy.none);

void main() {
  group('AUT-01 · Inicio de sesión y registro (Validators)', () {
    test('entrada válida: correo y contraseña correctos no devuelven error', () {
      expect(Validators.email('ana@correo.com'), isNull);
      expect(Validators.email('  Ana.Lopez@uteq.edu.mx  '), isNull, reason: 'se ignoran los espacios');
      expect(Validators.password('fitpulse123'), isNull);
      expect(Validators.range('72.5', 30, 250, 'peso'), isNull);
    });

    test('entrada vacía o nula: pide el dato en lugar de fallar', () {
      expect(Validators.email(null), 'Escribe tu correo electrónico');
      expect(Validators.email('   '), 'Escribe tu correo electrónico');
      expect(Validators.password(null), 'Escribe tu contraseña');
      expect(Validators.password(''), 'Escribe tu contraseña');
      expect(Validators.range(null, 30, 250, 'peso'), 'Escribe tu peso');
      expect(Validators.range('', 30, 250, 'peso', optional: true), isNull, reason: 'campo opcional vacío');
    });

    test('valores fuera de rango: límites de longitud y de valor', () {
      expect(Validators.password('a' * 7), 'Mínimo 8 caracteres');
      expect(Validators.password('a' * 8), isNull);
      expect(Validators.password('a' * 72), isNull);
      expect(Validators.password('a' * 73), 'Máximo 72 caracteres');
      expect(Validators.email('${'a' * 110}@correo.com'), 'Máximo 120 caracteres');
      expect(Validators.range('29.9', 30, 250, 'peso'), 'Valor entre 30 y 250');
      expect(Validators.range('250.1', 30, 250, 'peso'), 'Valor entre 30 y 250');
      expect(Validators.email('ana@correo'), 'Correo no válido');
    });

    test('resultado esperado: puntaje de seguridad de la contraseña de 0 a 4', () {
      expect(Validators.passwordScore(''), 0);
      expect(Validators.passwordScore('abcdefgh'), 1);
      expect(Validators.passwordScore('Abcdefgh'), 2);
      expect(Validators.passwordScore('Abcdefg1'), 3);
      expect(Validators.passwordScore('Fitpulse#2026'), 4);
    });

    test('Regresión D-08: "NaN" e "Infinity" no se aceptan como números', () {
      expect(Validators.range('NaN', 30, 250, 'peso'), isNotNull);
      expect(Validators.range('Infinity', 30, 250, 'peso'), isNotNull);
      expect(Validators.range('-Infinity', 0, 120, 'edad'), isNotNull);
    });
  });

  group('AUT-02 · Formato de datos y configuración del servidor', () {
    test('resultado esperado: separadores de miles y redondeo', () {
      expect(Fmt.number(0), '0');
      expect(Fmt.number(999), '999');
      expect(Fmt.number(1000), '1,000');
      expect(Fmt.number(1234567), '1,234,567');
      expect(Fmt.number(999.6), '1,000');
      expect(Fmt.number(-1500), '-1,500');
    });

    test('Regresión D-09: un negativo que redondea a cero se muestra "0", no "-0"', () {
      expect(Fmt.number(-0.4), '0');
      expect(Fmt.number(-0.0), '0');
    });

    test('ApiConfig.normalize completa lo que escribe el usuario', () {
      expect(ApiConfig.normalize('34.228.70.230'), 'http://34.228.70.230/api');
      expect(ApiConfig.normalize('https://fitpulse.test/api/'), 'https://fitpulse.test/api');
      expect(ApiConfig.normalize('  http://192.168.1.50:3000  '), 'http://192.168.1.50:3000/api');
      expect(ApiConfig.normalize(''), ApiConfig.platformDefault, reason: 'vacío → valor por defecto');
    });
  });

  group('AUT-03 · Manejo de excepciones en la comunicación (ApiClient)', () {
    test('error 500: mensaje genérico, sin filtrar el detalle técnico del servidor', () async {
      final api = clientWith((_) async => http.Response('{"error":"ER_NO_SUCH_TABLE: Table sessions"}', 500));
      await expectLater(api.get('/sessions'), throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 500)
          .having((e) => e.message, 'message', 'Ocurrió un problema en el servidor. Intenta más tarde.')));
    });

    test('sin red: SocketException se convierte en ApiException de red', () async {
      final api = clientWith((_) async => throw const SocketException('Network is unreachable'));
      await expectLater(api.get('/sessions'), throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)));
    });

    test('respuesta 200 vacía o que no es JSON: devuelve null sin lanzar', () async {
      expect(await clientWith((_) async => http.Response('', 200)).get('/health'), isNull);
      expect(await clientWith((_) async => http.Response('<html>ok</html>', 200)).get('/health'), isNull);
    });

    test('400 con mensaje del servidor: se muestra ese mensaje', () async {
      final api = clientWith((_) async => http.Response('{"error":"La distancia no puede ser negativa"}', 400));
      await expectLater(api.post('/sessions', {'distance_km': -1}),
          throwsA(isA<ApiException>().having((e) => e.message, 'message', 'La distancia no puede ser negativa')));
    });

    test('Regresión D-07: una dirección de servidor mal escrita da ApiException, no FormatException', () async {
      final api = clientWith((_) async => http.Response('{}', 200), baseUrl: 'http://[direccion mal escrita');
      await expectLater(api.get('/health'), throwsA(isA<ApiException>()));
    });
  });
}
