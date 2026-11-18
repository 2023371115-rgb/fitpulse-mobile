// Prácticas 13 y 14 · AUT-05 La pantalla de inicio de sesión muestra un mensaje adecuado
// cuando el servidor falla (integración pantalla → AppState → repositorio → ApiClient).
// El servidor se simula en el cliente HTTP para controlar el tiempo con el reloj de la prueba.
import 'dart:io';

import 'package:fitpulse_mobile/api/api_client.dart';
import 'package:fitpulse_mobile/api/fitpulse_api.dart';
import 'package:fitpulse_mobile/screens/auth_screen.dart';
import 'package:fitpulse_mobile/services/local_store.dart';
import 'package:fitpulse_mobile/state/app_state.dart';
import 'package:fitpulse_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Future<void> openLogin(WidgetTester tester, Future<http.Response> Function(http.Request) server) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final api = FitPulseApi(ApiClient(baseUrl: 'http://fitpulse.test/api', httpClient: MockClient(server), retry: RetryPolicy.none));
  final state = AppState(store: LocalStore.memory(), api: api);
  await tester.pumpWidget(AppScope(state: state, child: MaterialApp(theme: buildFitPulseTheme(), home: const AuthScreen())));
  await tester.enterText(find.byType(TextFormField).at(0), 'ana@correo.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'fitpulse123');
  await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
}

void main() {
  testWidgets('servidor sin respuesta: tras 15 s ofrece revisar el servidor o usar el modo demo', (tester) async {
    await openLogin(tester, (_) => Future.delayed(const Duration(seconds: 30), () => http.Response('{}', 200)));
    await tester.pump(const Duration(seconds: 14));
    expect(find.text('Sin conexión'), findsNothing, reason: 'todavía dentro del límite de 15 s');
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.textContaining('El servidor tardó demasiado en responder'), findsOneWidget);
    expect(find.text('Modo demo'), findsOneWidget);
    await tester.pump(const Duration(seconds: 20)); // deja terminar la respuesta tardía
  });

  testWidgets('sin red: el mismo diálogo con el mensaje de conexión', (tester) async {
    await openLogin(tester, (_) async => throw const SocketException('Network is unreachable'));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.textContaining('No se pudo conectar con el servidor'), findsOneWidget);
  });

  testWidgets('contraseña incorrecta (401): mensaje en el formulario, sin diálogo', (tester) async {
    await openLogin(tester, (_) async => http.Response('{"error":"invalid credentials"}', 401));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('auth-error')), findsOneWidget);
    expect(find.text('Correo o contraseña incorrectos. Revisa tus datos e inténtalo de nuevo.'), findsOneWidget);
    expect(find.text('Sin conexión'), findsNothing);
  });

  testWidgets('error 500: mensaje genérico y el formulario conserva lo escrito', (tester) async {
    await openLogin(tester, (_) async => http.Response('{"error":"ER_ACCESS_DENIED"}', 500));
    await tester.pumpAndSettle();
    expect(find.text('Ocurrió un problema en el servidor. Intenta más tarde.'), findsOneWidget);
    expect(find.text('ana@correo.com'), findsOneWidget);
  });
}
