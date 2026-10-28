import 'dart:math';
import 'package:flutter/widgets.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../utils/format.dart';

/// Estado global simulado de la app.
/// En la Unidad 2 cada método se reemplazará por una llamada a la API REST
/// (Node.js/Express → MySQL); las pantallas no tendrán que cambiar.
class AppState extends ChangeNotifier {
  UserProfile user = MockData.user();
  final List<Goal> goals = MockData.goals();
  final List<Session> sessions = MockData.sessions();
  final List<AppNotice> notices = MockData.notices();
  final List<Device> devices = MockData.devices();

  int todaySteps = MockData.todaySteps;
  int todayCalories = MockData.todayCalories;
  double todayKm = MockData.todayKm;
  int activeMinutes = MockData.activeMinutes;
  int heartRate = MockData.heartRate;

  final Map<String, bool> sharedData = {
    'Pasos': true,
    'Ritmo cardíaco': true,
    'Movimiento': true,
    'Sueño': false,
  };

  final Map<String, bool> noticePrefs = {
    'Metas cumplidas': true,
    'Sincronización del dispositivo': true,
    'Ritmo cardíaco alto': true,
    'Batería baja': true,
    'Recordatorio diario de actividad': false,
  };

  bool allowAnonymousStats = true;

  int _seq = 100;
  String _id(String prefix) => '$prefix${_seq++}';

  // ───────── Sesión de usuario (simulada) ─────────

  Future<void> login(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (email.trim().toLowerCase() != user.email) {
      user.email = email.trim().toLowerCase();
    }
    notifyListeners();
  }

  Future<void> register(String name, String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 1300));
    user.name = name.trim();
    user.email = email.trim().toLowerCase();
    notifyListeners();
  }

  void resetDemo() {
    user = MockData.user();
    goals
      ..clear()
      ..addAll(MockData.goals());
    sessions
      ..clear()
      ..addAll(MockData.sessions());
    notices
      ..clear()
      ..addAll(MockData.notices());
    devices
      ..clear()
      ..addAll(MockData.devices());
    todaySteps = MockData.todaySteps;
    todayCalories = MockData.todayCalories;
    todayKm = MockData.todayKm;
    activeMinutes = MockData.activeMinutes;
    notifyListeners();
  }

  // ───────── Perfil ─────────

  void updateProfile({required String name, required double weightKg, required int heightCm, required int age, required int dailyStepGoal}) {
    user
      ..name = name
      ..weightKg = weightKg
      ..heightCm = heightCm
      ..age = age
      ..dailyStepGoal = dailyStepGoal;
    for (final g in goals.where((g) => g.type == GoalType.steps && g.period == GoalPeriod.daily)) {
      g.target = dailyStepGoal.toDouble();
      g.title = '${Fmt.number(dailyStepGoal)} pasos diarios';
    }
    notifyListeners();
  }

  // ───────── Sesiones ─────────

  Goal? get stepsGoal {
    for (final g in goals) {
      if (g.type == GoalType.steps && g.period == GoalPeriod.daily) return g;
    }
    return null;
  }

  Session? get lastSession => sessions.isEmpty ? null : sessions.first;

  void addSession(Session s) {
    sessions.insert(0, s);
    todaySteps += s.steps;
    todayCalories += s.kcal;
    todayKm += s.km;
    activeMinutes += s.duration.inMinutes;

    for (final g in goals) {
      final wasDone = g.done;
      switch (g.type) {
        case GoalType.steps:
          if (g.period == GoalPeriod.daily) g.current = todaySteps.toDouble();
          break;
        case GoalType.distance:
          if (s.type == ActivityType.running) g.current += s.km;
          break;
        case GoalType.workouts:
          g.current += 1;
          break;
        case GoalType.calories:
          g.current += s.kcal;
          break;
        case GoalType.active:
          g.current += s.duration.inMinutes;
          break;
        case GoalType.sleep:
          break;
      }
      if (!wasDone && g.done) {
        _notify(NoticeKind.goal, '¡Meta cumplida!', 'Completaste "${g.title}". 🎉');
      }
    }

    _notify(NoticeKind.session, 'Sesión guardada', '${s.type.title} · ${Fmt.duration(s.duration)}${s.km > 0 ? ' · ${Fmt.km(s.km)} km' : ''}');
    if (s.maxHr >= 175) {
      _notify(NoticeKind.heart, 'Ritmo cardíaco alto', 'Alcanzaste ${s.maxHr} bpm. Recuerda hidratarte.');
    }
    notifyListeners();
  }

  void deleteSession(String id) {
    sessions.removeWhere((s) => s.id == id);
    notifyListeners();
  }

  /// Construye una sesión a partir de lo medido en la pantalla de actividad.
  Session buildSession({required ActivityType type, required int seconds, required double km, required List<double> hr, required int kcal, required int steps}) {
    final avg = hr.isEmpty ? type.baseHr : (hr.reduce((a, b) => a + b) / hr.length).round();
    final maxHr = hr.isEmpty ? type.baseHr + 12 : hr.reduce(max).round();
    final series = hr.length >= 8 ? List<double>.from(hr) : MockData.hrSeries(seconds, avg);
    return Session(
      id: _id('s'),
      type: type,
      start: DateTime.now().subtract(Duration(seconds: seconds)),
      duration: Duration(seconds: max(seconds, 60)),
      km: double.parse(km.toStringAsFixed(2)),
      avgHr: avg,
      maxHr: maxHr,
      kcal: kcal,
      steps: steps,
      hrSeries: series,
    );
  }

  // ───────── Metas ─────────

  void addGoal({required GoalType type, required double target, required GoalPeriod period}) {
    final current = switch (type) {
      GoalType.steps => period == GoalPeriod.daily ? todaySteps.toDouble() : 63440.0,
      GoalType.distance => period == GoalPeriod.daily ? todayKm : 27.4,
      GoalType.workouts => period == GoalPeriod.daily ? 1.0 : 3.0,
      GoalType.calories => period == GoalPeriod.daily ? todayCalories.toDouble() : 2860.0,
      GoalType.sleep => 7.2,
      GoalType.active => period == GoalPeriod.daily ? activeMinutes.toDouble() : 245.0,
    };
    final rnd = Random(type.index + target.round());
    goals.add(Goal(
      id: _id('g'),
      type: type,
      title: goalTitle(type, target, period),
      target: target,
      current: current,
      period: period,
      history: List<double>.generate(7, (_) => .45 + rnd.nextDouble() * .55),
    ));
    notifyListeners();
  }

  static String goalTitle(GoalType type, double target, GoalPeriod period) {
    final v = target == target.roundToDouble() ? Fmt.number(target) : target.toStringAsFixed(1);
    final p = period == GoalPeriod.daily ? 'diarios' : 'por semana';
    return switch (type) {
      GoalType.steps => '$v pasos $p',
      GoalType.distance => 'Recorrer $v km${period == GoalPeriod.weekly ? ' por semana' : ' al día'}',
      GoalType.workouts => '$v entrenamientos${period == GoalPeriod.weekly ? '' : ' al día'}',
      GoalType.calories => 'Quemar $v kcal${period == GoalPeriod.daily ? ' al día' : ' por semana'}',
      GoalType.sleep => 'Dormir $v horas',
      GoalType.active => '$v min activos${period == GoalPeriod.daily ? ' al día' : ' por semana'}',
    };
  }

  void deleteGoal(String id) {
    goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  // ───────── Notificaciones ─────────

  int get unreadCount => notices.where((n) => !n.read).length;

  void _notify(NoticeKind kind, String title, String body) {
    notices.insert(0, AppNotice(id: _id('n'), kind: kind, title: title, body: body, time: DateTime.now()));
  }

  void markAllRead() {
    for (final n in notices) {
      n.read = true;
    }
    notifyListeners();
  }

  void markRead(String id) {
    for (final n in notices) {
      if (n.id == id) n.read = true;
    }
    notifyListeners();
  }

  void removeNotice(String id) {
    notices.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  // ───────── Dispositivos (simulación BLE) ─────────

  Device? get mainDevice => devices.isEmpty ? null : devices.first;

  Future<int> syncDevice(Device d) async {
    if (d.syncing) return 0;
    d.syncing = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    final newSteps = 80 + Random().nextInt(240);
    todaySteps += newSteps;
    final g = stepsGoal;
    if (g != null) g.current = todaySteps.toDouble();
    d
      ..syncing = false
      ..connected = true
      ..lastSync = DateTime.now();
    heartRate = 68 + Random().nextInt(9);
    if (noticePrefs['Sincronización del dispositivo'] ?? true) {
      _notify(NoticeKind.sync, 'Dispositivo sincronizado', 'Se recibieron ${Fmt.number(newSteps)} pasos nuevos desde ${d.name}.');
    }
    notifyListeners();
    return newSteps;
  }

  void toggleConnection(Device d) {
    d.connected = !d.connected;
    notifyListeners();
  }

  void pairDevice(FoundDevice f) {
    devices.add(Device(
      id: _id('d'),
      name: f.name,
      model: f.model,
      kind: f.kind,
      battery: 70 + Random().nextInt(30),
      connected: true,
      lastSync: DateTime.now(),
    ));
    _notify(NoticeKind.sync, 'Nuevo dispositivo vinculado', '${f.name} ya comparte datos con FitPulse.');
    notifyListeners();
  }

  void removeDevice(String id) {
    devices.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  void setShared(String key, bool value) {
    sharedData[key] = value;
    notifyListeners();
  }

  void setNoticePref(String key, bool value) {
    noticePrefs[key] = value;
    notifyListeners();
  }

  void setAnonymousStats(bool value) {
    allowAnonymousStats = value;
    notifyListeners();
  }
}

/// Acceso al estado desde cualquier widget: `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  /// Escucha cambios (reconstruye el widget).
  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Solo lectura, para callbacks.
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
