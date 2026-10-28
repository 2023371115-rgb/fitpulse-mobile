import 'dart:async';
import 'package:flutter/material.dart';
import 'main.dart';

// ───────── Helpers ─────────
Widget gap([double h = 12]) => SizedBox(height: h);
void push(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

Widget card(Widget child, {Color color = kCard, double pad = 16, VoidCallback? onTap}) => Material(
    color: color,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(padding: EdgeInsets.all(pad), child: child)));

Widget pill(String t, bool sel, VoidCallback f) => GestureDetector(
    onTap: f,
    child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: sel ? kPrimary : kMint, borderRadius: BorderRadius.circular(14)),
        child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: sel ? Colors.white : kText))));

Widget tag(String t) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: kMint, borderRadius: BorderRadius.circular(10)),
    child: Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)));

Widget big(String t, {Color color = kText, double size = 28}) =>
    Text(t, style: TextStyle(fontSize: size, fontWeight: FontWeight.w800, color: color));
Widget muted(String t, {double size = 14}) => Text(t, style: TextStyle(fontSize: size, color: kMuted));
Widget rowOf(List<Widget> k) =>
    Row(children: [for (var i = 0; i < k.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: k[i])]]);
Widget wrapPills(List<Widget> k) => Wrap(spacing: 8, runSpacing: 8, children: k);

Widget page(String title, List<Widget> kids, {List<Widget>? actions}) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: kids));

Widget brand() => RichText(
    text: const TextSpan(style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: kText), children: [
  TextSpan(text: 'Fit'),
  TextSpan(text: 'Pulse', style: TextStyle(color: kPrimary))
]));

void toast(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

// ───────── Figs 1 y 2: Registro / Inicio de sesión ─────────
class AuthScreen extends StatelessWidget {
  final bool register;
  const AuthScreen({super.key, this.register = false});
  @override
  Widget build(BuildContext context) {
    void go(Widget w) => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => w));
    Widget f(String h, {bool pass = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 12), child: TextField(obscureText: pass, decoration: InputDecoration(hintText: h)));
    return Scaffold(
        body: SafeArea(
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  gap(register ? 56 : 90),
                  brand(),
                  gap(register ? 12 : 20),
                  if (register) muted('Crea tu cuenta y empieza a medir tu actividad.', size: 16) else big('Bienvenido de nuevo', size: 26),
                  gap(24),
                  if (register) f('Nombre completo'),
                  f('Correo electrónico'),
                  f('Contraseña', pass: true),
                  if (register) f('Confirmar contraseña', pass: true),
                  if (!register)
                    Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () {}, child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: kMuted)))),
                  gap(8),
                  FilledButton(onPressed: () => go(const Shell()), child: Text(register ? 'Crear cuenta' : 'Iniciar sesión')),
                  gap(8),
                  Center(
                      child: TextButton(
                          onPressed: () => go(AuthScreen(register: !register)),
                          child: Text(register ? '¿Ya tienes cuenta? Inicia sesión' : '¿No tienes cuenta? Regístrate', style: const TextStyle(color: kText)))),
                ]))));
  }
}

// ───────── Navegación principal (4 pestañas) ─────────
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: [
          HomeScreen(onStart: () => setState(() => i = 1)),
          const ActivityScreen(),
          const GoalsScreen(),
          const ProfileScreen(),
        ]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            destinations: const [
              NavigationDestination(icon: SizedBox.shrink(), label: 'Inicio'),
              NavigationDestination(icon: SizedBox.shrink(), label: 'Actividad'),
              NavigationDestination(icon: SizedBox.shrink(), label: 'Metas'),
              NavigationDestination(icon: SizedBox.shrink(), label: 'Perfil'),
            ]),
      );
}

// ───────── Fig 3: Página principal ─────────
class HomeScreen extends StatelessWidget {
  final VoidCallback onStart;
  const HomeScreen({super.key, required this.onStart});
  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [muted('Hola, Ana'), big('Tu día', size: 30)])),
            card(const Text('🔔', style: TextStyle(fontSize: 20)), color: kMint, pad: 10, onTap: () => push(c, const NotificationsScreen())),
          ]),
          gap(16),
          card(Row(children: [
            SizedBox(
                width: 96,
                height: 96,
                child: Stack(alignment: Alignment.center, children: const [
                  SizedBox.expand(child: CircularProgressIndicator(value: .72, strokeWidth: 10, color: kPrimary, backgroundColor: Color(0xFFD5DCDA))),
                ])),
            const SizedBox(width: 18),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [big('7,240', size: 34), muted('de 10,000 pasos')])),
          ]), pad: 18),
          gap(),
          rowOf([
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [muted('Ritmo cardíaco'), gap(6), big('72 bpm', color: kPrimary, size: 24)])),
            card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [muted('Calorías'), gap(6), big('410', size: 24)])),
          ]),
          gap(),
          card(
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: big('Último entrenamiento', size: 18)), tag('Correr')]),
                gap(6),
                muted('Ayer · 32 min · 4.8 km'),
              ]),
              onTap: () => push(c, const SessionsScreen())),
          gap(),
          FilledButton(onPressed: onStart, child: const Text('Iniciar actividad')),
        ])),
      );
}

// ───────── Fig 4: Actividad física ─────────
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityState();
}

class _ActivityState extends State<ActivityScreen> {
  String sport = 'Correr';
  int secs = 1122; // 00:18:42
  Timer? t;
  bool get running => t != null;

  @override
  void initState() {
    super.initState();
    start();
  }

  void start() => t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => secs++));
  void toggle() {
    if (running) {
      t!.cancel();
      t = null;
    } else {
      start();
    }
    setState(() {});
  }

  void finish() {
    t?.cancel();
    t = null;
    setState(() => secs = 0);
    toast(context, 'Sesión guardada (ejemplo)');
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext c) {
    final clock = '${(secs ~/ 3600).toString().padLeft(2, '0')}:${((secs % 3600) ~/ 60).toString().padLeft(2, '0')}:${(secs % 60).toString().padLeft(2, '0')}';
    final km = (secs * 2.6 / 1122).toStringAsFixed(1);
    return page('Actividad física', [
      muted('Elige qué vas a hacer', size: 15),
      gap(),
      wrapPills([for (final s in ['Correr', 'Caminar', 'Bici']) pill(s, sport == s, () => setState(() => sport = s))]),
      gap(),
      card(Center(child: Column(children: [big(clock, size: 56), gap(8), muted('Duración')])), pad: 28),
      gap(),
      rowOf([
        card(Center(child: Column(children: [big(km, size: 26), muted('km')])), pad: 20),
        card(Center(child: Column(children: [big(secs == 0 ? '--' : '148', color: kPrimary, size: 26), muted('bpm')])), pad: 20),
      ]),
      gap(),
      rowOf([
        card(Center(child: Text(running ? 'Pausar' : 'Reanudar', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), color: kMint, pad: 18, onTap: toggle),
        card(const Center(child: Text('Terminar', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Colors.white))), color: kPrimary, pad: 18, onTap: finish),
      ]),
      gap(20),
      rowOf([
        OutlinedButton.icon(onPressed: () => push(c, const SessionsScreen()), icon: const Icon(Icons.history), label: const Text('Sesiones')),
        OutlinedButton.icon(onPressed: () => push(c, const MetricsScreen()), icon: const Icon(Icons.bar_chart), label: const Text('Métricas')),
      ]),
    ]);
  }
}

// ───────── Fig 5: Metas ─────────
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});
  @override
  State<GoalsScreen> createState() => _GoalsState();
}

class _GoalsState extends State<GoalsScreen> {
  // título, texto derecho, progreso, cumplida
  final goals = <List<dynamic>>[
    ['10,000 pasos diarios', '72%', .72, false],
    ['Correr 15 km', 'Semana · 8 km', .53, false],
    ['4 entrenamientos', '3 de 4', .75, false],
    ['Dormir 8 horas', 'Cumplida', 1.0, true],
  ];

  void add() {
    final ctrl = TextEditingController();
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              big('Nueva meta', size: 20),
              gap(),
              TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Ej. Caminar 5 km')),
              gap(16),
              FilledButton(
                  onPressed: () {
                    if (ctrl.text.trim().isEmpty) return;
                    setState(() => goals.add([ctrl.text.trim(), '0%', 0.0, false]));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar meta')),
            ])));
  }

  @override
  Widget build(BuildContext c) => page('Metas', [
        for (final g in goals) ...[
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: big(g[0], size: 17)),
              g[3] ? tag('Cumplida') : muted(g[1], size: 13),
            ]),
            gap(12),
            LinearProgressIndicator(
                value: g[2], minHeight: 8, color: g[3] || g[2] == .75 ? kGreen : kPrimary,
                backgroundColor: const Color(0xFFD5DCDA), borderRadius: BorderRadius.circular(6)),
          ])),
          gap(10),
        ]
      ], actions: [
        Padding(padding: const EdgeInsets.only(right: 16), child: Center(child: GestureDetector(onTap: add, child: tag('+ Nueva meta'))))
      ]);
}

// ───────── Fig 6: Sesiones (se abre desde Actividad) ─────────
const sessions = [
  ['Correr', 'Hoy', '32 min · 4.8 km · 156 bpm prom.'],
  ['Caminar', 'Ayer', '45 min · 3.9 km · 104 bpm prom.'],
  ['Bicicleta', 'Lun 21', '1 h 10 min · 18 km · 132 bpm prom.'],
  ['Correr', 'Dom 20', '25 min · 3.7 km · 150 bpm prom.'],
];

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessionsState();
}

class _SessionsState extends State<SessionsScreen> {
  String f = 'Todas';
  @override
  Widget build(BuildContext c) => page('Sesiones', [
        wrapPills([for (final x in ['Todas', 'Correr', 'Caminar', 'Bici']) pill(x, f == x, () => setState(() => f = x))]),
        gap(),
        for (final s in sessions.where((s) => f == 'Todas' || s[0].startsWith(f))) ...[
          card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: big(s[0], size: 18)), muted(s[1])]),
            gap(6),
            muted(s[2]),
          ])),
          gap(10),
        ]
      ]);
}

// ───────── Fig 7: Métricas (se abre desde Actividad) ─────────
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});
  @override
  State<MetricsScreen> createState() => _MetricsState();
}

class _MetricsState extends State<MetricsScreen> {
  bool week = true;
  @override
  Widget build(BuildContext c) {
    const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    const h = [.6, .75, .45, .9, .65, 1.0, .72];
    return page('Métricas', [
      Row(children: [pill('Semana', week, () => setState(() => week = true)), const Spacer(), pill('Mes', !week, () => setState(() => week = false))]),
      gap(),
      card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        big('Pasos por día', size: 17),
        gap(16),
        SizedBox(
            height: 130,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (var i = 0; i < 7; i++)
                Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Container(width: 30, height: h[i] * 100, decoration: BoxDecoration(color: i == 6 ? kPrimary : kMint, borderRadius: BorderRadius.circular(6))),
                  gap(6),
                  muted(days[i]),
                ])
            ])),
      ])),
      gap(),
      card(Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [muted('Ritmo cardíaco en reposo'), gap(6), big('62 bpm', color: kPrimary, size: 26)])),
        tag('−2 vs. semana pasada'),
      ])),
      gap(),
      card(Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [muted('Distancia total'), gap(6), big('27.4 km', size: 24)])),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [muted('Calorías'), gap(6), big('2,860', size: 24)]),
      ])),
    ]);
  }
}

// ───────── Fig 8: Dispositivos conectados ─────────
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesState();
}

class _DevicesState extends State<DevicesScreen> {
  final on = {'Pasos': true, 'Ritmo cardíaco': true, 'Movimiento': true};
  @override
  Widget build(BuildContext c) => page('Dispositivos', [
        card(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            card(const Text('⌚', style: TextStyle(fontSize: 22)), color: kMint, pad: 10),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              big('FitPulse Band', size: 18),
              Row(children: [const Icon(Icons.circle, size: 10, color: kGreen), const SizedBox(width: 6), muted('Conectado · 84%', size: 13)]),
            ]),
          ]),
          gap(10),
          muted('Última sincronización: hace 5 min', size: 13),
        ])),
        gap(),
        FilledButton(onPressed: () => toast(c, 'Sincronizando… (ejemplo)'), child: const Text('Sincronizar ahora')),
        gap(),
        muted('Datos que se comparten', size: 13),
        gap(8),
        for (final k in on.keys) ...[
          card(Row(children: [
            Expanded(child: Text(k, style: const TextStyle(fontSize: 16))),
            tag(on[k]! ? 'Activo' : 'Inactivo'),
          ]), onTap: () => setState(() => on[k] = !on[k]!)),
          gap(8),
        ],
        card(const Center(child: Text('Buscar otro dispositivo', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            color: kMint, pad: 18, onTap: () => toast(c, 'Buscando dispositivos… (ejemplo)')),
      ]);
}

// ───────── Fig 9: Notificaciones ─────────
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext c) {
    const n = [
      ['🎯', '¡Meta cumplida!', 'Ahora', 'Llegaste a 10,000 pasos.'],
      ['⌚', 'Dispositivo sincronizado', '1 h', 'Se guardaron 3 sesiones nuevas.'],
      ['❤️', 'Ritmo cardíaco alto', 'Ayer', 'Alcanzaste 176 bpm al correr.'],
      ['🔋', 'Batería baja', 'Lun', 'Tu banda tiene 15%.'],
    ];
    return page('Notificaciones', [
      for (final x in n) ...[
        card(Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          card(Text(x[0], style: const TextStyle(fontSize: 18)), color: kMint, pad: 10),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [big(x[1], size: 17), gap(4), muted(x[3], size: 13)])),
          muted(x[2], size: 13),
        ])),
        gap(10),
      ]
    ]);
  }
}

// ───────── Fig 10: Perfil ─────────
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext c) {
    Widget stat(String v, String l) => card(Center(child: Column(children: [big(v, size: 20), muted(l, size: 13)])), pad: 14);
    Widget item(String t, [Widget? w]) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: card(Row(children: [Expanded(child: Text(t, style: const TextStyle(fontSize: 16))), const Icon(Icons.chevron_right, color: kMuted)]),
            pad: 16, onTap: () => w != null ? push(c, w) : toast(c, '$t (próximamente)')));
    return Scaffold(
        body: SafeArea(
            child: ListView(padding: const EdgeInsets.all(20), children: [
      const Center(child: CircleAvatar(radius: 40, backgroundColor: kMint, child: Text('👤', style: TextStyle(fontSize: 34)))),
      gap(),
      Center(child: big('Ana Torres', size: 26)),
      Center(child: muted('ana@correo.com')),
      gap(16),
      rowOf([stat('62', 'kg'), stat('165', 'cm'), stat('28', 'años')]),
      gap(),
      item('Editar perfil'),
      item('Dispositivos', const DevicesScreen()),
      item('Notificaciones', const NotificationsScreen()),
      item('Privacidad de datos'),
      gap(4),
      card(const Center(child: Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          color: kMint, pad: 18,
          onTap: () => Navigator.pushAndRemoveUntil(c, MaterialPageRoute(builder: (_) => const AuthScreen()), (_) => false)),
    ])));
  }
}
