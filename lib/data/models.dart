import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Tipos de actividad física. Coinciden con el ENUM `sessions.type` del backend
/// (running, walking, cycling, gym) para facilitar la conexión en la Unidad 2.
enum ActivityType {
  running('Correr', 'Carrera', Icons.directions_run_rounded, FP.red, 150, 1 / 360, 10.5, 2.7),
  walking('Caminar', 'Caminata', Icons.directions_walk_rounded, FP.green, 102, 1 / 690, 4.6, 1.8),
  cycling('Bici', 'Bicicleta', Icons.directions_bike_rounded, FP.amber, 132, 1 / 150, 8.4, 0),
  gym('Fuerza', 'Fuerza', Icons.fitness_center_rounded, FP.indigo, 118, 0, 6.2, 0.3);

  const ActivityType(this.label, this.title, this.icon, this.color, this.baseHr, this.kmPerSecond, this.kcalPerMinute, this.stepsPerSecond);

  final String label;
  final String title;
  final IconData icon;
  final Color color;
  final int baseHr;
  final double kmPerSecond;
  final double kcalPerMinute;
  final double stepsPerSecond;

  bool get hasDistance => kmPerSecond > 0;
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

  /// Ritmo promedio en minutos por kilómetro.
  double? get paceMinPerKm => km > 0 ? duration.inSeconds / 60 / km : null;

  /// Porcentaje aproximado de tiempo en cada zona cardíaca (Z1..Z5).
  List<double> get zones {
    final maxRef = 192.0; // 220 - 28 años
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
  steps('Pasos', 'pasos', Icons.directions_walk_rounded, 10000),
  distance('Distancia', 'km', Icons.timeline_rounded, 15),
  workouts('Entrenamientos', 'entrenamientos', Icons.fitness_center_rounded, 4),
  calories('Calorías', 'kcal', Icons.local_fire_department_rounded, 500),
  sleep('Sueño', 'horas', Icons.bedtime_rounded, 8),
  active('Minutos activos', 'min', Icons.timer_rounded, 60);

  const GoalType(this.label, this.unit, this.icon, this.suggested);
  final String label;
  final String unit;
  final IconData icon;
  final double suggested;
}

enum GoalPeriod { daily, weekly }

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

  final String id;
  final GoalType type;
  String title;
  double target;
  double current;
  GoalPeriod period;

  /// Progreso (0..1) de los últimos 7 días/semanas, para la mini gráfica.
  final List<double> history;

  double get progress => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0).toDouble();
  bool get done => current >= target;
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
}

class AppNotice {
  AppNotice({required this.id, required this.kind, required this.title, required this.body, required this.time, this.read = false});
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

  final String id;
  String name;
  final String model;
  final DeviceKind kind;
  int battery;
  bool connected;
  DateTime lastSync;
  final String firmware;
  bool syncing = false;

  IconData get icon => switch (kind) {
        DeviceKind.band => Icons.watch_rounded,
        DeviceKind.watch => Icons.watch_rounded,
        DeviceKind.phone => Icons.smartphone_rounded,
      };
}

class UserProfile {
  UserProfile({required this.name, required this.email, required this.weightKg, required this.heightCm, required this.age, required this.dailyStepGoal});
  String name;
  String email;
  double weightKg;
  int heightCm;
  int age;
  int dailyStepGoal;

  String get firstName => name.trim().split(' ').first;
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  double get bmi => weightKg / ((heightCm / 100) * (heightCm / 100));
  String get bmiLabel {
    final b = bmi;
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
