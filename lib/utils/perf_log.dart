import 'dart:async';
import 'dart:ui' show FrameTiming, PlatformDispatcher;

import 'package:flutter/scheduler.dart';

/// Instrumentación de la Práctica 12 (profiling en el teléfono, también en release).
///
/// Solo se activa al compilar con `--dart-define=FP_PERF=true`; si no, todo es no-op.
/// Escribe líneas `FP-PERF …` en logcat (etiqueta `flutter`) que el script
/// `tests/perfil-android.ps1` recoge y resume:
///   - cada solicitud HTTP: método, ruta, código, ms de red, ms de decodificación JSON, bytes;
///   - cada 5 s con actividad: cuadros dibujados, tiempos de build/raster y cuadros con jank;
///   - cambios de pestaña (navegación) y operaciones marcadas con [PerfLog.op].
class PerfLog {
  static const enabled = bool.fromEnvironment('FP_PERF');

  static final List<FrameTiming> _frames = [];
  static Timer? _timer;

  static void _emit(String line) {
    // print llega a logcat aun en release; debugPrint se puede silenciar.
    // ignore: avoid_print
    print('FP-PERF $line');
  }

  /// Empieza a recolectar los tiempos de cada cuadro (FrameTiming del motor).
  static void start() {
    if (!enabled || _timer != null) return;
    final hz = PlatformDispatcher.instance.views.firstOrNull?.display.refreshRate ?? 60;
    _emit('inicio refresco=${hz.round()}Hz presupuesto=${(1000 / hz).toStringAsFixed(1)}ms');
    SchedulerBinding.instance.addTimingsCallback(_frames.addAll);
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _flushFrames(1000 / hz));
  }

  static void _flushFrames(double budgetMs) {
    if (_frames.isEmpty) return;
    double ms(Duration d) => d.inMicroseconds / 1000;
    final build = _frames.map((f) => ms(f.buildDuration)).toList()..sort();
    final raster = _frames.map((f) => ms(f.rasterDuration)).toList()..sort();
    final total = _frames.map((f) => ms(f.totalSpan)).toList()..sort();
    final jank = _frames.where((f) => ms(f.buildDuration) > budgetMs || ms(f.rasterDuration) > budgetMs).length;
    final slow = total.where((t) => t > 100).length; // cuadros > 100 ms: congelamiento visible
    String p(List<double> v, double q) => v[((v.length - 1) * q).round()].toStringAsFixed(1);
    _emit('cuadros n=${_frames.length} jank=$jank lentos100=$slow '
        'build_p50=${p(build, .5)} build_p90=${p(build, .9)} build_max=${build.last.toStringAsFixed(1)} '
        'raster_p50=${p(raster, .5)} raster_p90=${p(raster, .9)} raster_max=${raster.last.toStringAsFixed(1)} '
        'total_p90=${p(total, .9)} total_max=${total.last.toStringAsFixed(1)}');
    _frames.clear();
  }

  static void http(String method, String path, int status, int netMs, int decodeMs, int bytes) {
    if (enabled) _emit('http $method $path $status red=${netMs}ms json=${decodeMs}ms bytes=$bytes');
  }

  static void httpError(String method, String path, String kind, int ms) {
    if (enabled) _emit('http $method $path ERROR=$kind tras=${ms}ms');
  }

  static void event(String what) {
    if (enabled) _emit('evento $what');
  }

  /// Mide una operación de la app (incluye red + procesamiento + estado).
  static Future<T> op<T>(String name, Future<T> Function() fn) async {
    if (!enabled) return fn();
    final sw = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      _emit('op $name ${sw.elapsedMilliseconds}ms');
    }
  }
}
