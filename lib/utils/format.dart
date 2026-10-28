/// Utilidades de formato en español (sin dependencias externas).
class Fmt {
  Fmt._();

  static const _days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
  static const _daysShort = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
  static const _months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

  /// 7240 → "7,240"
  static String number(num value) {
    final s = value.round().abs().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return value < 0 ? '-$b' : b.toString();
  }

  static String km(double v) => v.toStringAsFixed(1);

  /// 32 min · 1 h 10 min
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    if (h == 0) return '${d.inMinutes} min';
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// 00:18:42
  static String clock(int seconds) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(seconds ~/ 3600)}:${two((seconds % 3600) ~/ 60)}:${two(seconds % 60)}';
  }

  /// 5:52 /km
  static String pace(double? minPerKm) {
    if (minPerKm == null || minPerKm.isInfinite || minPerKm.isNaN) return '--';
    final total = (minPerKm * 60).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  /// Hoy · Ayer · Lun 21
  static String day(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Hoy';
    if (_sameDay(d, now.subtract(const Duration(days: 1)))) return 'Ayer';
    return '${_daysShort[d.weekday - 1]} ${d.day}';
  }

  /// Ahora · hace 5 min · 1 h · Ayer · Lun
  static String ago(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'Ahora';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ayer';
    return _daysShort[d.weekday - 1];
  }

  /// Viernes 9 de octubre
  static String longDate(DateTime d) => '${_days[d.weekday - 1]} ${d.day} de ${_months[d.month - 1]}';

  /// 07:10
  static String time(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  static String greeting(DateTime d) {
    if (d.hour < 12) return 'Buenos días';
    if (d.hour < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// 8 → "8" · 10000 → "10,000" · 7.2 → "7.2"
  static String compact(double v) => v == v.roundToDouble() ? number(v) : v.toStringAsFixed(1);

  static String goalValue(double v, String unit) {
    final txt = v == v.roundToDouble() ? number(v) : v.toStringAsFixed(1);
    return '$txt $unit';
  }
}
