import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pc = PageController();
  int _page = 0;

  static const _slides = [
    (
      'Mide tu actividad',
      'Pasos, distancia, calorías y ritmo cardíaco en un solo lugar, todos los días.',
      Icons.directions_run_rounded,
      FP.red,
    ),
    (
      'Cumple tus metas',
      'Define objetivos diarios o semanales y mira tu progreso crecer sesión tras sesión.',
      Icons.emoji_events_rounded,
      FP.green,
    ),
    (
      'Conecta tu wearable',
      'Sincroniza tu smartwatch o banda por Bluetooth y deja que FitPulse registre por ti.',
      Icons.watch_rounded,
      FP.indigo,
    ),
  ];

  void _goAuth({bool register = true}) => Navigator.of(context).pushReplacement(fadeRoute(AuthScreen(register: register)));

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 8, 0),
            child: Row(children: [
              const FpLogo(size: 30, textSize: 22),
              const Spacer(),
              TextButton(onPressed: () => _goAuth(register: false), child: const Text('Omitir', style: TextStyle(color: FP.muted))),
            ]),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pc,
              itemCount: _slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) {
                final s = _slides[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    _Illustration(index: i, icon: s.$3, color: s.$4),
                    gap(40),
                    Text(s.$1, style: T.h1, textAlign: TextAlign.center),
                    gap(12),
                    Text(s.$2, style: T.muted.copyWith(fontSize: 16), textAlign: TextAlign.center),
                  ]),
                );
              },
            ),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 0; i < _slides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: i == _page ? 26 : 8,
                height: 8,
                decoration: BoxDecoration(color: i == _page ? FP.red : FP.track, borderRadius: BorderRadius.circular(8)),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
            child: FilledButton(
              onPressed: () => last ? _goAuth() : _pc.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic),
              child: Text(last ? 'Comenzar' : 'Siguiente'),
            ),
          ),
          TextButton(
            onPressed: () => _goAuth(register: false),
            child: const Text.rich(TextSpan(text: '¿Ya tienes cuenta? ', style: TextStyle(color: FP.muted), children: [
              TextSpan(text: 'Inicia sesión', style: TextStyle(color: FP.red, fontWeight: FontWeight.w800)),
            ])),
          ),
          gap(8),
        ]),
      ),
    );
  }
}

/// Ilustración construida con widgets (no requiere imágenes).
class _Illustration extends StatelessWidget {
  const _Illustration({required this.index, required this.icon, required this.color});
  final int index;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    Widget chip(String text, IconData ic, Color c) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: FP.ink.withValues(alpha: .08), blurRadius: 18, offset: const Offset(0, 6))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ic, size: 18, color: c),
            hgap(6),
            Text(text, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: FP.ink)),
          ]),
        );

    final chips = switch (index) {
      0 => [chip('7,240 pasos', Icons.directions_walk_rounded, FP.green), chip('72 bpm', Icons.favorite_rounded, FP.red)],
      1 => [chip('Meta 72%', Icons.flag_rounded, FP.red), chip('3 de 4', Icons.check_circle_rounded, FP.green)],
      _ => [chip('Conectado', Icons.bluetooth_connected_rounded, FP.blue), chip('84%', Icons.battery_std_rounded, FP.green)],
    };

    return SizedBox(
      width: 280,
      height: 260,
      child: Stack(alignment: Alignment.center, children: [
        Container(width: 240, height: 240, decoration: BoxDecoration(color: color.withValues(alpha: .08), shape: BoxShape.circle)),
        Container(width: 176, height: 176, decoration: BoxDecoration(color: color.withValues(alpha: .14), shape: BoxShape.circle)),
        if (index == 1)
          ProgressRing(value: .72, size: 150, stroke: 14, color: color, child: Icon(icon, size: 56, color: color))
        else
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: .35), blurRadius: 30, offset: const Offset(0, 12))],
            ),
            child: Icon(icon, size: 58, color: Colors.white),
          ),
        Positioned(top: 18, left: 0, child: chips[0]),
        Positioned(bottom: 22, right: 0, child: chips[1]),
      ]),
    );
  }
}
