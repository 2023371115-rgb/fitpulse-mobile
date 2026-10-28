import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import 'shell.dart';

/// Pantalla de arranque: el logotipo "dibuja" su línea de pulso.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1700))..forward();

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Muestra la animación mientras intenta recuperar la sesión guardada.
  Future<void> _start() async {
    final app = AppScope.read(context);
    final results = await Future.wait<Object>([
      app.restoreSession(),
      Future<void>.delayed(const Duration(milliseconds: 2300)).then((_) => true),
    ]);
    if (!mounted) return;
    final restored = results.first == true;
    final Widget next = restored
        ? const Shell()
        : app.store.onboardingSeen
            ? const AuthScreen()
            : const OnboardingScreen();
    Navigator.of(context).pushReplacement(fadeRoute(next));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FP.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final pop = Curves.elasticOut.transform((_c.value / .6).clamp(0.0, 1.0).toDouble());
            final line = Curves.easeInOut.transform(((_c.value - .25) / .6).clamp(0.0, 1.0).toDouble());
            final text = Curves.easeOut.transform(((_c.value - .55) / .45).clamp(0.0, 1.0).toDouble());
            return Column(mainAxisSize: MainAxisSize.min, children: [
              Transform.scale(
                scale: .4 + .6 * pop,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: FP.red,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [BoxShadow(color: FP.red.withValues(alpha: .35), blurRadius: 36, offset: const Offset(0, 14))],
                  ),
                  child: CustomPaint(painter: PulseMarkPainter(color: Colors.white, strokeWidth: 7, progress: line)),
                ),
              ),
              gap(26),
              Opacity(
                opacity: text,
                child: Transform.translate(
                  offset: Offset(0, 12 * (1 - text)),
                  child: Column(children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: FP.ink, letterSpacing: -1),
                        children: [TextSpan(text: 'Fit'), TextSpan(text: 'Pulse', style: TextStyle(color: FP.red))],
                      ),
                    ),
                    gap(6),
                    const Text('Tu actividad, en cada latido', style: T.muted),
                  ]),
                ),
              ),
            ]);
          },
        ),
      ),
    );
  }
}
