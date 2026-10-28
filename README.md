# FitPulse · App móvil (Flutter)

Prototipo navegable de la app de FitPulse para el **Entregable 1**. Todos los datos son **simulados** (no se conecta todavía al backend). La app comparte colores, logotipo, componentes y datos de ejemplo con la consola web, para que ambas se vean como aplicaciones hermanas.

## Ejecutar

```bash
flutter pub get
flutter run
```

No usa paquetes externos: solo el SDK de Flutter (Material 3).

## Pantallas

| # | Pantalla | Qué se puede hacer |
|---|----------|--------------------|
| — | Bienvenida | Logotipo animado (línea de pulso) |
| — | Onboarding | 3 diapositivas: actividad, metas y wearable |
| 1 | Registro | Validación de campos, fuerza de contraseña, aviso de privacidad |
| 2 | Inicio de sesión | Validación, "Usar cuenta demo", recuperar contraseña |
| 3 | Página principal | Anillo de pasos, ritmo cardíaco en vivo, calorías, último entrenamiento, semana, estado del wearable |
| 4 | Actividad física | Cronómetro con distancia, ritmo, bpm, calorías y pasos simulados; pausa, resumen y guardado (modo ×10 para demos) |
| 5 | Metas | Progreso animado, detalle con historial, crear y eliminar metas |
| 6 | Sesiones | Filtros por tipo, detalle con gráfica de ritmo cardíaco y zonas |
| 7 | Métricas | Semana/mes, ritmo en reposo, tiempo por actividad |
| 8 | Dispositivos | Sincronización paso a paso, datos compartidos, búsqueda Bluetooth con radar y código de vinculación |
| 9 | Notificaciones | No leídas, marcar leídas, deslizar para eliminar, preferencias |
| 10 | Perfil | Editar perfil (peso, estatura, edad, meta), privacidad, acerca de, cerrar sesión |

Las acciones tienen efecto en toda la app. Por ejemplo, al guardar una sesión se actualizan los pasos de hoy y las metas, y llega una notificación.

## Estructura

```
lib/
  main.dart                 Arranque y tema
  theme/app_theme.dart      Sistema de diseño (mismos tokens que la web)
  data/models.dart          Modelos (coinciden con las tablas del backend)
  data/mock_data.dart       Datos simulados (los mismos que la web)
  state/app_state.dart      Estado global simulado (ChangeNotifier)
  utils/format.dart         Formatos en español
  widgets/common.dart       Logo, tarjetas, etiquetas, botones
  widgets/charts.dart       Anillo, barras, línea, barra apilada (CustomPainter)
  screens/                  Una pantalla por archivo
```

## Siguiente paso (Unidad 2)

Cada método de `AppState` (login, addSession, addGoal, syncDevice…) se reemplazará por una llamada a la API REST (Node.js + Express + MySQL). Las pantallas no tendrán que cambiar.
