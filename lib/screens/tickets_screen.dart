import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Versión que se adjunta a cada reporte (igual a pubspec.yaml).
const appVersion = '0.4.0';

const _categories = {
  'bug': 'Error',
  'crash': 'Se cierra',
  'ui': 'Diseño',
  'performance': 'Lentitud',
  'data': 'Datos',
  'other': 'Otro',
};
const _severities = {'low': 'Baja', 'medium': 'Media', 'high': 'Alta', 'critical': 'Crítica'};
const _screens = ['Inicio', 'Actividad', 'Metas', 'Sesiones', 'Métricas', 'Dispositivos', 'Notificaciones', 'Perfil', 'Buscador', 'Otra'];

Color _statusColor(String s) => switch (s) {
      'open' => FP.amber,
      'in_progress' => FP.blue,
      'resolved' => FP.green,
      _ => FP.muted,
    };

/// Mis reportes de fallos y su estado.
class TicketsScreen extends StatefulWidget {
  const TicketsScreen({super.key});
  @override
  State<TicketsScreen> createState() => _TicketsScreenState();
}

class _TicketsScreenState extends State<TicketsScreen> {
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_items == null && _error == null) _load();
  }

  Future<void> _load() async {
    final app = AppScope.read(context);
    if (app.isDemo) {
      setState(() => _error = 'Los reportes de fallos se guardan en el servidor. Inicia sesión con tu cuenta para enviarlos.');
      return;
    }
    try {
      final items = await app.api.tickets();
      if (mounted) setState(() { _items = items; _error = null; });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _new() async {
    final created = await Navigator.of(context).push<Map<String, dynamic>>(fadeRoute(const NewTicketScreen()));
    if (created != null && mounted) {
      setState(() => _items = [created, ...?_items]);
      toast(context, 'Reporte ${created['code']} enviado', icon: Icons.check_circle_rounded);
      AppScope.read(context).refreshNotices();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Reportes de fallos')),
      floatingActionButton: AppScope.of(context).isDemo
          ? null
          : FloatingActionButton.extended(
              onPressed: _new,
              backgroundColor: FP.red,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.bug_report_rounded),
              label: const Text('Reportar fallo'),
            ),
      body: RefreshIndicator(
        color: FP.red,
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 96), physics: const AlwaysScrollableScrollPhysics(), children: [
          Text('¿Algo no funciona? Envía un reporte y te avisaremos cuando lo revisemos.', style: T.muted),
          gap(14),
          if (_error != null)
            FpCard(
              color: FP.redSoft,
              onTap: _load,
              child: Row(children: [
                const Icon(Icons.cloud_off_rounded, color: FP.redDark),
                hgap(10),
                Expanded(child: Text(_error!, style: T.small.copyWith(color: FP.redDark, fontWeight: FontWeight.w600))),
              ]),
            )
          else if (items == null)
            const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: FP.red)))
          else if (items.isEmpty)
            const EmptyState(icon: Icons.bug_report_outlined, title: 'Sin reportes', message: 'Cuando envíes un reporte de fallo aparecerá aquí con su estado.')
          else
            for (final t in items) ...[
              FpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${t['code']} · ${t['title']}', style: T.bodyStrong)),
                    hgap(8),
                    FpTag('${t['status_label']}', color: _statusColor('${t['status']}').withValues(alpha: .16), textColor: _statusColor('${t['status']}')),
                  ]),
                  gap(4),
                  Text('${_categories[t['category']] ?? t['category']} · gravedad ${(_severities[t['severity']] ?? '').toLowerCase()} · ${t['screen'] ?? 'sin pantalla'}', style: T.small),
                  gap(6),
                  Text('${t['description']}', style: T.body),
                  if (t['admin_note'] != null && '${t['admin_note']}'.isNotEmpty) ...[
                    gap(8),
                    Text('Respuesta: ${t['admin_note']}', style: T.small.copyWith(color: FP.green, fontWeight: FontWeight.w700)),
                  ],
                ]),
              ),
              gap(10),
            ],
        ]),
      ),
    );
  }
}

/// Formulario para reportar un fallo.
class NewTicketScreen extends StatefulWidget {
  const NewTicketScreen({super.key, this.screen});
  final String? screen;
  @override
  State<NewTicketScreen> createState() => _NewTicketScreenState();
}

class _NewTicketScreenState extends State<NewTicketScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String _category = 'bug';
  String _severity = 'medium';
  late String _screen = widget.screen ?? 'Inicio';
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_form.currentState!.validate()) return;
    setState(() { _sending = true; _error = null; });
    try {
      final ticket = await AppScope.read(context).api.createTicket({
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'category': _category,
        'severity': _severity,
        'screen': _screen,
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'app_version': appVersion,
        'device_info': 'FitPulse $appVersion · ${kIsWeb ? 'navegador' : defaultTargetPlatform.name}',
      });
      if (mounted) Navigator.pop(context, ticket);
    } on ApiException catch (e) {
      // No se cierra la pantalla: el usuario no pierde lo que escribió.
      if (mounted) setState(() { _sending = false; _error = e.message; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Reportar un fallo')),
        body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 28), children: [
            TextFormField(
              controller: _title,
              maxLength: 140,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Título', hintText: 'Ej. La app se cierra al guardar'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe un título de al menos 3 caracteres' : null,
            ),
            gap(6),
            const Text('Tipo de fallo', style: T.label),
            gap(8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _categories.entries) FpPill(e.value, dense: true, selected: _category == e.key, onTap: () => setState(() => _category = e.key)),
            ]),
            gap(14),
            const Text('Gravedad', style: T.label),
            gap(8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in _severities.entries) FpPill(e.value, dense: true, selected: _severity == e.key, onTap: () => setState(() => _severity = e.key)),
            ]),
            gap(14),
            DropdownButtonFormField<String>(
              initialValue: _screen,
              decoration: const InputDecoration(labelText: '¿En qué pantalla pasó?'),
              items: [for (final s in _screens) DropdownMenuItem(value: s, child: Text(s))],
              onChanged: (v) => setState(() => _screen = v ?? _screen),
            ),
            gap(14),
            TextFormField(
              controller: _desc,
              minLines: 4,
              maxLines: 8,
              maxLength: 4000,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción', hintText: '¿Qué hacías, qué esperabas y qué pasó?', alignLabelWithHint: true),
              validator: (v) => (v ?? '').trim().length < 10 ? 'Describe el fallo con al menos 10 caracteres' : null,
            ),
            Text('Se adjunta la versión de la app ($appVersion) y la plataforma para ayudar a reproducir el fallo.', style: T.small),
            if (_error != null) ...[
              gap(12),
              FpCard(
                color: FP.redSoft,
                child: Row(children: [
                  const Icon(Icons.error_outline_rounded, color: FP.redDark),
                  hgap(10),
                  Expanded(child: Text('No se envió: $_error', style: T.small.copyWith(color: FP.redDark, fontWeight: FontWeight.w600))),
                ]),
              ),
            ],
            gap(18),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Text('Enviar reporte'),
            ),
          ]),
        ),
      );
}
