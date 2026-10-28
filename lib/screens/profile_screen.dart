import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'auth_screen.dart';
import 'devices_screen.dart';
import 'notifications_screen.dart';

/// Figura 10: Perfil.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final u = app.user;

    Widget stat(String v, String l) => Expanded(
          child: FpCard(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Column(children: [
              Text(v, style: T.h2.copyWith(fontSize: 20)),
              Text(l, style: T.small),
            ]),
          ),
        );

    Widget item(String title, IconData icon, VoidCallback onTap, {String? trailing}) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: FpCard(
            onTap: onTap,
            child: Row(children: [
              Icon(icon, color: FP.muted, size: 22),
              hgap(14),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 16, color: FP.ink))),
              if (trailing != null) ...[Text(trailing, style: T.small), hgap(4)],
              const Icon(Icons.chevron_right_rounded, color: FP.subtle),
            ]),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), children: [
          Center(
            child: Stack(children: [
              Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(
                  color: FP.mint,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [BoxShadow(color: FP.ink.withValues(alpha: .08), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                alignment: Alignment.center,
                child: Text(u.initials, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: FP.green)),
              ),
              Positioned(
                right: 0,
                bottom: 2,
                child: GestureDetector(
                  onTap: () => push(context, const EditProfileScreen()),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: FP.red, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3)),
                    child: const Icon(Icons.edit_rounded, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ]),
          ),
          gap(),
          Center(child: Text(u.name, style: T.h2.copyWith(fontSize: 24))),
          Center(child: Text(u.email, style: T.muted)),
          gap(16),
          Row(children: [
            stat(u.weightKg == u.weightKg.roundToDouble() ? '${u.weightKg.round()}' : u.weightKg.toStringAsFixed(1), 'kg'),
            hgap(10),
            stat('${u.heightCm}', 'cm'),
            hgap(10),
            stat('${u.age}', 'años'),
          ]),
          gap(10),
          FpCard(
            color: FP.mintSoft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              const Icon(Icons.accessibility_new_rounded, color: FP.green, size: 20),
              hgap(10),
              Expanded(child: Text('IMC ${u.bmi.toStringAsFixed(1)} · ${u.bmiLabel}', style: T.bodyStrong)),
              Text('Meta: ${Fmt.number(u.dailyStepGoal)} pasos', style: T.small),
            ]),
          ),
          gap(16),
          item('Editar perfil', Icons.person_outline_rounded, () => push(context, const EditProfileScreen())),
          item('Dispositivos', Icons.watch_outlined, () => push(context, const DevicesScreen()), trailing: '${app.devices.length}'),
          item('Notificaciones', Icons.notifications_none_rounded, () => push(context, const NotificationsScreen()),
              trailing: app.unreadCount > 0 ? '${app.unreadCount} nuevas' : null),
          item('Privacidad de datos', Icons.privacy_tip_outlined, () => push(context, const PrivacyScreen())),
          item('Acerca de FitPulse', Icons.info_outline_rounded, () => push(context, const AboutScreen())),
          gap(4),
          MintButton(
            label: 'Cerrar sesión',
            icon: Icons.logout_rounded,
            onPressed: () async {
              final ok = await confirmDialog(context, title: '¿Cerrar sesión?', message: 'Podrás volver a entrar con tu correo y contraseña.', confirm: 'Cerrar sesión');
              if (!ok || !context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen()), (_) => false);
            },
          ),
        ]),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _weight, _height, _age, _steps;

  @override
  void initState() {
    super.initState();
    final u = AppScope.read(context).user;
    _name = TextEditingController(text: u.name);
    _weight = TextEditingController(text: u.weightKg.toString().replaceAll(RegExp(r'\.0$'), ''));
    _height = TextEditingController(text: '${u.heightCm}');
    _age = TextEditingController(text: '${u.age}');
    _steps = TextEditingController(text: '${u.dailyStepGoal}');
  }

  @override
  void dispose() {
    for (final c in [_name, _weight, _height, _age, _steps]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _range(String? v, num lo, num hi, String what) {
    final n = num.tryParse(v ?? '');
    if (n == null) return 'Escribe tu $what';
    if (n < lo || n > hi) return 'Valor entre $lo y $hi';
    return null;
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    AppScope.read(context).updateProfile(
      name: _name.text.trim(),
      weightKg: double.parse(_weight.text),
      heightCm: int.parse(_height.text),
      age: int.parse(_age.text),
      dailyStepGoal: int.parse(_steps.text),
    );
    Navigator.pop(context);
    toast(context, 'Perfil actualizado');
  }

  @override
  Widget build(BuildContext context) {
    final email = AppScope.of(context).user.email;
    final digits = [FilteringTextInputFormatter.digitsOnly];

    Widget field(TextEditingController c, String label, {String? suffix, List<TextInputFormatter>? fmt, String? Function(String?)? validator, TextInputType? type}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            keyboardType: type,
            inputFormatters: fmt,
            validator: validator,
            decoration: InputDecoration(labelText: label, suffixText: suffix),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
          field(_name, 'Nombre completo', validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe tu nombre' : null),
          TextFormField(
            initialValue: email,
            enabled: false,
            decoration: const InputDecoration(labelText: 'Correo electrónico', suffixIcon: Icon(Icons.lock_outline_rounded, size: 18)),
          ),
          gap(12),
          Row(children: [
            Expanded(
              child: field(_weight, 'Peso', suffix: 'kg', type: const TextInputType.numberWithOptions(decimal: true),
                  fmt: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))], validator: (v) => _range(v, 30, 250, 'peso')),
            ),
            hgap(10),
            Expanded(child: field(_height, 'Estatura', suffix: 'cm', type: TextInputType.number, fmt: digits, validator: (v) => _range(v, 100, 230, 'estatura'))),
          ]),
          Row(children: [
            Expanded(child: field(_age, 'Edad', suffix: 'años', type: TextInputType.number, fmt: digits, validator: (v) => _range(v, 12, 100, 'edad'))),
            hgap(10),
            Expanded(child: field(_steps, 'Meta diaria', suffix: 'pasos', type: TextInputType.number, fmt: digits, validator: (v) => _range(v, 1000, 50000, 'meta'))),
          ]),
          gap(4),
          const Text('Tu peso y estatura se usan para estimar calorías y distancia.', style: T.small),
          gap(20),
          FilledButton(onPressed: _save, child: const Text('Guardar cambios')),
        ]),
      ),
    );
  }
}

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return FpPage(
      title: 'Preferencias',
      subtitle: 'Elige qué avisos quieres recibir.',
      children: [
        for (final k in app.noticePrefs.keys) ...[
          FpCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
            onTap: () => app.setNoticePref(k, !app.noticePrefs[k]!),
            child: Row(children: [
              Expanded(child: Text(k, style: const TextStyle(fontSize: 15.5, color: FP.ink))),
              Switch(value: app.noticePrefs[k]!, onChanged: (v) => app.setNoticePref(k, v)),
            ]),
          ),
          gap(8),
        ],
        gap(8),
        OutlinedButton.icon(
          onPressed: () => toast(context, 'Notificación de prueba: ¡Hora de moverte! 🏃', icon: Icons.notifications_active_rounded),
          icon: const Icon(Icons.notifications_active_outlined),
          label: const Text('Enviar notificación de prueba'),
        ),
      ],
    );
  }
}

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    Widget point(IconData icon, String title, String body) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(icon, color: FP.green, size: 38),
            hgap(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: T.bodyStrong),
                gap(2),
                Text(body, style: T.muted.copyWith(fontSize: 13.5)),
              ]),
            ),
          ]),
        );

    return FpPage(
      title: 'Privacidad',
      children: [
        FpCard(
          child: Column(children: [
            point(Icons.person_outline_rounded, 'Qué datos guardamos', 'Nombre, correo, peso, estatura, pasos, ritmo cardíaco, sesiones y metas.'),
            point(Icons.track_changes_rounded, 'Para qué', 'Mostrar tu progreso y sincronizar tus dispositivos. Nunca vendemos tus datos.'),
            point(Icons.lock_outline_rounded, 'Cómo se protegen', 'Contraseñas cifradas (bcrypt), sesiones con token JWT y conexión HTTPS.'),
          ]),
        ),
        gap(12),
        FpCard(
          padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
          child: Row(children: [
            const Expanded(child: Text('Compartir estadísticas anónimas para mejorar FitPulse', style: TextStyle(fontSize: 15, color: FP.ink))),
            Switch(value: app.allowAnonymousStats, onChanged: app.setAnonymousStats),
          ]),
        ),
        gap(16),
        OutlinedButton.icon(
          onPressed: () => toast(context, 'Te enviaremos tus datos a ${app.user.email} (simulado)', icon: Icons.download_rounded),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Descargar mis datos'),
        ),
        gap(10),
        TextButton.icon(
          onPressed: () async {
            final ok = await confirmDialog(context,
                title: '¿Eliminar cuenta?', message: 'Se borrarán tu perfil, sesiones y metas. Esta acción no se puede deshacer.', confirm: 'Eliminar', destructive: true);
            if (!ok || !context.mounted) return;
            AppScope.read(context).resetDemo();
            Navigator.of(context).pushAndRemoveUntil(fadeRoute(const AuthScreen(register: true)), (_) => false);
          },
          icon: const Icon(Icons.delete_forever_outlined, color: FP.redDark),
          label: const Text('Eliminar mi cuenta', style: TextStyle(color: FP.redDark)),
        ),
        gap(10),
        const Text('Conforme a la LFPDPPP. Puedes ejercer tus derechos ARCO desde esta pantalla.', style: T.small, textAlign: TextAlign.center),
      ],
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Widget row(String a, String b) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: [Expanded(child: Text(a, style: T.muted)), Text(b, style: T.bodyStrong)]),
        );
    return FpPage(
      title: 'Acerca de',
      children: [
        gap(10),
        const Center(child: FpLogo(size: 64, showText: false)),
        gap(14),
        Center(
          child: RichText(
            text: const TextSpan(
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: FP.ink, letterSpacing: -0.6),
              children: [TextSpan(text: 'Fit'), TextSpan(text: 'Pulse', style: TextStyle(color: FP.red))],
            ),
          ),
        ),
        gap(4),
        const Center(child: Text('Versión 0.2.0 · Prototipo navegable', style: T.muted)),
        gap(20),
        FpCard(
          child: Column(children: [
            row('Aplicación móvil', 'Flutter 3'),
            const Divider(),
            row('Consola web', 'Angular'),
            const Divider(),
            row('API', 'Node.js + Express'),
            const Divider(),
            row('Base de datos', 'MySQL'),
            const Divider(),
            row('Wearable', 'Wear OS · BLE'),
          ]),
        ),
        gap(12),
        FpCard(
          color: FP.mintSoft,
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: FP.green),
            SizedBox(width: 10),
            Expanded(child: Text('Esta versión usa datos simulados. La conexión con la API llegará en la Unidad 2.', style: T.body)),
          ]),
        ),
      ],
    );
  }
}
