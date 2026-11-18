// Prácticas 13 y 14 · Integración de la app con la API REAL (Node.js + Express + MariaDB).
//
// Solo se ejecuta si se indica la dirección de la API:
//   flutter test test/api_real_test.dart --dart-define=API_URL=http://127.0.0.1:3000/api
// En GitHub Actions el job "integracion-api" levanta MariaDB y el backend de
// fitpulse-backend, y corre este archivo contra ellos. Sin API_URL las pruebas se omiten.
//
// AUT-04  la app envía datos al servicio y recibe respuestas válidas
// AUT-05  la API devuelve los códigos HTTP esperados
// AUT-06  el registro y las sesiones quedan almacenados (se vuelven a leer del servidor)
import 'package:fitpulse_mobile/api/api_client.dart';
import 'package:fitpulse_mobile/api/fitpulse_api.dart';
import 'package:fitpulse_mobile/data/repository.dart';
import 'package:fitpulse_mobile/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';

const apiUrl = String.fromEnvironment('API_URL');
final skip = apiUrl.isEmpty ? 'Sin --dart-define=API_URL: prueba contra la API real omitida' : null;

void main() {
  final stamp = DateTime.now().millisecondsSinceEpoch;
  final email = 'ci.$stamp@fitpulse.test';
  const password = 'Ci-prueba-2026';
  late FitPulseApi api;
  late ApiRepository repo;
  late LocalStore store;

  setUpAll(() {
    store = LocalStore.memory();
    api = FitPulseApi(ApiClient(baseUrl: apiUrl.isEmpty ? 'http://127.0.0.1:9/api' : apiUrl));
    repo = ApiRepository(api, store);
  });

  test('la API responde /health con 200', () async {
    final h = await api.health();
    expect(h['ok'], isTrue);
  }, skip: skip);

  test('AUT-06 registro: crea la cuenta, devuelve token y la app lo guarda', () async {
    final user = await repo.register(name: 'Prueba CI', email: email, password: password);
    expect(user.email, email);
    expect(store.token, isNotEmpty);
  }, skip: skip);

  test('AUT-05 registro repetido con el mismo correo → 409 con mensaje', () async {
    await expectLater(api.register(name: 'Otra', email: email, password: password),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)));
  }, skip: skip);

  test('AUT-06 la cuenta quedó almacenada: se puede iniciar sesión con ella', () async {
    final fresh = ApiRepository(FitPulseApi(ApiClient(baseUrl: apiUrl)), LocalStore.memory());
    final user = await fresh.login(email.toUpperCase(), password);
    expect(user.email, email);
  }, skip: skip);

  test('AUT-05 contraseña incorrecta → 401', () async {
    await expectLater(FitPulseApi(ApiClient(baseUrl: apiUrl)).login(email, 'otra-clave-123'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 401)));
  }, skip: skip);

  test('AUT-04 registrar una sesión y leerla de vuelta del servidor', () async {
    final created = await api.createSession({
      'type': 'cycling',
      'started_at': DateTime.now().toUtc().subtract(const Duration(hours: 1)).toIso8601String(),
      'duration_sec': 1800,
      'distance_km': 12.5,
      'steps': 0,
      'calories': 320,
      'notes': 'Ruta de integración continua',
    });
    expect(created['id'], isNotNull);
    final list = await repo.sessions();
    expect(list.where((s) => s.id == '${created['id']}').single.km, 12.5);
  }, skip: skip);

  test('AUT-04 reintento con la misma Idempotency-Key → misma sesión, sin duplicado', () async {
    final body = {
      'type': 'running',
      'started_at': DateTime.now().toUtc().subtract(const Duration(hours: 3)).toIso8601String(),
      'duration_sec': 1200,
      'distance_km': 4,
      'notes': 'Idempotencia CI',
    };
    final key = ApiClient.newIdempotencyKey();
    final a = await api.createSession(body, idempotencyKey: key);
    final b = await api.createSession(body, idempotencyKey: key);
    expect(b['id'], a['id']);
    final list = await api.sessions();
    expect(list.where((s) => s['notes'] == 'Idempotencia CI').length, 1);
  }, skip: skip);

  test('AUT-04 la búsqueda encuentra de inmediato la sesión recién creada', () async {
    final res = await api.search('integracion');
    expect((res['hits'] as Map)['total'], greaterThanOrEqualTo(1));
  }, skip: skip);

  test('AUT-05 regresión D-01: limit con decimales responde 200 (antes 500)', () async {
    final res = await api.client.get('/sessions', query: {'limit': '5.5'});
    expect(res, isA<List>());
  }, skip: skip);

  test('AUT-05 token inválido → 401 y la app lo marca como sesión vencida', () async {
    var expired = 0;
    final client = ApiClient(baseUrl: apiUrl)
      ..token = 'token-falso'
      ..onUnauthorized = () => expired++;
    await expectLater(client.get('/sessions'), throwsA(isA<ApiException>().having((e) => e.isUnauthorized, '401', true)));
    expect(expired, 1);
  }, skip: skip);

  test('AUT-05 ruta inexistente → 404 con mensaje', () async {
    await expectLater(api.client.get('/no-existe'), throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
  }, skip: skip);
}
