import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/splash_screen.dart';
import 'services/local_store.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));
  final store = await LocalStore.open();
  runApp(FitPulseApp(state: AppState(store: store)));
}

/// Llave global del navegador: permite volver al login desde cualquier
/// pantalla cuando la sesión expira.
final navigatorKey = GlobalKey<NavigatorState>();

class FitPulseApp extends StatelessWidget {
  const FitPulseApp({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => AppScope(
        state: state,
        child: MaterialApp(
          title: 'FitPulse',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: buildFitPulseTheme(),
          home: const SplashScreen(),
        ),
      );
}
