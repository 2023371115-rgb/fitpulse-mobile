import 'dart:async';
import 'dart:math';

import '../data/models.dart';

/// Lectura de sensores del wearable.
///
/// [steps] son los pasos nuevos desde la lectura anterior; el backend los suma
/// a los de las sesiones para calcular los pasos del día.
class WearableReading {
  const WearableReading({required this.steps, required this.heartRate, required this.battery, this.spo2, this.movement});

  final int steps;
  final int heartRate;
  final int battery;
  final int? spo2;

  /// Intensidad de movimiento del acelerómetro (0..1).
  final double? movement;

  /// Cuerpo para POST /api/devices/:id/metrics/user
  Map<String, dynamic> toApi() => {
        'steps': steps,
        'heart_rate': heartRate,
        'battery': battery,
        if (spo2 != null) 'spo2': spo2,
        if (movement != null) 'extra': {'movement': double.parse(movement!.toStringAsFixed(2))},
      };
}

/// Contrato de comunicación con el wearable.
///
/// La app solo depende de esta interfaz. En la Unidad 3 se agregará una
/// implementación real (Bluetooth LE / Wear OS Data Layer) sin cambiar las
/// pantallas:
///
///   Wearable → Sensores/Bluetooth → Flutter → API → MySQL
abstract class WearableService {
  /// Busca dispositivos cercanos. Emite cada dispositivo conforme se encuentra.
  Stream<FoundDevice> scan({Duration timeout = const Duration(seconds: 4)});

  /// Establece la conexión con un dispositivo encontrado.
  Future<void> connect(FoundDevice device);

  /// Lee los sensores del dispositivo vinculado (pasos, ritmo, batería…).
  Future<WearableReading> read(Device device);

  /// Ritmo cardíaco en vivo durante una actividad.
  Stream<int> heartRate(Device device, {int base = 72});
}

/// Implementación simulada usada en esta etapa del proyecto.
///
/// Genera valores realistas para probar el flujo completo
/// (lectura → API → base de datos → métricas y notificaciones).
class SimulatedWearableService implements WearableService {
  SimulatedWearableService({Random? random}) : _rnd = random ?? Random();

  final Random _rnd;
  final Map<String, int> _battery = {};

  static const nearby = [
    FoundDevice('FitPulse Watch S2', 'FP-W2 · Wear OS', DeviceKind.watch, 4),
    FoundDevice('Galaxy Watch 7', 'Samsung · Wear OS', DeviceKind.watch, 3),
    FoundDevice('Mi Smart Band 9', 'Xiaomi · BLE', DeviceKind.band, 2),
  ];

  @override
  Stream<FoundDevice> scan({Duration timeout = const Duration(seconds: 4)}) async* {
    final step = Duration(milliseconds: timeout.inMilliseconds ~/ (nearby.length + 1));
    for (final d in nearby) {
      await Future<void>.delayed(step);
      yield d;
    }
  }

  @override
  Future<void> connect(FoundDevice device) => Future<void>.delayed(const Duration(milliseconds: 1500));

  @override
  Future<WearableReading> read(Device device) async {
    // Conexión por Bluetooth y lectura de sensores
    await Future<void>.delayed(const Duration(milliseconds: 2200));
    final battery = (_battery[device.id] ?? device.battery ?? 90) - _rnd.nextInt(2);
    _battery[device.id] = battery.clamp(5, 100).toInt();
    return WearableReading(
      steps: 80 + _rnd.nextInt(240),
      heartRate: 66 + _rnd.nextInt(12),
      battery: _battery[device.id]!,
      spo2: 96 + _rnd.nextInt(4),
      movement: _rnd.nextDouble(),
    );
  }

  @override
  Stream<int> heartRate(Device device, {int base = 72}) async* {
    var hr = base - 20;
    while (true) {
      await Future<void>.delayed(const Duration(seconds: 1));
      hr = (hr + (base - hr) * .1 + _rnd.nextInt(5) - 2).round().clamp(50, 195).toInt();
      yield hr;
    }
  }
}
