import 'dart:async';
import 'dart:ui' show FrameTiming, PlatformDispatcher;

import 'package:flutter/scheduler.dart';

import 'perf_log.dart';

/// Práctica 12 · Tiempos de cada cuadro (FrameTiming del motor de Flutter) a logcat.
/// Solo con `--dart-define=FP_PERF=true`.
class PerfFrames {
  static final List<FrameTiming> _frames = [];
  static Timer? _timer;

  /// Empieza a recolectar los tiempos de cada cuadro (FrameTiming del motor).
  static void start() {
    if (!PerfLog.enabled || _timer != null) return;
    final hz = PlatformDispatcher.instance.views.firstOrNull?.display.refreshRate ?? 60;
    PerfLog.emit('inicio refresco=${hz.round()}Hz presupuesto=${(1000 / hz).toStringAsFixed(1)}ms');
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
    PerfLog.emit('cuadros n=${_frames.length} jank=$jank lentos100=$slow '
        'build_p50=${p(build, .5)} build_p90=${p(build, .9)} build_max=${build.last.toStringAsFixed(1)} '
        'raster_p50=${p(raster, .5)} raster_p90=${p(raster, .9)} raster_max=${raster.last.toStringAsFixed(1)} '
        'total_p90=${p(total, .9)} total_max=${total.last.toStringAsFixed(1)}');
    _frames.clear();
  }

}
