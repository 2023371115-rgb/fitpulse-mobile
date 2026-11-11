/// Validaciones de formularios (Dart puro, sin dependencias de Flutter).
///
/// Están separadas de las pantallas para poder probarlas con pruebas unitarias
/// (Práctica 11, pruebas white box). Las pantallas solo las conectan a sus campos.
class Validators {
  Validators._();

  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Correo de inicio de sesión y registro.
  static String? email(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Escribe tu correo electrónico';
    if (t.length > 120) return 'Máximo 120 caracteres';
    if (!_emailRe.hasMatch(t)) return 'Correo no válido';
    return null;
  }

  /// Contraseña: 8 a 72 caracteres (72 es el máximo que procesa bcrypt en el servidor).
  static String? password(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Escribe tu contraseña';
    if (v!.length < 8) return 'Mínimo 8 caracteres';
    if (v.length > 72) return 'Máximo 72 caracteres';
    return null;
  }

  /// Número dentro de [lo, hi]. Si [optional] es true, el campo vacío es válido.
  /// Se usa en el perfil para el peso, la estatura y la edad.
  static String? range(String? v, num lo, num hi, String what, {bool optional = false}) {
    if (optional && (v ?? '').trim().isEmpty) return null;
    final n = num.tryParse(v ?? '');
    if (n == null) return 'Escribe tu $what';
    if (n < lo || n > hi) return 'Valor entre $lo y $hi';
    return null;
  }

  /// Puntaje de seguridad de la contraseña, de 0 a 4 (barra de "Seguridad" del registro).
  static int passwordScore(String p) {
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
    return score;
  }
}
