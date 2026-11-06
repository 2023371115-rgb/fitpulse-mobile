import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Widget de FitPulse en la pantalla de inicio del teléfono (Android).
///
/// La app le manda los datos del día por el canal `fitpulse/widget`; el código
/// nativo (android/.../FitPulseWidget.kt) los guarda y redibuja el widget.
/// En web, iOS o escritorio no hace nada.
class HomeWidgetService {
  HomeWidgetService._();

  static const _channel = MethodChannel('fitpulse/widget');

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Al cerrar sesión el widget deja de mostrar los datos del usuario.
  static Future<void> clear() async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('clear');
    } on MissingPluginException {
      // sin código nativo
    } on PlatformException catch (e) {
      debugPrint('Widget no limpiado: ${e.message}');
    }
  }

  static Future<void> update({
    required String name,
    required int steps,
    required int stepGoal,
    required int calories,
    int? heartRate,
    String? lastSession,
  }) async {
    if (!supported) return;
    try {
      await _channel.invokeMethod('update', {
        'name': name,
        'steps': steps,
        'goal': stepGoal <= 0 ? 10000 : stepGoal,
        'calories': calories,
        'heartRate': heartRate,
        'lastSession': lastSession,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // Pruebas o plataforma sin el código nativo.
    } on PlatformException catch (e) {
      debugPrint('Widget no actualizado: ${e.message}');
    }
  }
}
