import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

import '../api/api_client.dart';
import '../api/api_config.dart';
import '../api/fitpulse_api.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../services/local_store.dart';
import '../utils/format.dart';
import '../wearable/wearable_service.dart';

/// Estado global de la app.
///
/// Las pantallas leen de aquí y llaman a sus métodos; este estado habla con
/// el [FitPulseRepository] (API REST o modo demo) y con el [WearableService].
/// Los métodos que llaman a la API lanzan [ApiException] con un mensaje listo
/// para mostrar.
class AppState extends ChangeNotifier {
  AppState({required this.store, FitPulseApi? api, FitPulseRepository? demo, WearableService? wearable})
      : wearable = wearable ?? SimulatedWearableService() {
    this.api = api ?? FitPulseApi(ApiClient(baseUrl: store.apiUrl ?? ApiConfig.platformDefault));
    this.api.client.onUnauthorized = _sessionExpired;
    _apiRepo = ApiRepository(this.api, store);
    _demoRepo = demo ?? DemoRepository();
    _repo = _apiRepo;
    sharedData.updateAll((k, v) => store.pref('share_$k', v));
    noticePrefs.updateAll((k, v) => store.pref('notice_$k', v));
    allowAnonymousStats = store.pref('anonymous_stats', true);
  }

  final LocalStore store;
  final WearableService wearable;
  late final FitPulseApi api;
  late final ApiRepository _apiRepo;
  late final FitPulseRepository _demoRepo;
  late FitPulseRepository _repo;

  FitPulseRepository get repository => _repo;
  bool get isDemo => _repo.isDemo;
  String get apiUrl => api.client.baseUrl;

  // ───────── Datos ─────────
  UserProfile user = UserProfile.empty();
  List<Goal> goals = [];
  List<Session> sessions = [];
  List<AppNotice> notices = [];
  List<Device> devices = [];
  ActivitySummary summary = ActivitySummary.empty;
  int unreadCount = 0;

  bool loading = false;
  String? loadError;
  bool signedIn = false;

  /// Se activa cuando el servidor rechaza el token; la app vuelve al login.
  final ValueNotifier<bool> sessionExpired = ValueNotifier(false);

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

  // Atajos usados por las pantallas
  int get todaySteps => summary.todaySteps;
  int get todayCalories => summary.todayKcal;
  double get todayKm => summary.todayKm;
  int get activeMinutes => summary.activeMinutes;
  int? get heartRate => summary.heartRate;
  Device? get mainDevice => devices.isEmpty ? null : devices.first;
  Session? get lastSession => sessions.isEmpty ? null : sessions.first;
  Goal? get stepsGoal {
    for (final g in goals) {
      if (g.type == GoalType.steps && g.period == GoalPeriod.daily) return g;
    }
    return null;
  }

  // ───────── Servidor ─────────

  Future<void> setApiUrl(String url) async {
    final normalized = ApiConfig.normalize(url);
    api.client.url = normalized;
    await store.setApiUrl(normalized == ApiConfig.platformDefault ? null : normalized);
    notifyListeners();
  }

  /// Prueba la conexión con el servidor. Devuelve la versión de la API.
  Future<String> checkServer() async {
    final h = await api.health();
    return '${h['name'] ?? 'FitPulse'} ${h['version'] ?? ''}'.trim();
  }

  // ───────── Sesión de usuario ─────────

  /// Intenta recuperar la sesión guardada. true si hay un usuario válido.
  Future<bool> restoreSession() async {
    try {
      final u = await _apiRepo.restore();
      if (u == null) return false;
      _repo = _apiRepo;
      user = u;
      signedIn = true;
      unawaited(refreshAll());
      return true;
    } on ApiException {
      return false;
    }
  }

  Future<void> login(String email, String password) async {
    final u = await _apiRepo.login(email, password);
    await _startSession(_apiRepo, u);
  }

  Future<void> register(String name, String email, String password) async {
    final u = await _apiRepo.register(name: name, email: email, password: password);
    await _startSession(_apiRepo, u);
  }

  /// Modo demo: datos de ejemplo en el teléfono, sin servidor.
  Future<void> enterDemo() async {
    final u = await _demoRepo.login('', '');
    await _startSession(_demoRepo, u);
  }

  Future<void> _startSession(FitPulseRepository repo, UserProfile u) async {
    _repo = repo;
    user = u;
    signedIn = true;
    sessionExpired.value = false;
    await refreshAll();
  }

  Future<void> logout() async {
    await _repo.logout();
    _clear();
  }

  Future<void> deleteAccount(String password) async {
    await _repo.deleteAccount(password);
    _clear();
  }

  void _clear() {
    signedIn = false;
    _repo = _apiRepo;
    user = UserProfile.empty();
    goals = [];
    sessions = [];
    notices = [];
    devices = [];
    summary = ActivitySummary.empty;
    unreadCount = 0;
    _monthCache = null;
    notifyListeners();
  }

  void _sessionExpired() {
    if (!signedIn || isDemo) return;
    unawaited(_apiRepo.logout());
    _clear();
    sessionExpired.value = true;
  }

  // ───────── Carga de datos ─────────

  /// Descarga todo lo necesario para las pantallas principales.
  Future<void> refreshAll() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repo.goals(),
        _repo.sessions(),
        _repo.summary(),
        _repo.devices(),
        _repo.notifications(),
      ]);
      goals = results[0] as List<Goal>;
      sessions = results[1] as List<Session>;
      summary = results[2] as ActivitySummary;
      devices = results[3] as List<Device>;
      final n = results[4] as NoticeList;
      notices = n.items;
      unreadCount = n.unread;
      _monthCache = null;
    } on ApiException catch (e) {
      loadError = e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _refresh({bool goals = false, bool sessions = false, bool summary = false, bool devices = false, bool notices = true}) async {
    try {
      if (goals) this.goals = await _repo.goals();
      if (sessions) this.sessions = await _repo.sessions();
      if (summary) {
        this.summary = await _repo.summary();
        _monthCache = null;
      }
      if (devices) this.devices = await _repo.devices();
      if (notices) {
        final n = await _repo.notifications();
        this.notices = n.items;
        unreadCount = n.unread;
      }
    } on ApiException catch (e) {
      loadError = e.message;
    }
    notifyListeners();
  }

  ActivitySummary? _monthCache;

  /// Resumen de la semana (ya cargado) o del mes (se descarga al pedirlo).
  Future<ActivitySummary> summaryFor({required bool month}) async {
    if (!month) return summary;
    return _monthCache ??= await _repo.summary(month: true);
  }

  // ───────── Perfil ─────────

  Future<void> updateProfile({required String name, double? weightKg, int? heightCm, int? age, required int dailyStepGoal}) async {
    user = await _repo.updateProfile(name: name, weightKg: weightKg, heightCm: heightCm, age: age, dailyStepGoal: dailyStepGoal);
    await _refresh(goals: true, notices: false);
  }

  // ───────── Sesiones ─────────

  /// Construye una sesión a partir de lo medido en la pantalla de actividad.
  Session buildSession({required ActivityType type, required int seconds, required double km, required List<double> hr, required int kcal, required int steps}) {
    final avg = hr.isEmpty ? type.baseHr : (hr.reduce((a, b) => a + b) / hr.length).round();
    final maxHr = hr.isEmpty ? type.baseHr + 12 : hr.reduce(max).round();
    return Session(
      id: 'local',
      type: type,
      start: DateTime.now().subtract(Duration(seconds: seconds)),
      duration: Duration(seconds: max(seconds, 60)),
      km: double.parse(km.toStringAsFixed(2)),
      avgHr: avg,
      maxHr: maxHr,
      kcal: kcal,
      steps: steps,
      hrSeries: List<double>.from(hr),
      device: mainDevice?.connected == true ? mainDevice!.name : 'Teléfono',
    );
  }

  Future<Session> addSession(Session s) async {
    final saved = await _repo.createSession(s);
    sessions.insert(0, saved);
    notifyListeners();
    await _refresh(goals: true, summary: true);
    return saved;
  }

  /// Detalle de una sesión con su gráfica de ritmo cardíaco.
  Future<Session> loadSession(Session s) async {
    if (s.hrSeries.isNotEmpty) return s;
    final full = await _repo.session(s.id);
    final i = sessions.indexWhere((x) => x.id == s.id);
    if (i >= 0) sessions[i] = full;
    return full;
  }

  Future<void> deleteSession(String id) async {
    await _repo.deleteSession(id);
    sessions.removeWhere((s) => s.id == id);
    notifyListeners();
    await _refresh(goals: true, summary: true, notices: false);
  }

  // ───────── Metas ─────────

  Future<void> addGoal({required GoalType type, required double target, required GoalPeriod period}) async {
    final g = await _repo.createGoal(type: type, target: target, period: period, title: goalTitle(type, target, period));
    goals.add(g);
    notifyListeners();
  }

  Future<void> updateGoalProgress(Goal goal, double value) async {
    final updated = await _repo.updateGoalProgress(goal.id, value);
    final i = goals.indexWhere((g) => g.id == goal.id);
    if (i >= 0) goals[i] = updated;
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
      GoalType.heartRate => 'Ritmo en reposo de $v bpm',
      GoalType.weight => 'Llegar a $v kg',
    };
  }

  Future<void> deleteGoal(String id) async {
    await _repo.deleteGoal(id);
    goals.removeWhere((g) => g.id == id);
    notifyListeners();
  }

  // ───────── Notificaciones ─────────

  Future<void> refreshNotices() => _refresh();

  Future<void> markAllRead() async {
    await _repo.markAllRead();
    for (final n in notices) {
      n.read = true;
    }
    unreadCount = 0;
    notifyListeners();
  }

  Future<void> markRead(String id) async {
    final n = notices.where((n) => n.id == id && !n.read).firstOrNull;
    if (n == null) return;
    n.read = true;
    unreadCount = max(0, unreadCount - 1);
    notifyListeners();
    await _repo.markRead(id);
  }

  Future<void> removeNotice(String id) async {
    final n = notices.where((n) => n.id == id).firstOrNull;
    notices.removeWhere((n) => n.id == id);
    if (n != null && !n.read) unreadCount = max(0, unreadCount - 1);
    notifyListeners();
    await _repo.deleteNotice(id);
  }

  // ───────── Dispositivos y wearable ─────────

  /// Lee los sensores del wearable y envía la lectura a la API.
  /// Devuelve los pasos nuevos recibidos.
  Future<int> syncDevice(Device d) async {
    if (d.syncing) return 0;
    d.syncing = true;
    notifyListeners();
    try {
      final reading = await wearable.read(d);
      await _repo.sendReading(d, reading);
      d
        ..battery = reading.battery
        ..connected = true
        ..lastSync = DateTime.now();
      await _refresh(goals: true, summary: true, devices: true);
      return reading.steps;
    } finally {
      d.syncing = false;
      notifyListeners();
    }
  }

  Future<void> toggleConnection(Device d) async {
    final next = !d.connected;
    await _repo.setDeviceConnected(d, next);
    d.connected = next;
    notifyListeners();
  }

  /// Vincula un dispositivo encontrado por Bluetooth y envía su primera lectura.
  Future<void> pairDevice(FoundDevice f) async {
    await wearable.connect(f);
    final d = await _repo.registerDevice(f);
    devices.add(d);
    notifyListeners();
    final reading = await wearable.read(d);
    await _repo.sendReading(d, reading);
    await _refresh(devices: true, summary: true);
  }

  Future<void> removeDevice(String id) async {
    await _repo.deleteDevice(id);
    devices.removeWhere((d) => d.id == id);
    notifyListeners();
  }

  // ───────── Preferencias locales ─────────

  void setShared(String key, bool value) {
    sharedData[key] = value;
    unawaited(store.setPref('share_$key', value));
    notifyListeners();
  }

  void setNoticePref(String key, bool value) {
    noticePrefs[key] = value;
    unawaited(store.setPref('notice_$key', value));
    notifyListeners();
  }

  void setAnonymousStats(bool value) {
    allowAnonymousStats = value;
    unawaited(store.setPref('anonymous_stats', value));
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
