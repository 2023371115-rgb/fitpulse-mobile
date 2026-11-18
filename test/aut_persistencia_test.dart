// Prácticas 13 y 14 · AUT-06 Persistencia en el teléfono (LocalStore sobre SharedPreferences).
//
// LocalStore guarda el token de la sesión, la dirección del servidor, si ya se vio el
// onboarding y las preferencias. Se prueba con el almacenamiento simulado de
// shared_preferences: lo que se escribe debe leerse igual al "reabrir" la app.
import 'package:fitpulse_mobile/services/local_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('el token y la dirección del servidor se conservan al reabrir la app', () async {
    final store = await LocalStore.open();
    await store.setToken('eyJhbGciOiJIUzI1NiJ9.prueba.firma');
    await store.setApiUrl('http://34.228.70.230/api');

    final reopened = await LocalStore.open();
    expect(reopened.token, 'eyJhbGciOiJIUzI1NiJ9.prueba.firma');
    expect(reopened.apiUrl, 'http://34.228.70.230/api');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('fp_token'), 'eyJhbGciOiJIUzI1NiJ9.prueba.firma', reason: 'se guardó en el almacenamiento real');
  });

  test('cerrar sesión (token nulo) lo borra del almacenamiento', () async {
    final store = await LocalStore.open();
    await store.setToken('t1');
    await store.setToken(null);
    expect(store.token, isNull);
    expect((await SharedPreferences.getInstance()).containsKey('fp_token'), isFalse);
    expect((await LocalStore.open()).token, isNull);
  });

  test('valores por defecto cuando no hay nada guardado', () async {
    final store = await LocalStore.open();
    expect(store.token, isNull);
    expect(store.apiUrl, isNull);
    expect(store.onboardingSeen, isFalse);
    expect(store.pref('share_steps', true), isTrue);
    expect(store.pref('share_steps', false), isFalse);
  });

  test('onboarding y preferencias se guardan como booleanos', () async {
    final store = await LocalStore.open();
    await store.setOnboardingSeen();
    await store.setPref('notice_goals', false);
    final reopened = await LocalStore.open();
    expect(reopened.onboardingSeen, isTrue);
    expect(reopened.pref('notice_goals', true), isFalse);
  });

  test('datos previos de otra versión de la app se leen sin migrar', () async {
    SharedPreferences.setMockInitialValues({'fp_token': 'viejo', 'fp_onboarding_seen': true});
    final store = await LocalStore.open();
    expect(store.token, 'viejo');
    expect(store.onboardingSeen, isTrue);
  });

  test('sin almacenamiento disponible la app funciona en memoria', () async {
    final store = LocalStore.memory();
    await store.setToken('solo-memoria');
    await store.setPref('anonymous_stats', false);
    expect(store.token, 'solo-memoria');
    expect(store.pref('anonymous_stats', true), isFalse);
  });
}
