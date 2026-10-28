import 'dart:math';

import '../api/api_client.dart';
import '../api/fitpulse_api.dart' show FitPulseApi;
import '../services/local_store.dart';
import '../utils/format.dart';
import '../wearable/wearable_service.dart';
import 'mock_data.dart';
import 'models.dart';

class NoticeList {
  const NoticeList(this.items, this.unread);
  final List<AppNotice> items;
  final int unread;
}

/// Fuente de datos de la app. Las pantallas y el estado solo conocen esta
/// interfaz, así que da igual si los datos vienen de la API o del modo demo.
abstract class FitPulseRepository {
  bool get isDemo;

  Future<UserProfile> login(String email, String password);
  Future<UserProfile> register({required String name, required String email, required String password});

  /// Recupera la sesión guardada en el teléfono (null si no hay o expiró).
  Future<UserProfile?> restore();
  Future<void> logout();

  Future<UserProfile> updateProfile({required String name, double? weightKg, int? heightCm, int? age, required int dailyStepGoal});
  Future<void> deleteAccount(String password);

  Future<List<Goal>> goals();
  Future<Goal> createGoal({required GoalType type, required double target, required GoalPeriod period, required String title});
  Future<Goal> updateGoalProgress(String id, double value);
  Future<void> deleteGoal(String id);

  Future<List<Session>> sessions();
  Future<Session> session(String id);
  Future<Session> createSession(Session session);
  Future<void> deleteSession(String id);

  Future<ActivitySummary> summary({bool month = false});

  Future<List<Device>> devices();
  Future<Device> registerDevice(FoundDevice found);
  Future<void> sendReading(Device device, WearableReading reading);
  Future<void> setDeviceConnected(Device device, bool connected);
  Future<void> deleteDevice(String id);

  Future<NoticeList> notifications();
  Future<void> markRead(String id);
  Future<void> markAllRead();
  Future<void> deleteNotice(String id);
}

// ═════════════════════════ API REST ═════════════════════════

class ApiRepository implements FitPulseRepository {
  ApiRepository(this.api, this.store);

  final FitPulseApi api;
  final LocalStore store;

  @override
  bool get isDemo => false;

  Future<UserProfile> _signIn(Json res) async {
    final token = res['token'] as String;
    api.client.token = token;
    await store.setToken(token);
    return UserProfile.fromJson((res['user'] as Map).cast<String, dynamic>());
  }

  @override
  Future<UserProfile> login(String email, String password) async => _signIn(await api.login(email.trim().toLowerCase(), password));

  @override
  Future<UserProfile> register({required String name, required String email, required String password}) async =>
      _signIn(await api.register(name: name.trim(), email: email.trim().toLowerCase(), password: password));

  @override
  Future<UserProfile?> restore() async {
    final token = store.token;
    if (token == null) return null;
    api.client.token = token;
    try {
      return UserProfile.fromJson(await api.profile());
    } on ApiException catch (e) {
      if (e.isUnauthorized) await logout();
      rethrow;
    }
  }

  @override
  Future<void> logout() async {
    api.client.token = null;
    await store.setToken(null);
  }

  @override
  Future<UserProfile> updateProfile({required String name, double? weightKg, int? heightCm, int? age, required int dailyStepGoal}) async =>
      UserProfile.fromJson(await api.updateProfile({
        'name': name,
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'age': age,
        'daily_step_goal': dailyStepGoal,
      }));

  @override
  Future<void> deleteAccount(String password) async {
    await api.deleteAccount(password);
    await logout();
  }

  @override
  Future<List<Goal>> goals() async => (await api.goals()).map(Goal.fromJson).toList();

  @override
  Future<Goal> createGoal({required GoalType type, required double target, required GoalPeriod period, required String title}) async =>
      Goal.fromJson(await api.createGoal(type: type.apiName, target: target, period: period.apiName, title: title));

  @override
  Future<Goal> updateGoalProgress(String id, double value) async => Goal.fromJson(await api.updateGoal(id, {'manual_value': value}));

  @override
  Future<void> deleteGoal(String id) => api.deleteGoal(id);

  @override
  Future<List<Session>> sessions() async => (await api.sessions()).map(Session.fromJson).toList();

  @override
  Future<Session> session(String id) async => Session.fromJson(await api.session(id));

  @override
  Future<Session> createSession(Session session) async => Session.fromJson(await api.createSession(session.toApi()));

  @override
  Future<void> deleteSession(String id) => api.deleteSession(id);

  @override
  Future<ActivitySummary> summary({bool month = false}) async => ActivitySummary.fromJson(await api.summary(range: month ? 'month' : 'week'));

  @override
  Future<List<Device>> devices() async {
    final list = (await api.devices()).map(Device.fromJson).toList();
    // El primero registrado es el principal.
    return list.reversed.toList();
  }

  @override
  Future<Device> registerDevice(FoundDevice found) async {
    final d = await api.registerDevice(name: found.name, type: found.kind == DeviceKind.phone ? 'phone' : 'wearable');
    return Device.fromJson(d);
  }

  @override
  Future<void> sendReading(Device device, WearableReading reading) => api.sendReading(device.id, reading.toApi());

  @override
  Future<void> setDeviceConnected(Device device, bool connected) => api.setDeviceStatus(device.id, connected ? 'linked' : 'offline');

  @override
  Future<void> deleteDevice(String id) => api.deleteDevice(id);

  @override
  Future<NoticeList> notifications() async {
    final res = await api.notifications();
    final items = (res['items'] as List).map((e) => AppNotice.fromJson((e as Map).cast<String, dynamic>())).toList();
    return NoticeList(items, (res['unread'] as num?)?.toInt() ?? items.where((n) => !n.read).length);
  }

  @override
  Future<void> markRead(String id) => api.markNotificationRead(id);

  @override
  Future<void> markAllRead() => api.markAllNotificationsRead();

  @override
  Future<void> deleteNotice(String id) => api.deleteNotification(id);
}

// ═════════════════════════ MODO DEMO (sin conexión) ═════════════════════════

/// Datos en memoria para presentar la app sin servidor.
/// Replica las reglas del backend: avance de metas, pasos del día y notificaciones.
class DemoRepository implements FitPulseRepository {
  DemoRepository() {
    _reset();
  }

  late UserProfile _user;
  late List<Goal> _goals;
  late List<Session> _sessions;
  late List<AppNotice> _notices;
  late List<Device> _devices;
  late int _steps;
  late int _kcal;
  late double _km;
  late int _minutes;
  late int _hr;
  int _seq = 100;

  String _id(String p) => '$p${_seq++}';

  void _reset() {
    _user = MockData.user();
    _goals = MockData.goals();
    _sessions = MockData.sessions();
    _notices = MockData.notices();
    _devices = MockData.devices();
    _steps = MockData.todaySteps;
    _kcal = MockData.todayCalories;
    _km = MockData.todayKm;
    _minutes = MockData.activeMinutes;
    _hr = MockData.heartRate;
  }

  Future<T> _later<T>(T value, [int ms = 250]) => Future<T>.delayed(Duration(milliseconds: ms), () => value);

  void _notify(NoticeKind kind, String title, String body) =>
      _notices.insert(0, AppNotice(id: _id('n'), kind: kind, title: title, body: body, time: DateTime.now()));

  @override
  bool get isDemo => true;

  @override
  Future<UserProfile> login(String email, String password) => _later(_user, 600);

  @override
  Future<UserProfile> register({required String name, required String email, required String password}) {
    _user
      ..name = name.trim()
      ..email = email.trim().toLowerCase();
    return _later(_user, 600);
  }

  @override
  Future<UserProfile?> restore() => _later(_user);

  @override
  Future<void> logout() async => _reset();

  @override
  Future<UserProfile> updateProfile({required String name, double? weightKg, int? heightCm, int? age, required int dailyStepGoal}) {
    _user
      ..name = name
      ..weightKg = weightKg
      ..heightCm = heightCm
      ..age = age
      ..dailyStepGoal = dailyStepGoal;
    for (final g in _goals.where((g) => g.type == GoalType.steps && g.period == GoalPeriod.daily)) {
      g.target = dailyStepGoal.toDouble();
      g.title = '${Fmt.number(dailyStepGoal)} pasos diarios';
    }
    return _later(_user);
  }

  @override
  Future<void> deleteAccount(String password) async => _reset();

  @override
  Future<List<Goal>> goals() => _later(List.of(_goals));

  @override
  Future<Goal> createGoal({required GoalType type, required double target, required GoalPeriod period, required String title}) {
    final daily = period == GoalPeriod.daily;
    final current = switch (type) {
      GoalType.steps => daily ? _steps.toDouble() : 63440.0,
      GoalType.distance => daily ? _km : 27.4,
      GoalType.workouts => daily ? 1.0 : 3.0,
      GoalType.calories => daily ? _kcal.toDouble() : 2860.0,
      GoalType.active => daily ? _minutes.toDouble() : 245.0,
      _ => 0.0,
    };
    final rnd = Random(type.index + target.round());
    final g = Goal(
      id: _id('g'),
      type: type,
      title: title,
      target: target,
      current: current,
      period: period,
      history: type.isAuto ? List<double>.generate(7, (_) => .45 + rnd.nextDouble() * .55) : const [],
    );
    _goals.add(g);
    return _later(g);
  }

  @override
  Future<Goal> updateGoalProgress(String id, double value) {
    final g = _goals.firstWhere((g) => g.id == id);
    g.current = value;
    return _later(g);
  }

  @override
  Future<void> deleteGoal(String id) async => _goals.removeWhere((g) => g.id == id);

  @override
  Future<List<Session>> sessions() => _later(List.of(_sessions));

  @override
  Future<Session> session(String id) => _later(_sessions.firstWhere((s) => s.id == id));

  @override
  Future<Session> createSession(Session s) async {
    final saved = Session(
      id: _id('s'),
      type: s.type,
      start: s.start,
      duration: s.duration,
      km: s.km,
      avgHr: s.avgHr,
      maxHr: s.maxHr,
      kcal: s.kcal,
      steps: s.steps,
      hrSeries: s.hrSeries,
      device: s.device,
    );
    _sessions.insert(0, saved);
    _steps += s.steps;
    _kcal += s.kcal;
    _km += s.km;
    _minutes += s.duration.inMinutes;
    for (final g in _goals) {
      final wasDone = g.done;
      switch (g.type) {
        case GoalType.steps:
          if (g.period == GoalPeriod.daily) g.current = _steps.toDouble();
        case GoalType.distance:
          g.current += s.km;
        case GoalType.workouts:
          g.current += 1;
        case GoalType.calories:
          g.current += s.kcal;
        case GoalType.active:
          g.current += s.duration.inMinutes;
        default:
          break;
      }
      if (!wasDone && g.done) _notify(NoticeKind.goal, '¡Meta cumplida!', 'Completaste "${g.title}". ¡Sigue así!');
    }
    _notify(NoticeKind.session, 'Sesión guardada',
        '${s.type.title} · ${Fmt.duration(s.duration)}${s.km > 0 ? ' · ${Fmt.km(s.km)} km' : ''}');
    if (s.maxHr >= 175) _notify(NoticeKind.heart, 'Ritmo cardíaco alto', 'Alcanzaste ${s.maxHr} bpm. Recuerda hidratarte.');
    return _later(saved, 500);
  }

  @override
  Future<void> deleteSession(String id) async => _sessions.removeWhere((s) => s.id == id);

  @override
  Future<ActivitySummary> summary({bool month = false}) {
    final now = DateTime.now();
    final values = month ? MockData.monthSteps() : [...MockData.weekSteps.sublist(0, 6), _steps.toDouble()];
    if (month) values[values.length - 1] = _steps.toDouble();
    final days = [
      for (var i = 0; i < values.length; i++)
        DaySummary(
          date: DateTime(now.year, now.month, now.day).subtract(Duration(days: values.length - 1 - i)),
          steps: values[i].round(),
          km: 0,
          kcal: 0,
          minutes: 0,
          sessions: 0,
        ),
    ];
    final byType = <ActivityType, TypeTotals>{};
    for (final s in _sessions) {
      final p = byType[s.type] ?? const TypeTotals();
      byType[s.type] = TypeTotals(count: p.count + 1, minutes: p.minutes + s.duration.inMinutes, km: p.km + s.km);
    }
    return _later(ActivitySummary(
      todaySteps: _steps,
      todayKm: _km,
      todayKcal: _kcal,
      activeMinutes: _minutes,
      heartRate: _hr,
      days: days,
      totalKm: month ? 112.8 : 27.4,
      totalKcal: month ? 11940 : 2860,
      byType: byType,
      restingHr: MockData.restingHr,
      restingDelta: MockData.restingHrDelta,
      restingTrend: MockData.restingHrTrend,
      hrToday: MockData.todayHr,
    ));
  }

  @override
  Future<List<Device>> devices() => _later(List.of(_devices));

  @override
  Future<Device> registerDevice(FoundDevice f) {
    final d = Device(id: _id('d'), name: f.name, model: f.model, kind: f.kind, battery: 70 + Random().nextInt(30), connected: true, lastSync: DateTime.now());
    _devices.add(d);
    _notify(NoticeKind.sync, 'Nuevo dispositivo vinculado', '${f.name} ya comparte datos con FitPulse.');
    return _later(d);
  }

  @override
  Future<void> sendReading(Device device, WearableReading r) async {
    _steps += r.steps;
    _hr = r.heartRate;
    for (final g in _goals.where((g) => g.type == GoalType.steps && g.period == GoalPeriod.daily)) {
      g.current = _steps.toDouble();
    }
    final d = _devices.firstWhere((x) => x.id == device.id, orElse: () => device);
    d
      ..battery = r.battery
      ..connected = true
      ..lastSync = DateTime.now();
    _notify(NoticeKind.sync, 'Dispositivo sincronizado', 'Se recibieron ${Fmt.number(r.steps)} pasos nuevos desde ${device.name}.');
  }

  @override
  Future<void> setDeviceConnected(Device device, bool connected) async {
    for (final d in _devices.where((d) => d.id == device.id)) {
      d.connected = connected;
    }
  }

  @override
  Future<void> deleteDevice(String id) async => _devices.removeWhere((d) => d.id == id);

  @override
  Future<NoticeList> notifications() => _later(NoticeList(List.of(_notices), _notices.where((n) => !n.read).length));

  @override
  Future<void> markRead(String id) async {
    for (final n in _notices.where((n) => n.id == id)) {
      n.read = true;
    }
  }

  @override
  Future<void> markAllRead() async {
    for (final n in _notices) {
      n.read = true;
    }
  }

  @override
  Future<void> deleteNotice(String id) async => _notices.removeWhere((n) => n.id == id);
}
