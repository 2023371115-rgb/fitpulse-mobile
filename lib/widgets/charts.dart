import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Anillo de progreso animado (pasos del día, metas).
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.value, this.size = 110, this.stroke = 12, this.color = FP.red, this.track = FP.track, this.child});
  final double value;
  final double size;
  final double stroke;
  final Color color;
  final Color track;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0).toDouble();
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: v),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(progress: t, color: color, track: track, stroke: stroke),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track, required this.stroke});
  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * pi, false, base);
    if (progress <= 0) return;
    final fg = Paint()
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [color.withValues(alpha: .75), color],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -pi / 2, 2 * pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.progress != progress || old.color != color;
}

/// Barra de progreso horizontal animada.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.color = FP.red, this.height = 9, this.track = FP.track});
  final double value;
  final Color color;
  final double height;
  final Color track;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, __) => Container(
          height: height,
          decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(height)),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: t,
            child: Container(decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height))),
          ),
        ),
      );
}

/// Gráfica de barras con selección al tocar (pasos por día).
class FpBarChart extends StatefulWidget {
  const FpBarChart({
    super.key,
    required this.values,
    required this.labels,
    this.highlight,
    this.height = 170,
    this.goal,
    this.format,
    this.color = FP.mint,
    this.highlightColor = FP.red,
    this.showEveryLabel = 1,
  });

  final List<double> values;
  final List<String> labels;
  final int? highlight;
  final double height;
  final double? goal;
  final String Function(double)? format;
  final Color color;
  final Color highlightColor;
  final int showEveryLabel;

  @override
  State<FpBarChart> createState() => _FpBarChartState();
}

class _FpBarChartState extends State<FpBarChart> {
  int? _selected;

  @override
  void didUpdateWidget(covariant FpBarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final maxV = max(values.fold<double>(0, max), widget.goal ?? 0) * 1.08;
    const labelH = 22.0;
    const tipH = 24.0;
    final barArea = widget.height - labelH - tipH;
    final n = values.length;
    final gapW = n > 12 ? 3.0 : 10.0;

    return SizedBox(
      height: widget.height,
      child: Stack(children: [
        if (widget.goal != null && maxV > 0)
          Positioned(
            left: 0,
            right: 0,
            top: tipH + barArea - barArea * (widget.goal! / maxV),
            child: Row(children: [
              Expanded(child: CustomPaint(painter: _DashPainter(), size: const Size(double.infinity, 1))),
              const SizedBox(width: 6),
              const Text('Meta', style: TextStyle(fontSize: 10.5, color: FP.muted, fontWeight: FontWeight.w700)),
            ]),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (var i = 0; i < n; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _selected = _selected == i ? null : i),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: gapW / 2),
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      SizedBox(
                        height: tipH,
                        child: _selected == i
                            ? FittedBox(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: FP.ink, borderRadius: BorderRadius.circular(6)),
                                  child: Text(
                                    widget.format?.call(values[i]) ?? values[i].round().toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              )
                            : null,
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: maxV == 0 ? 0 : values[i] / maxV),
                        duration: Duration(milliseconds: 700 + i * (n > 12 ? 15 : 60)),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, __) {
                          final isHi = i == (_selected ?? widget.highlight);
                          return Container(
                            height: max(4.0, barArea * t),
                            decoration: BoxDecoration(
                              color: isHi ? widget.highlightColor : widget.color,
                              borderRadius: BorderRadius.circular(n > 12 ? 3 : 7),
                            ),
                          );
                        },
                      ),
                      SizedBox(
                        height: labelH,
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: i % widget.showEveryLabel == 0 || i == n - 1
                              ? Text(
                                  widget.labels[i],
                                  maxLines: 1,
                                  overflow: TextOverflow.visible,
                                  softWrap: false,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: i == (_selected ?? widget.highlight) ? FP.ink : FP.muted,
                                    fontWeight: i == (_selected ?? widget.highlight) ? FontWeight.w800 : FontWeight.w500,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = FP.subtle
      ..strokeWidth = 1;
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(min(x + 4, size.width), 0), p);
      x += 8;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Gráfica de línea suave con relleno degradado (ritmo cardíaco).
class FpLineChart extends StatelessWidget {
  const FpLineChart({super.key, required this.data, this.color = FP.red, this.height = 120, this.fill = true, this.showDots = false, this.strokeWidth = 2.6, this.animate = true});
  final List<double> data;
  final Color color;
  final double height;
  final bool fill;
  final bool showDots;
  final double strokeWidth;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (data.length < 2) return SizedBox(height: height);
    Widget chart(double t) => SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(painter: _LinePainter(data: data, color: color, fill: fill, t: t, dots: showDots, strokeWidth: strokeWidth)),
        );
    if (!animate) return chart(1);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, t, __) => chart(t),
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({required this.data, required this.color, required this.fill, required this.t, required this.dots, required this.strokeWidth});
  final List<double> data;
  final Color color;
  final bool fill;
  final double t;
  final bool dots;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = data.reduce(min);
    final hi = data.reduce(max);
    final span = (hi - lo).abs() < 1 ? 1.0 : hi - lo;
    final padTop = strokeWidth + 4;
    final padBottom = strokeWidth + 2;
    final h = size.height - padTop - padBottom;
    final dx = size.width / (data.length - 1);

    final pts = <Offset>[
      for (var i = 0; i < data.length; i++) Offset(i * dx, padTop + h - (data[i] - lo) / span * h),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1];
      final p1 = pts[i];
      final mx = (p0.dx + p1.dx) / 2;
      line.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));

    if (fill) {
      final area = Path.from(line)
        ..lineTo(pts.last.dx, size.height)
        ..lineTo(0, size.height)
        ..close();
      final shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)],
      ).createShader(Offset.zero & size);
      canvas.drawPath(area, Paint()..shader = shader);
    }

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    if (dots) {
      for (final p in pts) {
        canvas.drawCircle(p, 3.2, Paint()..color = Colors.white);
        canvas.drawCircle(p, 2.2, Paint()..color = color);
      }
    }
    canvas.restore();

    // Punto final destacado
    if (t >= 1) {
      final last = pts.last;
      canvas.drawCircle(last, 7, Paint()..color = color.withValues(alpha: .2));
      canvas.drawCircle(last, 4, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.t != t || old.data != data || old.color != color;
}

/// Barra apilada horizontal (distribución por tipo de actividad, zonas).
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.parts, this.height = 14});
  final List<(double, Color)> parts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold<double>(0, (a, p) => a + p.$1);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: SizedBox(
        height: height,
        child: Row(children: [
          for (final p in parts)
            if (p.$1 > 0)
              Expanded(
                flex: max(1, (p.$1 / (total == 0 ? 1 : total) * 1000).round()),
                child: Container(color: p.$2, margin: const EdgeInsets.only(right: 2)),
              ),
        ]),
      ),
    );
  }
}

/// Corazón que late (indicador de ritmo cardíaco en vivo).
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({super.key, this.bpm = 72, this.size = 20, this.color = FP.red});
  final int bpm;
  final double size;
  final Color color;

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _period)..repeat();

  Duration get _period => Duration(milliseconds: (60000 / max(widget.bpm, 30)).round());

  @override
  void didUpdateWidget(covariant BeatingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) {
      _c.duration = _period;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, child) {
          final v = _c.value;
          final s = v < .15 ? 1 + v / .15 * .22 : v < .3 ? 1.22 - (v - .15) / .15 * .22 : 1.0;
          return Transform.scale(scale: s, child: child);
        },
        child: Icon(Icons.favorite_rounded, color: widget.color, size: widget.size),
      );
}
