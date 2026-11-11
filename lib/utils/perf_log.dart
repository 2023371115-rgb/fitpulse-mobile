/// Instrumentación de la Práctica 12 (profiling en el teléfono, también en release).
/// Dart puro (lo usa ApiClient); los tiempos de cuadros están en perf_frames.dart.
///
/// Solo se activa al compilar con `--dart-define=FP_PERF=true`; si no, todo es no-op.
/// Escribe líneas `FP-PERF …` en logcat (etiqueta `flutter`) que el script
/// `tool/perfil-android.ps1` recoge y resume:
///   - cada solicitud HTTP: método, ruta, código, ms de red, ms de decodificación JSON, bytes;
///   - cada 5 s con actividad: cuadros dibujados, tiempos de build/raster y cuadros con jank;
///   - cambios de pestaña (navegación) y operaciones marcadas con [PerfLog.op].
class PerfLog {
  static const enabled = bool.fromEnvironment('FP_PERF');

  static void emit(String line) {
    // print llega a logcat aun en release; debugPrint se puede silenciar.
    // ignore: avoid_print
    print('FP-PERF $line');
  }

  static void http(String method, String path, int status, int netMs, int decodeMs, int bytes) {
    if (enabled) emit('http $method $path $status red=${netMs}ms json=${decodeMs}ms bytes=$bytes');
  }

  static void httpError(String method, String path, String kind, int ms) {
    if (enabled) emit('http $method $path ERROR=$kind tras=${ms}ms');
  }

  static void event(String what) {
    if (enabled) emit('evento $what');
  }

  /// Mide una operación de la app (incluye red + procesamiento + estado).
  static Future<T> op<T>(String name, Future<T> Function() fn) async {
    if (!enabled) return fn();
    final sw = Stopwatch()..start();
    try {
      return await fn();
    } finally {
      emit('op $name ${sw.elapsedMilliseconds}ms');
    }
  }
}
