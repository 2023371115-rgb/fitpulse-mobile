import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../api/api_client.dart';
import '../api/api_config.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'shell.dart';

/// Figuras 1 y 2: Registro / Inicio de sesión contra la API (JWT).
///
/// Validaciones de la Práctica 5 (código seguro): campos sin espacios vacíos,
/// longitud máxima, contraseña de 8+ caracteres, contraseña oculta y mensajes
/// de error genéricos. El backend vuelve a validar todo.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.register = false});
  final bool register;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  bool _hide = true;
  bool _loading = false;
  bool _terms = true;

  bool get _register => widget.register;

  @override
  void dispose() {
    for (final c in [_name, _email, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _validateEmail(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Escribe tu correo electrónico';
    if (t.length > 120) return 'Máximo 120 caracteres';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Correo no válido';
    return null;
  }

  String? _validatePass(String? v) {
    if ((v ?? '').trim().isEmpty) return 'Escribe tu contraseña';
    if (v!.length < 8) return 'Mínimo 8 caracteres';
    if (v.length > 72) return 'Máximo 72 caracteres';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    if (_register && !_terms) {
      toast(context, 'Acepta el aviso de privacidad para continuar', icon: Icons.info_rounded);
      return;
    }
    setState(() => _loading = true);
    final app = AppScope.read(context);
    try {
      if (_register) {
        await app.register(_name.text, _email.text, _pass.text);
      } else {
        await app.login(_email.text, _pass.text);
      }
      if (!mounted) return;
      _pass.clear();
      _pass2.clear();
      Navigator.of(context).pushAndRemoveUntil(fadeRoute(const Shell()), (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      if (e.isNetwork) {
        _offerDemo(e.message);
      } else {
        toast(context, e.message, icon: Icons.error_outline_rounded);
      }
    }
  }

  /// Sin conexión con el servidor: permite revisar la dirección o entrar en modo demo.
  Future<void> _offerDemo(String message) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sin conexión', style: T.h2),
        content: Text('$message\n\nPuedes revisar la dirección del servidor o explorar la app con datos de ejemplo.', style: T.muted),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'server'), child: const Text('Servidor')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'demo'),
            style: FilledButton.styleFrom(minimumSize: const Size(110, 46)),
            child: const Text('Modo demo'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'server') _serverSheet();
    if (choice == 'demo') _enterDemo();
  }

  Future<void> _enterDemo() async {
    setState(() => _loading = true);
    await AppScope.read(context).enterDemo();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(fadeRoute(const Shell()), (_) => false);
  }

  /// Configura la dirección de la API sin volver a compilar la app.
  void _serverSheet() {
    final app = AppScope.read(context);
    final ctrl = TextEditingController(text: app.apiUrl);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String? status;
        bool ok = false;
        bool testing = false;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Text('Servidor', style: T.h2),
              gap(6),
              const Text('Dirección de la API de FitPulse (Node.js + Express).', style: T.muted),
              gap(16),
              TextField(
                controller: ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(hintText: 'http://10.0.2.2:3000/api', prefixIcon: Icon(Icons.dns_outlined)),
              ),
              gap(10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                ActionChip(label: const Text('Esta PC'), onPressed: () => ctrl.text = ApiConfig.platformDefault),
                ActionChip(label: const Text('Render'), onPressed: () => ctrl.text = ApiConfig.production),
              ]),
              if (status != null) ...[
                gap(12),
                Row(children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: ok ? FP.green : FP.redDark, size: 20),
                  hgap(8),
                  Expanded(child: Text(status!, style: T.small.copyWith(color: ok ? FP.green : FP.redDark, fontWeight: FontWeight.w600))),
                ]),
              ],
              gap(16),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: testing
                        ? null
                        : () async {
                            setSheet(() => testing = true);
                            await app.setApiUrl(ctrl.text);
                            ctrl.text = app.apiUrl;
                            try {
                              final v = await app.checkServer();
                              setSheet(() {
                                ok = true;
                                status = 'Conectado · $v';
                              });
                            } on ApiException catch (e) {
                              setSheet(() {
                                ok = false;
                                status = e.message;
                              });
                            } finally {
                              setSheet(() => testing = false);
                            }
                          },
                    child: Text(testing ? 'Probando…' : 'Probar'),
                  ),
                ),
                hgap(10),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await app.setApiUrl(ctrl.text);
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) toast(context, 'Servidor guardado', icon: Icons.dns_rounded);
                    },
                    child: const Text('Guardar'),
                  ),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  void _fillDemo() {
    setState(() {
      _email.text = 'ana@correo.com';
      _pass.text = 'fitpulse123';
    });
  }

  void _forgot() {
    final ctrl = TextEditingController(text: _email.text);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const IconBadge(Icons.lock_outline_rounded, color: FP.red, size: 52),
          gap(14),
          const Text('Recuperar contraseña', style: T.h2),
          gap(6),
          const Text('Te enviaremos un enlace para crear una nueva contraseña.', style: T.muted),
          gap(18),
          TextField(controller: ctrl, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(hintText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline_rounded))),
          gap(16),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              toast(context, 'La recuperación por correo estará disponible en la siguiente versión', icon: Icons.info_rounded);
            },
            child: const Text('Enviar enlace'),
          ),
        ]),
      ),
    );
  }

  InputDecoration _dec(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(hintText: hint, prefixIcon: Icon(icon, color: FP.subtle), suffixIcon: suffix);

  @override
  Widget build(BuildContext context) {
    final eye = IconButton(
      onPressed: () => setState(() => _hide = !_hide),
      icon: Icon(_hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: FP.subtle),
    );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(
            key: _form,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Servidor',
                  onPressed: _serverSheet,
                  icon: const Icon(Icons.dns_outlined, color: FP.subtle),
                ),
              ),
              gap(_register ? 0 : 24),
              const Align(alignment: Alignment.centerLeft, child: FpLogo(size: 40, textSize: 34)),
              gap(_register ? 14 : 22),
              if (_register)
                const Text('Crea tu cuenta y empieza a medir tu actividad.', style: TextStyle(fontSize: 16, color: FP.muted))
              else ...[
                const Text('Bienvenido de nuevo', style: T.h1),
                gap(6),
                const Text('Inicia sesión para ver tu progreso de hoy.', style: T.muted),
              ],
              gap(26),
              if (_register) ...[
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(80)],
                  decoration: _dec('Nombre completo', Icons.person_outline_rounded),
                  validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe tu nombre completo' : null,
                ),
                gap(),
              ],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                inputFormatters: [LengthLimitingTextInputFormatter(120), FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                decoration: _dec('Correo electrónico', Icons.mail_outline_rounded),
                validator: _validateEmail,
              ),
              gap(),
              TextFormField(
                controller: _pass,
                obscureText: _hide,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: [LengthLimitingTextInputFormatter(72)],
                textInputAction: _register ? TextInputAction.next : TextInputAction.done,
                decoration: _dec('Contraseña', Icons.lock_outline_rounded, suffix: eye),
                validator: _validatePass,
                onFieldSubmitted: (_) => _register ? null : _submit(),
              ),
              if (_register) ...[
                gap(),
                TextFormField(
                  controller: _pass2,
                  obscureText: _hide,
                  autocorrect: false,
                  enableSuggestions: false,
                  inputFormatters: [LengthLimitingTextInputFormatter(72)],
                  decoration: _dec('Confirmar contraseña', Icons.lock_outline_rounded),
                  validator: (v) => v != _pass.text ? 'Las contraseñas no coinciden' : null,
                ),
                gap(8),
                _PasswordStrength(controller: _pass),
                gap(6),
                Row(children: [
                  Checkbox(
                    value: _terms,
                    activeColor: FP.red,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                    onChanged: (v) => setState(() => _terms = v ?? false),
                  ),
                  const Expanded(child: Text('Acepto el aviso de privacidad y el uso de mis datos de actividad.', style: T.small)),
                ]),
              ] else
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _forgot, child: const Text('¿Olvidaste tu contraseña?', style: TextStyle(color: FP.muted))),
                ),
              gap(14),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(disabledBackgroundColor: FP.red.withValues(alpha: .7)),
                child: _loading
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white))
                    : Text(_register ? 'Crear cuenta' : 'Iniciar sesión'),
              ),
              if (!_register) ...[
                gap(10),
                OutlinedButton.icon(onPressed: _fillDemo, icon: const Icon(Icons.bolt_rounded, color: FP.red), label: const Text('Usar cuenta demo')),
                gap(4),
                TextButton(
                  onPressed: _loading ? null : _enterDemo,
                  child: const Text('Explorar sin conexión (modo demo)', style: TextStyle(color: FP.muted)),
                ),
              ],
              gap(14),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(fadeRoute(AuthScreen(register: !_register))),
                  child: Text.rich(TextSpan(
                    text: _register ? '¿Ya tienes cuenta? ' : '¿No tienes cuenta? ',
                    style: const TextStyle(color: FP.muted),
                    children: [TextSpan(text: _register ? 'Inicia sesión' : 'Regístrate', style: const TextStyle(color: FP.red, fontWeight: FontWeight.w800))],
                  )),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (_, v, __) {
          final p = v.text;
          var score = 0;
          if (p.length >= 8) score++;
          if (RegExp(r'[A-Z]').hasMatch(p)) score++;
          if (RegExp(r'[0-9]').hasMatch(p)) score++;
          if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) score++;
          const labels = ['Muy débil', 'Débil', 'Aceptable', 'Buena', 'Fuerte'];
          final colors = [FP.track, FP.redDark, FP.amber, FP.green, FP.green];
          return Row(children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 5,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(color: i < score ? colors[score] : FP.track, borderRadius: BorderRadius.circular(4)),
                ),
              ),
            hgap(8),
            Text(p.isEmpty ? 'Seguridad' : labels[score], style: T.small),
          ]);
        },
      );
}
