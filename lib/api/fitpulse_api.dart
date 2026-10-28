import 'api_client.dart';

typedef Json = Map<String, dynamic>;

/// Endpoints de la API REST de FitPulse (Node.js + Express + MySQL).
/// Devuelve JSON; la conversión a modelos se hace en el repositorio.
class FitPulseApi {
  FitPulseApi(this.client);

  final ApiClient client;

  // ── Servidor ──
  Future<Json> health() async => (await client.get('/health')) as Json;

  // ── Autenticación ──
  Future<Json> login(String email, String password) async =>
      (await client.post('/auth/login', {'email': email, 'password': password})) as Json;

  Future<Json> register({required String name, required String email, required String password}) async =>
      (await client.post('/auth/register', {'name': name, 'email': email, 'password': password})) as Json;

  // ── Perfil ──
  Future<Json> profile() async => ((await client.get('/profile')) as Json)['user'] as Json;

  Future<Json> updateProfile(Json changes) async => ((await client.put('/profile', changes)) as Json)['user'] as Json;

  /// Elimina la cuenta y todos sus datos. Requiere la contraseña actual.
  Future<void> deleteAccount(String password) => client.delete('/profile', {'password': password});

  // ── Metas ──
  Future<List<Json>> goals() async => _list(await client.get('/goals'));

  Future<Json> createGoal({required String type, required double target, required String period, String? title}) async =>
      (await client.post('/goals', {'type': type, 'target': target, 'period': period, if (title != null) 'title': title})) as Json;

  Future<Json> updateGoal(String id, Json changes) async => ((await client.patch('/goals/$id', changes)) as Json)['goal'] as Json;

  Future<void> deleteGoal(String id) => client.delete('/goals/$id');

  // ── Sesiones ──
  Future<List<Json>> sessions({String? type, int limit = 100}) async =>
      _list(await client.get('/sessions', query: {if (type != null) 'type': type, 'limit': '$limit'}));

  Future<Json> session(String id) async => (await client.get('/sessions/$id')) as Json;

  Future<Json> createSession(Json session) async => (await client.post('/sessions', session)) as Json;

  Future<void> deleteSession(String id) => client.delete('/sessions/$id');

  // ── Métricas ──
  Future<Json> summary({String range = 'week'}) async => (await client.get('/metrics/summary', query: {'range': range})) as Json;

  // ── Dispositivos ──
  Future<List<Json>> devices() async => _list(await client.get('/devices'));

  Future<Json> registerDevice({required String name, String type = 'wearable'}) async =>
      (await client.post('/devices', {'name': name, 'type': type})) as Json;

  Future<void> setDeviceStatus(String id, String status) => client.patch('/devices/$id/status', {'status': status});

  /// Envía una lectura de sensores del wearable (pasos nuevos, ritmo, batería).
  Future<void> sendReading(String deviceId, Json reading) => client.post('/devices/$deviceId/metrics/user', reading);

  Future<void> deleteDevice(String id) => client.delete('/devices/$id');

  // ── Notificaciones ──
  Future<Json> notifications() async => (await client.get('/notifications')) as Json;

  Future<void> markNotificationRead(String id) => client.patch('/notifications/$id/read');

  Future<void> markAllNotificationsRead() => client.post('/notifications/read-all');

  Future<void> deleteNotification(String id) => client.delete('/notifications/$id');

  static List<Json> _list(dynamic data) => (data as List).cast<Json>();
}
