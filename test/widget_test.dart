import 'package:flutter_test/flutter_test.dart';

import 'package:fitpulse_mobile/main.dart';
import 'package:fitpulse_mobile/state/app_state.dart';

void main() {
  testWidgets('La app arranca y muestra la marca FitPulse', (WidgetTester tester) async {
    await tester.pumpWidget(FitPulseApp(state: AppState()));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('Tu actividad, en cada latido'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  test('El estado simulado actualiza metas al guardar una sesión', () {
    final app = AppState();
    final before = app.todaySteps;
    final s = app.buildSession(
      type: app.sessions.first.type,
      seconds: 1200,
      km: 3.2,
      hr: const [120, 130, 140, 150, 145, 150, 155, 150],
      kcal: 210,
      steps: 3000,
    );
    app.addSession(s);
    expect(app.todaySteps, before + 3000);
    expect(app.sessions.first.id, s.id);
    expect(app.unreadCount, greaterThan(0));
  });
}
