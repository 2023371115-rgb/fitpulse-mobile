import 'package:flutter/foundation.dart';

/// Dirección de la API REST.
///
/// Prioridad:
/// 1. La que el usuario guardó en "Servidor" (pantalla de inicio de sesión).
/// 2. `--dart-define=API_URL=...` al compilar.
/// 3. Valor por defecto según la plataforma (backend corriendo en la misma PC):
///    - Emulador de Android: http://10.0.2.2:3000/api (10.0.2.2 = la PC anfitriona)
///    - Windows, web, iOS: http://localhost:3000/api
///
/// Para un teléfono físico usa la IP de la PC en la red local
/// (por ejemplo http://192.168.1.50:3000/api) o el backend publicado.
class ApiConfig {
  ApiConfig._();

  static const fromDefine = String.fromEnvironment('API_URL');

  /// Backend publicado en Render.
  static const production = 'https://fitpulse-backend-r77o.onrender.com/api';

  static String get platformDefault {
    if (fromDefine.isNotEmpty) return fromDefine;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 'http://10.0.2.2:3000/api';
    return 'http://localhost:3000/api';
  }

  /// Normaliza lo que escribe el usuario: agrega http:// y /api si faltan.
  static String normalize(String input) {
    var url = input.trim().replaceAll(RegExp(r'/+$'), '');
    if (url.isEmpty) return platformDefault;
    if (!url.startsWith('http://') && !url.startsWith('https://')) url = 'http://$url';
    if (!url.endsWith('/api')) url = '$url/api';
    return url;
  }
}
