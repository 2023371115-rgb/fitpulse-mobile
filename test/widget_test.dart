import 'package:flutter_test/flutter_test.dart';

import 'package:fitpulse_mobile/data/models.dart';
import 'package:fitpulse_mobile/data/repository.dart';
import 'package:fitpulse_mobile/main.dart';
import 'package:fitpulse_mobile/services/local_store.dart';
import 'package:fitpulse_mobile/state/app_state.dart';

void main() {
  testWidgets('La app arranca y muestra la marca FitPulse', (WidgetTester tester) async {
    await tester.pumpWidget(FitPulseApp(state: AppState(store: LocalStore.memory())));
    await tester.pump(const Duration(milliseconds: 1800));
    expect(find.text('Tu actividad, en cada latido'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  test('Modo demo: guardar una sesión actualiza pasos, metas y notificaciones', () async {
    final app = AppState(store: LocalStore.memory(), demo: DemoRepository());
    await app.enterDemo();
    final before = app.todaySteps;
    final unread = app.unreadCount;
    final s = app.buildSession(
      type: ActivityType.running,
      seconds: 1200,
      km: 3.2,
      hr: const [120, 130, 140, 150, 145, 150, 155, 150],
      kcal: 210,
      steps: 3000,
    );
    await app.addSession(s);
    expect(app.todaySteps, before + 3000);
    expect(app.sessions.first.km, 3.2);
    expect(app.unreadCount, greaterThan(unread));
  });

  test('Los modelos se construyen desde el JSON de la API', () {
    final session = Session.fromJson({
      'id': 'abc',
      'type': 'cycling',
      'started_at': '2026-10-27T14:00:00.000Z',
      'duration_sec': 3000,
      'distance_km': 15,
      'avg_heart_rate': 130,
      'max_heart_rate': 150,
      'calories': '400.00',
      'steps': null,
    });
    expect(session.type, ActivityType.cycling);
    expect(session.duration.inMinutes, 50);
    expect(session.kcal, 400);

    final goal = Goal.fromJson({'id': 'g', 'type': 'distance', 'title': 'Correr 15 km', 'target': 15, 'current': 8.7, 'period': 'weekly', 'history': [0.5, 1]});
    expect(goal.period, GoalPeriod.weekly);
    expect(goal.progress, closeTo(0.58, 0.01));
    expect(goal.done, isFalse);
  });
}
