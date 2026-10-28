import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

typedef Json = Map<String, dynamic>;

// ───────── Conversión segura de JSON ─────────
double _d(Object? v, [double fallback = 0]) => v is num ? v.toDouble() : double.tryParse('$v') ?? fallback;
double? _dn(Object? v) => v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
int _i(Object? v, [int fallback = 0]) => v is num ? v.round() : int.tryParse('$v') ?? fallback;
int? _in(Object? v) => v == null ? null : (v is num ? v.round() : int.tryParse('$v'));
DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();
List<double> _doubles(Object? v) => v is List ? v.whereType<num>().map((e) => e.toDouble()).toList() : <double>[];

/// Tipos de actividad física. `apiName` coincide con el ENUM `sessions.type` del backend.
enum ActivityType {
  running('running', 'Correr', 'Carrera', Icons.directions_run_rounded, FP.red, 150, 1 / 360, 10.5, 2.7),
  walking('walking', 'Caminar', 'Caminata', Icons.directions_walk_rounded, FP.green, 102, 1 / 690, 4.6, 1.8),
  cycling('cycling', 'Bici', 'Bicicleta', Icons.directions_bike_rounded, FP.amber, 132, 1 / 150, 8.4, 0),
  gym('gym', 'Fuerza', 'Fuerza', Icons.fitness_center_rounded, FP.indigo, 118, 0, 6.2, 0.3),
  other('other', 'Otra', 'Actividad', Icons.sports_rounded, FP.blue, 115, 0, 5.5, 0.5);

  const ActivityType(this.apiName, this.label, this.title, this.icon, this.color, this.baseHr, this.kmPerSecond, this.kcalPerMinute, this.stepsPerSecond);

  final String apiName;
  final String label;
  final String title;
  final IconData icon;
  final Color color;
  final int baseHr;
  final double kmPerSecond;
  final double kcalPerMinute;
  final double stepsPerSecond;

  bool get hasDistance => kmPerSecond > 0;

  /// Las que se pueden elegir al iniciar una actividad.
  static const selectable = [running, walking, cycling, gym];

  static ActivityType fromApi(Object? name) =>
      values.firstWhere((t) => t.apiName == name, orElse: () => other);
}

class Session {
  Session({
    required this.id,
    required this.type,
    required this.start,
    required this.duration,
    required this.km,
    required this.avgHr,
    required this.maxHr,
    required this.kcal,
    required this.steps,
    required this.hrSeries,
    this.device = 'FitPulse Band',
  });

  factory Session.fromJson(Json j) {
    final start = _date(j['started_at']) ?? DateTime.now();
    final end = _date(j['ended_at']);
    final seconds = _in(j['duration_sec']) ?? (end == null ? 0 : end.difference(start).inSeconds);
    return Session(
      id: '${j['id']}',
      type: ActivityType.fromApi(j['type']),
      start: start,
      duration: Duration(seconds: seconds < 0 ? 0 : seconds),
      km: _d(j['distance_km']),
      avgHr: _i(j['avg_heart_rate']),
      maxHr: _i(j['max_heart_rate'], _i(j['avg_heart_rate'])),
      kcal: _i(j['calories']),
      steps: _i(j['steps']),
      hrSeries: _doubles(j['hr_samples']),
      device: (j['device_name'] as String?) ?? 'Teléfono',
    );
  }

  /// Cuerpo para POST /api/sessions.
  Json toApi() => {
        'type': type.apiName,
        'started_at': start.toUtc().toIso8601String(),
        'duration_sec': duration.inSeconds,
        if (km > 0) 'distance_km': double.parse(km.toStringAsFixed(2)),
        'steps': steps,
        'calories': kcal,
        if (avgHr > 0) 'avg_heart_rate': avgHr,
        if (maxHr > 0) 'max_heart_rate': maxHr,
        if (hrSeries.isNotEmpty) 'hr_samples': hrSeries.map((e) => e.round()).toList(),
        'device_name': device,
      };

  final String id;
  final ActivityType type;
  final DateTime start;
  final Duration duration;
  final double km;
  final int avgHr;
  final int maxHr;
  final int kcal;
  final int steps;
  final List<double> hrSeries;
  final String device;

  Session copyWith({List<double>? hrSeries}) => Session(
        id: id,
        type: type,
        start: start,
        duration: duration,
        km: km,
        avgHr: avgHr,
        maxHr: maxHr,
        kcal: kcal,
        steps: steps,
        hrSeries: hrSeries ?? this.hrSeries,
        device: device,
      );

  /// Ritmo promedio en minutos por kilómetro.
  double? get paceMinPerKm => km > 0 ? duration.inSeconds / 60 / km : null;

  /// Porcentaje aproximado de tiempo en cada zona cardíaca (Z1..Z5).
  List<double> zones({int age = 28}) {
    final maxRef = (220 - age).toDouble();
    final counts = List<double>.filled(5, 0);
    for (final hr in hrSeries) {
      final p = hr / maxRef;
      final z = p < .6 ? 0 : p < .7 ? 1 : p < .8 ? 2 : p < .9 ? 3 : 4;
      counts[z] += 1;
    }
    final total = hrSeries.isEmpty ? 1 : hrSeries.length;
    return counts.map((c) => c / total).toList();
  }
}

enum GoalType {
  steps('steps', 'Pasos', 'pasos', Icons.directions_walk_rounded, 10000),
  distance('distance', 'Distancia', 'km', Icons.timeline_rounded, 15),
  workouts('workouts', 'Entrenamientos', 'entrenamientos', Icons.fitness_center_rounded, 4),
  calories('calories', 'Calorías', 'kcal', Icons.local_fire_department_rounded, 500),
  sleep('sleep', 'Sueño', 'horas', Icons.bedtime_rounded, 8),
  active('active', 'Minutos activos', 'min', Icons.timer_rounded, 60),
  heartRate('heart_rate', 'Ritmo cardíaco', 'bpm', Icons.favorite_rounded, 60),
  weight('weight', 'Peso', 'kg', Icons.monitor_weight_rounded, 60);

  const GoalType(this.apiName, this.label, this.unit, this.icon, this.suggested);
  final String apiName;
  final String label;
  final String unit;
  final IconData icon;
  final double suggested;

  /// Tipos que el usuario puede crear desde la app.
  static const selectable = [steps, distance, workouts, calories, sleep, active];

  /// El servidor calcula el avance a partir de sesiones y del wearable.
  bool get isAuto => this != sleep && this != heartRate && this != weight;

  static GoalType fromApi(Object? name) => values.firstWhere((t) => t.apiName == name, orElse: () => steps);
}

enum GoalPeriod {
  daily('daily'),
  weekly('weekly');

  const GoalPeriod(this.apiName);
  final String apiName;

  static GoalPeriod fromApi(Object? v) => v == 'weekly' ? weekly : daily;
}

class Goal {
  Goal({
    required this.id,
    required this.type,
    required this.title,
    required this.target,
    required this.current,
    required this.period,
    required this.history,
  });

  factory Goal.fromJson(Json j) {
    final type = GoalType.fromApi(j['type']);
    final target = _d(j['target']);
    final period = GoalPeriod.fromApi(j['period']);
    return Goal(
      id: '${j['id']}',
      type: type,
      title: (j['title'] as String?)?.trim().isNotEmpty == true ? j['title'] as String : '${type.label}: ${target.round()}',
      target: target,
      current: _d(j['current']),
      period: period,
      history: _doubles(j['history']),
    );
  }

  final String id;
  final GoalType type;
  String title;
  double target;
  double current;
  GoalPeriod period;

  /// Progreso (0..1) de los últimos 7 días/semanas, del más antiguo al actual.
  final List<double> history;

  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();
  bool get done => target > 0 && current >= target;
  String get periodLabel => period == GoalPeriod.daily ? 'Hoy' : 'Semana';
}

enum NoticeKind {
  goal(Icons.emoji_events_rounded, FP.amber),
  sync(Icons.sync_rounded, FP.green),
  heart(Icons.favorite_rounded, FP.red),
  battery(Icons.battery_alert_rounded, FP.amber),
  session(Icons.check_circle_rounded, FP.green),
  tip(Icons.lightbulb_rounded, FP.indigo);

  const NoticeKind(this.icon, this.color);
  final IconData icon;
  final Color color;

  static NoticeKind fromApi(Object? v) => values.firstWhere((k) => k.name == v, orElse: () => tip);
}

class AppNotice {
  AppNotice({required this.id, required this.kind, required this.title, required this.body, required this.time, this.read = false});

  factory AppNotice.fromJson(Json j) => AppNotice(
        id: '${j['id']}',
        kind: NoticeKind.fromApi(j['kind']),
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        time: _date(j['created_at']) ?? DateTime.now(),
        read: j['read'] == true,
      );

  final String id;
  final NoticeKind kind;
  final String title;
  final String body;
  final DateTime time;
  bool read;
}

enum DeviceKind { band, watch, phone }

class Device {
  Device({
    required this.id,
    required this.name,
    required this.model,
    required this.kind,
    required this.battery,
    required this.connected,
    required this.lastSync,
    this.firmware = '2.4.1',
  });

  factory Device.fromJson(Json j) {
    final type = j['type'];
    final name = '${j['name'] ?? 'Dispositivo'}';
    final kind = type == 'phone'
        ? DeviceKind.phone
        : name.toLowerCase().contains('watch')
            ? DeviceKind.watch
            : DeviceKind.band;
    return Device(
      id: '${j['id']}',
      name: name,
      model: switch (type) { 'wearable' => 'Wear OS · BLE', 'phone' => 'Teléfono', 'smarttv' => 'Smart TV', _ => 'Dispositivo' },
      kind: kind,
      battery: _in(j['battery']),
      connected: j['status'] == 'linked',
      lastSync: _date(j['last_sync_at']),
      firmware: '—',
    );
  }

  final String id;
  String name;
  final String model;
  final DeviceKind kind;
  int? battery;
  bool connected;
  DateTime? lastSync;
  final String firmware;
  bool syncing = false;

  IconData get icon => switch (kind) {
        DeviceKind.band => Icons.watch_rounded,
        DeviceKind.watch => Icons.watch_rounded,
        DeviceKind.phone => Icons.smartphone_rounded,
      };

  String get apiType => kind == DeviceKind.phone ? 'phone' : 'wearable';
}

class UserProfile {
  UserProfile({
    required this.name,
    required this.email,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.dailyStepGoal,
    this.role = 'user',
  });

  factory UserProfile.fromJson(Json j) => UserProfile(
        name: '${j['name'] ?? ''}'.trim().isEmpty ? '${j['email']}'.split('@').first : '${j['name']}',
        email: '${j['email'] ?? ''}',
        weightKg: _dn(j['weight_kg']),
        heightCm: _in(j['height_cm']),
        age: _in(j['age']),
        dailyStepGoal: _i(j['daily_step_goal'], 10000),
        role: '${j['role'] ?? 'user'}',
      );

  static UserProfile empty() => UserProfile(name: '', email: '', weightKg: null, heightCm: null, age: null, dailyStepGoal: 10000);

  String name;
  String email;
  double? weightKg;
  int? heightCm;
  int? age;
  int dailyStepGoal;
  String role;

  String get firstName => name.trim().isEmpty ? '' : name.trim().split(' ').first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  bool get hasBodyData => weightKg != null && heightCm != null && heightCm! > 0;

  double? get bmi => hasBodyData ? weightKg! / ((heightCm! / 100) * (heightCm! / 100)) : null;
  String get bmiLabel {
    final b = bmi;
    if (b == null) return 'Sin datos';
    if (b < 18.5) return 'Bajo';
    if (b < 25) return 'Saludable';
    if (b < 30) return 'Sobrepeso';
    return 'Alto';
  }
}

class FoundDevice {
  const FoundDevice(this.name, this.model, this.kind, this.signal);
  final String name;
  final String model;
  final DeviceKind kind;
  final int signal; // 1..4
}

// ───────── Resumen de actividad (GET /api/metrics/summary) ─────────

class DaySummary {
  const DaySummary({required this.date, required this.steps, required this.km, required this.kcal, required this.minutes, required this.sessions});

  factory DaySummary.fromJson(Json j) => DaySummary(
        date: DateTime.tryParse('${j['date']}') ?? DateTime.now(),
        steps: _i(j['steps']),
        km: _d(j['km']),
        kcal: _i(j['kcal']),
        minutes: _i(j['minutes']),
        sessions: _i(j['sessions']),
      );

  final DateTime date;
  final int steps;
  final double km;
  final int kcal;
  final int minutes;
  final int sessions;

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
  String get weekdayLetter => _letters[date.weekday - 1];
}

class TypeTotals {
  const TypeTotals({this.count = 0, this.minutes = 0, this.km = 0});
  factory TypeTotals.fromJson(Json j) => TypeTotals(count: _i(j['count']), minutes: _i(j['minutes']), km: _d(j['km']));
  final int count;
  final int minutes;
  final double km;
}

class ActivitySummary {
  const ActivitySummary({
    required this.todaySteps,
    required this.todayKm,
    required this.todayKcal,
    required this.activeMinutes,
    required this.heartRate,
    required this.days,
    required this.totalKm,
    required this.totalKcal,
    required this.byType,
    required this.restingHr,
    required this.restingDelta,
    required this.restingTrend,
    required this.hrToday,
  });

  factory ActivitySummary.fromJson(Json j) {
    final today = (j['today'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totals = (j['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rest = (j['resting_hr'] as Map?)?.cast<String, dynamic>() ?? const {};
    final types = (j['by_type'] as Map?)?.cast<String, dynamic>() ?? const {};
    final byType = <ActivityType, TypeTotals>{};
    types.forEach((k, v) {
      final t = ActivityType.fromApi(k);
      final prev = byType[t] ?? const TypeTotals();
      final cur = TypeTotals.fromJson((v as Map).cast<String, dynamic>());
      byType[t] = TypeTotals(count: prev.count + cur.count, minutes: prev.minutes + cur.minutes, km: prev.km + cur.km);
    });
    return ActivitySummary(
      todaySteps: _i(today['steps']),
      todayKm: _d(today['km']),
      todayKcal: _i(today['kcal']),
      activeMinutes: _i(today['active_minutes']),
      heartRate: _in(today['heart_rate']),
      days: (j['days'] as List? ?? const []).map((e) => DaySummary.fromJson((e as Map).cast<String, dynamic>())).toList(),
      totalKm: _d(totals['km']),
      totalKcal: _i(totals['kcal']),
      byType: byType,
      restingHr: _in(rest['current']),
      restingDelta: _in(rest['delta']),
      restingTrend: _doubles(rest['trend']),
      hrToday: (j['hr_today'] as List? ?? const []).map((e) => _d((e as Map)['bpm'])).toList(),
    );
  }

  static const empty = ActivitySummary(
    todaySteps: 0,
    todayKm: 0,
    todayKcal: 0,
    activeMinutes: 0,
    heartRate: null,
    days: [],
    totalKm: 0,
    totalKcal: 0,
    byType: {},
    restingHr: null,
    restingDelta: null,
    restingTrend: [],
    hrToday: [],
  );

  final int todaySteps;
  final double todayKm;
  final int todayKcal;
  final int activeMinutes;
  final int? heartRate;
  final List<DaySummary> days;
  final double totalKm;
  final int totalKcal;
  final Map<ActivityType, TypeTotals> byType;
  final int? restingHr;
  final int? restingDelta;
  final List<double> restingTrend;
  final List<double> hrToday;
}
