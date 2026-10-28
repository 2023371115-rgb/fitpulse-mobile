# FitPulse · App móvil (Flutter)

App de FitPulse para el usuario. Está conectada a la **API REST de FitPulse** (Node.js + Express + MySQL) del repositorio [`fitpulse-backend`](https://github.com/2023371115-rgb/fitpulse-backend). Comparte diseño y datos de ejemplo con la consola web.

```
App Flutter → API REST → Node.js/Express → MySQL
Wearable → Sensores/Bluetooth → Flutter → API → MySQL   (estructura lista; integración real en la Unidad 3)
```

Entregable 2: ver [`docs/ENTREGABLE_2.md`](docs/ENTREGABLE_2.md).

## Ejecutar

1. Levanta el backend (en el repositorio `fitpulse-backend`):

   ```bash
   npm install
   npm run migrate
   npm run seed     # cuenta demo: ana@correo.com / fitpulse123
   npm run dev      # http://localhost:3000
   ```

2. Ejecuta la app:

   ```bash
   flutter pub get
   flutter run
   ```

3. En la pantalla de inicio de sesión toca **"Usar cuenta demo"** y luego **"Iniciar sesión"**, o crea una cuenta nueva.

### Dirección del servidor

| Dónde corre la app | Dirección de la API |
|---|---|
| Emulador de Android | `http://10.0.2.2:3000/api` (valor por defecto) |
| Windows, Chrome, iOS | `http://localhost:3000/api` (valor por defecto) |
| Teléfono físico | `http://IP-DE-TU-PC:3000/api` (misma red Wi-Fi) |
| Backend publicado | `https://fitpulse-backend-r77o.onrender.com/api` |

Para cambiarla sin volver a compilar, toca el ícono de **servidor** (arriba a la derecha en el inicio de sesión). Ahí puedes probar la conexión y guardar la dirección. También se puede fijar al compilar:

```bash
flutter run --dart-define=API_URL=http://192.168.1.50:3000/api
```

### Modo demo (sin conexión)

Si el servidor no está disponible, la app ofrece **"Explorar sin conexión (modo demo)"**. Todo funciona con datos de ejemplo guardados solo en el teléfono, lo que sirve para presentaciones.

## Funciones

| Pantalla | Qué hace |
|---|---|
| Registro / Inicio de sesión | Cuenta real con JWT y validaciones de código seguro. La sesión se recuerda al cerrar la app |
| Inicio | Pasos de hoy contra tu meta, ritmo cardíaco, calorías, último entrenamiento, semana y estado del wearable. Desliza hacia abajo para actualizar |
| Actividad física | Cronómetro con distancia, ritmo, bpm, calorías y pasos. Al terminar guarda la sesión en la API |
| Sesiones | Historial con filtros y detalle con gráfica de ritmo cardíaco y zonas |
| Metas | Metas diarias o semanales cuyo avance calcula el servidor. Crear, eliminar y registrar sueño a mano |
| Métricas | Pasos por día (semana/mes), ritmo en reposo, distancia, calorías y tiempo por actividad |
| Dispositivos | Vincular un wearable, sincronizar sensores (envía la lectura a la API), batería y datos compartidos |
| Notificaciones | Avisos generados por el servidor: meta cumplida, sesión guardada, ritmo alto, sincronización, batería |
| Perfil | Editar nombre, peso, estatura, edad y meta diaria, privacidad (eliminar cuenta) y cerrar sesión |

## Estructura

```
lib/
  main.dart                     Arranque
  api/
    api_client.dart             Cliente HTTP: token JWT, zona horaria, errores amigables
    fitpulse_api.dart           Endpoints de la API REST
    api_config.dart             Dirección del servidor por plataforma
  data/
    models.dart                 Modelos y conversión desde JSON
    repository.dart             FitPulseRepository: ApiRepository (API) y DemoRepository (sin conexión)
    mock_data.dart              Datos del modo demo
  state/app_state.dart          Estado global (ChangeNotifier + InheritedNotifier)
  services/local_store.dart     Token, servidor y preferencias (shared_preferences)
  wearable/wearable_service.dart  Contrato del wearable + implementación simulada
  theme/ widgets/ utils/        Diseño, componentes y gráficas propias
  screens/                      Una pantalla por archivo
tool/api_smoke.dart             Prueba de la conexión app ↔ backend
test/widget_test.dart           Pruebas de la app
```

## Pruebas

```bash
flutter test
# Con el backend corriendo: recorre registro, metas, sesiones, wearable y notificaciones
dart run tool/api_smoke.dart http://localhost:3000/api
```
