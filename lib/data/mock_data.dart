import 'dart:math';
import 'models.dart';

/// Datos simulados de FitPulse.
/// Son los mismos que muestra la consola web (src/app/core/mock-data.ts),
/// así ambas aplicaciones cuentan la misma historia de "Ana Torres".
class MockData {
  MockData._();

  static UserProfile user() => UserProfile(
        name: 'Ana Torres',
        email: 'ana@correo.com',
        weightKg: 62,
        heightCm: 165,
        age: 28,
        dailyStepGoal: 10000,
      );

  // Indicadores de hoy
  static const todaySteps = 7240;
  static const todayCalories = 410;
  static const todayKm = 5.1;
  static const activeMinutes = 46;
  static const heartRate = 72;
  static const restingHr = 62;
  static const restingHrDelta = -2;

  /// Pasos de lunes a domingo (domingo = hoy en la maqueta).
  static const weekSteps = <double>[8120, 9650, 5870, 11240, 8430, 12890, 7240];
  static const weekLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  /// Pasos de los últimos 30 días.
  static List<double> monthSteps() {
    final rnd = Random(7);
    return List<double>.generate(30, (i) {
      final weekend = i % 7 == 5 || i % 7 == 6;
      final base = weekend ? 10400.0 : 8200.0;
      return (base + rnd.nextInt(4200) - 2100).roundToDouble();
    })
      ..[29] = 7240;
  }

  /// Ritmo cardíaco en reposo, últimos 14 días.
  static const restingHrTrend = <double>[66, 65, 66, 64, 65, 64, 63, 64, 63, 63, 62, 63, 62, 62];

  /// Ritmo cardíaco de hoy cada hora (06:00 → ahora).
  static const todayHr = <double>[61, 64, 88, 132, 151, 118, 84, 76, 72, 79, 74, 70, 73, 72];

  static List<double> hrSeries(int seed, int base, {int points = 40}) {
    final rnd = Random(seed);
    var hr = base - 30.0;
    return List<double>.generate(points, (i) {
      final target = i < 5 ? base - 30 + i * 6.0 : base + sin(i / 4) * 8;
      hr += (target - hr) * .35 + rnd.nextDouble() * 6 - 3;
      return hr.roundToDouble();
    });
  }

  static List<Session> sessions() {
    final now = DateTime.now();
    DateTime ago(int days, int h, int m) => DateTime(now.year, now.month, now.day, h, m).subtract(Duration(days: days));

    Session s(String id, ActivityType t, int daysAgo, int h, int min, int durMin, double km, int avg, int maxHr, int kcal, int steps) => Session(
          id: id,
          type: t,
          start: ago(daysAgo, h, min),
          duration: Duration(minutes: durMin),
          km: km,
          avgHr: avg,
          maxHr: maxHr,
          kcal: kcal,
          steps: steps,
          hrSeries: hrSeries(id.hashCode, avg),
        );

    return [
      s('s1', ActivityType.running, 0, 7, 10, 32, 4.8, 156, 176, 342, 5180),
      s('s2', ActivityType.walking, 1, 19, 5, 45, 3.9, 104, 121, 198, 5020),
      s('s3', ActivityType.cycling, 3, 8, 30, 70, 18.0, 132, 158, 610, 0),
      s('s4', ActivityType.running, 4, 7, 0, 25, 3.7, 150, 171, 268, 3990),
      s('s5', ActivityType.gym, 5, 18, 40, 50, 0, 118, 149, 290, 820),
      s('s6', ActivityType.walking, 6, 20, 15, 38, 3.2, 98, 112, 160, 4110),
      s('s7', ActivityType.running, 8, 6, 50, 40, 6.1, 158, 179, 430, 6540),
      s('s8', ActivityType.cycling, 10, 17, 20, 55, 14.2, 128, 151, 480, 0),
    ];
  }

  static List<Goal> goals() => [
        Goal(
          id: 'g1',
          type: GoalType.steps,
          title: '10,000 pasos diarios',
          target: 10000,
          current: todaySteps.toDouble(),
          period: GoalPeriod.daily,
          history: const [.81, .97, .59, 1, .84, 1, .72],
        ),
        Goal(
          id: 'g2',
          type: GoalType.distance,
          title: 'Correr 15 km',
          target: 15,
          current: 8,
          period: GoalPeriod.weekly,
          history: const [.9, 1, .74, .62, 1, .8, .53],
        ),
        Goal(
          id: 'g3',
          type: GoalType.workouts,
          title: '4 entrenamientos',
          target: 4,
          current: 3,
          period: GoalPeriod.weekly,
          history: const [1, .75, 1, 1, .5, 1, .75],
        ),
        Goal(
          id: 'g4',
          type: GoalType.sleep,
          title: 'Dormir 8 horas',
          target: 8,
          current: 8,
          period: GoalPeriod.daily,
          history: const [.85, .9, 1, .78, .94, 1, 1],
        ),
      ];

  static List<AppNotice> notices() {
    final now = DateTime.now();
    return [
      AppNotice(id: 'n1', kind: NoticeKind.goal, title: '¡Meta cumplida!', body: 'Llegaste a 10,000 pasos el sábado. ¡Sigue así!', time: now.subtract(const Duration(minutes: 2))),
      AppNotice(id: 'n2', kind: NoticeKind.sync, title: 'Dispositivo sincronizado', body: 'Se guardaron 3 sesiones nuevas desde tu FitPulse Band.', time: now.subtract(const Duration(hours: 1))),
      AppNotice(id: 'n3', kind: NoticeKind.heart, title: 'Ritmo cardíaco alto', body: 'Alcanzaste 176 bpm al correr. Recuerda hidratarte.', time: now.subtract(const Duration(days: 1)), read: true),
      AppNotice(id: 'n4', kind: NoticeKind.battery, title: 'Batería baja', body: 'Tu banda tenía 15%. Ya está cargada al 84%.', time: now.subtract(const Duration(days: 4)), read: true),
      AppNotice(id: 'n5', kind: NoticeKind.tip, title: 'Consejo de la semana', body: 'Caminar 10 minutos después de comer ayuda a mantener tu energía.', time: now.subtract(const Duration(days: 5)), read: true),
    ];
  }

  static List<Device> devices() {
    final now = DateTime.now();
    return [
      Device(id: 'd1', name: 'FitPulse Band', model: 'FP-B1 · Wear OS', kind: DeviceKind.band, battery: 84, connected: true, lastSync: now.subtract(const Duration(minutes: 5))),
      Device(id: 'd2', name: 'Teléfono de Ana', model: 'Android 15', kind: DeviceKind.phone, battery: 61, connected: true, lastSync: now.subtract(const Duration(minutes: 1)), firmware: '1.0.0'),
    ];
  }

  static const nearbyDevices = [
    FoundDevice('FitPulse Watch S2', 'FP-W2 · Wear OS', DeviceKind.watch, 4),
    FoundDevice('Galaxy Watch 7', 'Samsung · Wear OS', DeviceKind.watch, 3),
    FoundDevice('Mi Smart Band 9', 'Xiaomi · BLE', DeviceKind.band, 2),
  ];
}
