import 'package:shared_preferences/shared_preferences.dart';

/// Datos guardados en el teléfono entre sesiones de la app:
/// token de la API, URL del servidor, onboarding visto y preferencias.
///
/// El token es un JWT que expira a las 12 horas; nunca se guardan contraseñas.
class LocalStore {
  LocalStore._(this._prefs);

  final SharedPreferences? _prefs;
  final Map<String, Object> _memory = {};

  static Future<LocalStore> open() async {
    try {
      return LocalStore._(await SharedPreferences.getInstance());
    } catch (_) {
      // Si el almacenamiento no está disponible, la app funciona solo en memoria.
      return LocalStore._(null);
    }
  }

  /// Almacenamiento solo en memoria (pruebas).
  factory LocalStore.memory() => LocalStore._(null);

  static const _token = 'fp_token';
  static const _apiUrl = 'fp_api_url';
  static const _onboarding = 'fp_onboarding_seen';
  static const _prefix = 'fp_pref_';

  String? get token => _prefs?.getString(_token) ?? _memory[_token] as String?;
  Future<void> setToken(String? value) => _setString(_token, value);

  String? get apiUrl => _prefs?.getString(_apiUrl) ?? _memory[_apiUrl] as String?;
  Future<void> setApiUrl(String? value) => _setString(_apiUrl, value);

  bool get onboardingSeen => _prefs?.getBool(_onboarding) ?? _memory[_onboarding] as bool? ?? false;
  Future<void> setOnboardingSeen() => _setBool(_onboarding, true);

  bool pref(String key, bool fallback) => _prefs?.getBool('$_prefix$key') ?? _memory['$_prefix$key'] as bool? ?? fallback;
  Future<void> setPref(String key, bool value) => _setBool('$_prefix$key', value);

  Future<void> _setString(String key, String? value) async {
    if (value == null) {
      _memory.remove(key);
      await _prefs?.remove(key);
    } else {
      _memory[key] = value;
      await _prefs?.setString(key, value);
    }
  }

  Future<void> _setBool(String key, bool value) async {
    _memory[key] = value;
    await _prefs?.setBool(key, value);
  }
}
