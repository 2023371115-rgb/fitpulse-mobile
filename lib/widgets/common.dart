import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Widget gap([double h = 12]) => SizedBox(height: h);
Widget hgap([double w = 12]) => SizedBox(width: w);

void push(BuildContext context, Widget page) => Navigator.of(context).push(fadeRoute(page));

/// Transición suave (fade + slide) usada en toda la app.
Route<T> fadeRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, .04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    );

void toast(BuildContext context, String message, {IconData icon = Icons.check_circle_rounded}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(icon, color: FP.mint, size: 20),
        hgap(10),
        Expanded(child: Text(message)),
      ]),
      duration: const Duration(milliseconds: 2200),
    ));
}

/// Logotipo: marca con línea de pulso + "Fit" "Pulse".
class FpLogo extends StatelessWidget {
  const FpLogo({super.key, this.size = 32, this.showText = true, this.textSize});
  final double size;
  final bool showText;
  final double? textSize;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: FP.red,
        borderRadius: BorderRadius.circular(size * .3),
        boxShadow: [BoxShadow(color: FP.red.withValues(alpha: .28), blurRadius: size * .4, offset: Offset(0, size * .12))],
      ),
      child: CustomPaint(painter: PulseMarkPainter(color: Colors.white, strokeWidth: size * .085)),
    );
    if (!showText) return mark;
    final ts = textSize ?? size * .9;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      mark,
      hgap(size * .32),
      RichText(
        text: TextSpan(
          style: TextStyle(fontSize: ts, fontWeight: FontWeight.w800, color: FP.ink, letterSpacing: -0.6),
          children: const [
            TextSpan(text: 'Fit'),
            TextSpan(text: 'Pulse', style: TextStyle(color: FP.red)),
          ],
        ),
      ),
    ]);
  }
}

/// Línea de pulso del logotipo. Mismos puntos que el SVG de la web.
class PulseMarkPainter extends CustomPainter {
  PulseMarkPainter({required this.color, required this.strokeWidth, this.progress = 1});
  final Color color;
  final double strokeWidth;
  final double progress;

  static const _pts = [
    Offset(2, 13), Offset(7, 13), Offset(9.5, 6.5), Offset(12.5, 19), Offset(15, 10), Offset(16.8, 13), Offset(22, 13),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 24, sy = size.height / 24;
    final path = Path()..moveTo(_pts.first.dx * sx, _pts.first.dy * sy);
    for (final p in _pts.skip(1)) {
      path.lineTo(p.dx * sx, p.dy * sy);
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    if (progress >= 1) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(covariant PulseMarkPainter old) => old.progress != progress || old.color != color;
}

/// Tarjeta base (fondo gris-menta, esquinas de 16 px).
class FpCard extends StatelessWidget {
  const FpCard({super.key, required this.child, this.color = FP.card, this.padding = const EdgeInsets.all(16), this.onTap, this.radius = FP.radius, this.border});
  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final BoxBorder? border;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(borderRadius: shape, border: border),
      child: Material(
        color: color,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// Etiqueta pequeña (p. ej. "Correr", "Activo", "Cumplida").
class FpTag extends StatelessWidget {
  const FpTag(this.text, {super.key, this.color = FP.mint, this.textColor = FP.ink, this.icon});
  final String text;
  final Color color;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 14, color: textColor), hgap(4)],
          Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
        ]),
      );
}

/// Botón tipo píldora para filtros y selección (rojo cuando está activo).
class FpPill extends StatelessWidget {
  const FpPill(this.label, {super.key, required this.selected, required this.onTap, this.icon, this.dense = false});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: dense ? 14 : 18, vertical: dense ? 8 : 11),
          decoration: BoxDecoration(
            color: selected ? FP.red : FP.mint,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected ? [BoxShadow(color: FP.red.withValues(alpha: .25), blurRadius: 12, offset: const Offset(0, 4))] : const [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Icon(icon, size: 18, color: selected ? Colors.white : FP.ink), hgap(6)],
            Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: dense ? 13 : 14, color: selected ? Colors.white : FP.ink)),
          ]),
        ),
      );
}

/// Icono dentro de un cuadro redondeado de color suave.
class IconBadge extends StatelessWidget {
  const IconBadge(this.icon, {super.key, this.color = FP.ink, this.background, this.size = 44});
  final IconData icon;
  final Color color;
  final Color? background;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(size * .3),
        ),
        child: Icon(icon, color: color, size: size * .52),
      );
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Row(children: [
          Expanded(child: Text(title, style: T.h3)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: const TextStyle(color: FP.red, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
        ]),
      );
}

/// Valor grande + etiqueta, usado en tarjetas de métricas.
class StatBlock extends StatelessWidget {
  const StatBlock({super.key, required this.label, required this.value, this.unit, this.valueColor = FP.ink, this.size = 24, this.center = false});
  final String label;
  final String value;
  final String? unit;
  final Color valueColor;
  final double size;
  final bool center;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: T.muted),
          gap(4),
          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: value,
                style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: valueColor, letterSpacing: -0.4, fontFeatures: const [FontFeature.tabularFigures()]),
              ),
              if (unit != null) TextSpan(text: ' $unit', style: TextStyle(fontSize: size * .55, fontWeight: FontWeight.w700, color: valueColor)),
            ]),
          ),
        ],
      );
}

/// Página estándar con título grande.
class FpPage extends StatelessWidget {
  const FpPage({super.key, required this.title, required this.children, this.actions, this.subtitle, this.padding = const EdgeInsets.fromLTRB(20, 4, 20, 28), this.showBack});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final List<Widget>? actions;
  final EdgeInsets padding;
  final bool? showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: showBack ?? true,
          title: Text(title),
          actions: actions,
          bottom: subtitle == null
              ? null
              : PreferredSize(
                  preferredSize: const Size.fromHeight(22),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                    child: Align(alignment: Alignment.centerLeft, child: Text(subtitle!, style: T.muted)),
                  ),
                ),
        ),
        body: ListView(padding: padding, children: children),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        child: Column(children: [
          IconBadge(icon, color: FP.muted, background: FP.card, size: 72),
          gap(16),
          Text(title, style: T.h3, textAlign: TextAlign.center),
          gap(6),
          Text(message, style: T.muted, textAlign: TextAlign.center),
        ]),
      );
}

/// Botón secundario en tono menta (Pausar, Cerrar sesión, etc.).
class MintButton extends StatelessWidget {
  const MintButton({super.key, required this.label, required this.onPressed, this.icon, this.color = FP.mint, this.textColor = FP.ink});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: textColor),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 20), hgap(8)],
          Text(label),
        ]),
      );
}

Future<bool> confirmDialog(BuildContext context, {required String title, required String message, String confirm = 'Confirmar', bool destructive = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: T.h2),
      content: Text(message, style: T.muted),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(minimumSize: const Size(110, 46), backgroundColor: destructive ? FP.redDark : FP.red),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r ?? false;
}
