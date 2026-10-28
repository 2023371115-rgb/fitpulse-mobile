// Prueba de humo de la conexión app ↔ backend (Dart puro, sin Flutter).
//
// Recorre el flujo de la app contra una API en ejecución:
// registro, login, perfil, metas, sesiones, métricas, wearable y notificaciones.
//
//   dart run tool/api_smoke.dart [http://localhost:3000/api]
import 'dart:io';

import 'package:fitpulse_mobile/api/api_client.dart';
import 'package:fitpulse_mobile/api/fitpulse_api.dart';

Future<void> main(List<String> args) async {
  final baseUrl = args.isNotEmpty ? args.first : 'http://localhost:3000/api';
  final client = ApiClient(baseUrl: baseUrl);
  final api = FitPulseApi(client);
  var failures = 0;

  Future<void> step(String name, Future<void> Function() body) async {
    try {
      await body();
      stdout.writeln('  ✔ $name');
    } catch (e) {
      failures++;
      stdout.writeln('  ✘ $name → $e');
    }
  }

  void check(bool ok, String what) {
    if (!ok) throw StateError(what);
  }

  stdout.writeln('FitPulse API · $baseUrl');
  final email = 'smoke${DateTime.now().millisecondsSinceEpoch}@correo.com';

  await step('servidor disponible', () async {
    final h = await api.health();
    check(h['ok'] == true, 'health.ok');
  });

  await step('login con contraseña incorrecta muestra mensaje genérico', () async {
    try {
      await api.login(email, 'incorrecta123');
      throw StateError('debió fallar');
    } on ApiException catch (e) {
      check(e.statusCode == 401, 'status 401');
      check(e.message == 'Credenciales incorrectas.', 'mensaje: ${e.message}');
    }
  });

  await step('registro', () async {
    final r = await api.register(name: 'Prueba Smoke', email: email, password: 'password123');
    client.token = r['token'] as String;
    check((r['user'] as Json)['email'] == email, 'email');
  });

  await step('login', () async {
    final r = await api.login(email, 'password123');
    client.token = r['token'] as String;
  });

  await step('perfil', () async {
    final p = await api.updateProfile({'weight_kg': 62, 'height_cm': 165, 'age': 28, 'daily_step_goal': 9000});
    check(p['daily_step_goal'] == 9000, 'daily_step_goal');
    final again = await api.profile();
    check(again['name'] == 'Prueba Smoke', 'name');
  });

  String? goalId;
  await step('crear meta semanal de distancia', () async {
    final g = await api.createGoal(type: 'distance', target: 5, period: 'weekly', title: 'Correr 5 km');
    goalId = g['id'] as String;
    check(g['current'] == 0, 'current inicial');
  });

  String? sessionId;
  await step('registrar sesión (cumple la meta y notifica)', () async {
    final start = DateTime.now().subtract(const Duration(minutes: 40));
    final s = await api.createSession({
      'type': 'running',
      'started_at': start.toUtc().toIso8601String(),
      'duration_sec': 1800,
      'distance_km': 5.4,
      'steps': 5600,
      'calories': 350,
      'avg_heart_rate': 150,
      'max_heart_rate': 170,
      'hr_samples': [120, 140, 150, 160, 170],
    });
    sessionId = s['id'] as String;
    check((s['goals_completed'] as List).contains(goalId), 'goals_completed');
  });

  await step('metas con avance calculado por el servidor', () async {
    final goals = await api.goals();
    final g = goals.firstWhere((x) => x['id'] == goalId);
    check(g['done'] == true && g['current'] == 5.4, 'meta cumplida');
    final steps = goals.firstWhere((x) => x['type'] == 'steps');
    check(steps['target'] == 9000 && steps['current'] == 5600, 'meta de pasos');
  });

  await step('consultar sesiones y detalle', () async {
    final list = await api.sessions();
    check(list.length == 1, 'una sesión');
    final detail = await api.session(sessionId!);
    check((detail['hr_samples'] as List).length == 5, 'hr_samples');
  });

  String? deviceId;
  await step('vincular wearable y enviar lectura de sensores', () async {
    final d = await api.registerDevice(name: 'FitPulse Band');
    deviceId = d['id'] as String;
    await api.sendReading(deviceId!, {'steps': 400, 'heart_rate': 71, 'battery': 80});
    final devices = await api.devices();
    check(devices.first['status'] == 'linked' && devices.first['battery'] == 80, 'estado del dispositivo');
  });

  await step('resumen de métricas', () async {
    final m = await api.summary();
    final today = m['today'] as Json;
    check(today['steps'] == 6000, 'pasos de hoy: ${today['steps']}');
    check((m['days'] as List).length == 7, '7 días');
    check(today['heart_rate'] == 71, 'ritmo actual');
  });

  await step('notificaciones', () async {
    final n = await api.notifications();
    final kinds = (n['items'] as List).map((e) => (e as Json)['kind']).toSet();
    check(kinds.containsAll({'session', 'goal', 'sync'}), 'tipos: $kinds');
    await api.markAllNotificationsRead();
    check((await api.notifications())['unread'] == 0, 'todas leídas');
  });

  await step('eliminar sesión, meta y dispositivo', () async {
    await api.deleteSession(sessionId!);
    await api.deleteGoal(goalId!);
    await api.deleteDevice(deviceId!);
    check((await api.sessions()).isEmpty, 'sin sesiones');
  });

  await step('token inválido → sesión expirada', () async {
    client.token = 'token-invalido';
    try {
      await api.profile();
      throw StateError('debió fallar');
    } on ApiException catch (e) {
      check(e.isUnauthorized, '401');
    }
  });

  client.close();
  stdout.writeln(failures == 0 ? '\nTodo correcto.' : '\n$failures paso(s) fallaron.');
  exit(failures == 0 ? 0 : 1);
}
