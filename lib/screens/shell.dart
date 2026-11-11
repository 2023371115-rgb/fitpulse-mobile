import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/perf_log.dart';
import '../widgets/common.dart';
import 'activity_screen.dart';
import 'auth_screen.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';

/// Navegación principal con 4 pestañas (Inicio, Actividad, Metas, Perfil).
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _index = 0;
  AppState? _app;

  void _go(int i) {
    PerfLog.event('pestaña $_index→$i');
    setState(() => _index = i);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.read(context);
    if (_app != app) {
      _app?.sessionExpired.removeListener(_onExpired);
      _app = app..sessionExpired.addListener(_onExpired);
    }
  }

  @override
  void dispose() {
    _app?.sessionExpired.removeListener(_onExpired);
    super.dispose();
  }

  void _onExpired() {
    if (!mounted || _app?.sessionExpired.value != true) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false);
    toast(context, 'Tu sesión expiró. Vuelve a iniciar sesión.', icon: Icons.lock_clock_rounded);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack conserva las 4 pestañas vivas (no se pierde el estado al cambiar), pero sus
      // animaciones seguían corriendo aunque no se vieran. TickerMode las pausa fuera de pantalla
      // (Práctica 12: la app redibujaba ~46 cuadros/s sin parar y usaba ~61 % de un núcleo).
      body: IndexedStack(index: _index, children: [
        for (final (i, tab) in [
          HomeScreen(onStartActivity: () => _go(1), onOpenGoals: () => _go(2)),
          const ActivityScreen(),
          const GoalsScreen(),
          const ProfileScreen(),
        ].indexed)
          TickerMode(enabled: i == _index, child: tab),
      ]),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: FP.border))),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _go,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
            NavigationDestination(icon: Icon(Icons.bolt_outlined), selectedIcon: Icon(Icons.bolt_rounded), label: 'Actividad'),
            NavigationDestination(icon: Icon(Icons.flag_outlined), selectedIcon: Icon(Icons.flag_rounded), label: 'Metas'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
