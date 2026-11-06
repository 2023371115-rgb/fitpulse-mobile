import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'devices_screen.dart';
import 'metrics_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'sessions_screen.dart';
import 'tickets_screen.dart';

const _indexLabel = {
  'sessions': 'Sesiones',
  'goals': 'Metas',
  'notifications': 'Notificaciones',
  'devices': 'Dispositivos',
  'tickets': 'Reportes',
  'screens': 'Secciones',
  'users': 'Usuarios',
};

const _indexIcon = {
  'sessions': Icons.directions_run_rounded,
  'goals': Icons.flag_rounded,
  'notifications': Icons.notifications_rounded,
  'devices': Icons.watch_rounded,
  'tickets': Icons.bug_report_rounded,
  'screens': Icons.apps_rounded,
  'users': Icons.person_rounded,
};

/// Buscador de la app. Usa el motor del backend (/api/search, tipo Elasticsearch):
/// tolera acentos y errores de dedo, busca mientras escribes, resalta coincidencias
/// y agrupa los resultados por tipo.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.onOpenActivity, this.onOpenGoals});
  final VoidCallback? onOpenActivity;
  final VoidCallback? onOpenGoals;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  Map<String, dynamic>? _res;
  Map<String, dynamic> _facets = {};
  String? _filter;
  String? _error;
  bool _loading = false;
  int _seq = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _filter = null;
      _run();
    });
  }

  Future<void> _run() async {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      setState(() { _res = null; _error = null; _facets = {}; });
      return;
    }
    final app = AppScope.read(context);
    if (app.isDemo) {
      setState(() => _error = 'El buscador consulta el servidor. Inicia sesión con tu cuenta para usarlo.');
      return;
    }
    final seq = ++_seq;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await app.api.search(q, index: _filter);
      if (!mounted || seq != _seq) return; // llegó una búsqueda más nueva
      setState(() {
        _res = res;
        if (_filter == null) _facets = ((res['aggregations'] as Map?)?['by_index'] as Map?)?.cast<String, dynamic>() ?? {};
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted && seq == _seq) setState(() { _error = e.message; _loading = false; });
    }
  }

  void _open(Map<String, dynamic> hit) {
    final index = hit['_index'] as String;
    final id = hit['_id'] as String;
    final target = index == 'screens' ? id : index;
    switch (target) {
      case 'sessions':
        push(context, const SessionsScreen());
      case 'notifications':
        push(context, const NotificationsScreen());
      case 'devices':
        push(context, const DevicesScreen());
      case 'tickets':
        push(context, const TicketsScreen());
      case 'metrics':
        push(context, const MetricsScreen());
      case 'profile':
        push(context, const EditProfileScreen());
      case 'goals':
        Navigator.pop(context);
        widget.onOpenGoals?.call();
      case 'activity':
        Navigator.pop(context);
        widget.onOpenActivity?.call();
      default:
        Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hits = ((_res?['hits'] as Map?)?['hits'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    final total = (_res?['hits'] as Map?)?['total'] ?? 0;
    final suggestion = _res?['suggestion'] as String?;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          onSubmitted: (_) => _run(),
          decoration: InputDecoration(
            hintText: 'Buscar sesiones, metas, reportes…',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _ctrl.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _ctrl.clear();
                      _run();
                    }),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), children: [
        if (_loading) const LinearProgressIndicator(color: FP.red, backgroundColor: FP.track, minHeight: 2),
        if (_error != null)
          FpCard(color: FP.redSoft, child: Text(_error!, style: T.small.copyWith(color: FP.redDark, fontWeight: FontWeight.w600)))
        else if (_res == null)
          const EmptyState(
            icon: Icons.search_rounded,
            title: 'Busca en FitPulse',
            message: 'Prueba con "bicicleta", "octubre", "batería" o "reportar fallo". No importan los acentos ni los errores de dedo.',
          )
        else ...[
          Text('$total resultado${total == 1 ? '' : 's'} · ${_res!['took']} ms', style: T.small),
          if (_facets.length > 1) ...[
            gap(10),
            SizedBox(
              height: 38,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final f in _facets.entries) ...[
                  FpPill('${_indexLabel[f.key] ?? f.key} ${f.value}', dense: true, selected: _filter == f.key, onTap: () {
                    _filter = _filter == f.key ? null : f.key;
                    _run();
                  }),
                  hgap(8),
                ],
              ]),
            ),
          ],
          gap(12),
          if (hits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(children: [
                const Text('Sin resultados', style: T.h3),
                if (suggestion != null) ...[
                  gap(8),
                  GestureDetector(
                    onTap: () {
                      _ctrl.text = suggestion;
                      _run();
                    },
                    child: Text.rich(TextSpan(style: T.muted, children: [
                      const TextSpan(text: '¿Quisiste decir '),
                      TextSpan(text: suggestion, style: const TextStyle(color: FP.red, fontWeight: FontWeight.w800)),
                      const TextSpan(text: '?'),
                    ])),
                  ),
                ],
              ]),
            ),
          for (final h in hits) ...[
            _HitCard(hit: h, onTap: () => _open(h)),
            gap(8),
          ],
        ],
      ]),
    );
  }
}

class _HitCard extends StatelessWidget {
  const _HitCard({required this.hit, required this.onTap});
  final Map<String, dynamic> hit;
  final VoidCallback onTap;

  String? _first(String field) {
    final list = (hit['highlight'] as Map?)?[field] as List?;
    return list == null || list.isEmpty ? null : '${list.first}';
  }

  String _plainTitle(Map<String, dynamic> s) => '${s['title'] ?? s['name'] ?? s['email'] ?? s['code'] ?? ''}';

  String _detail(String index, Map<String, dynamic> s) {
    switch (index) {
      case 'sessions':
        final d = DateTime.tryParse('${s['started_at']}')?.toLocal();
        return [
          if (d != null) '${d.day}/${d.month}/${d.year}',
          if (s['distance_km'] != null) '${s['distance_km']} km',
          if (s['calories'] != null) '${(s['calories'] as num).round()} kcal',
        ].join(' · ');
      case 'goals':
        return '${s['target']} ${s['unit']} · ${s['period'] == 'weekly' ? 'semanal' : 'diaria'}';
      case 'tickets':
        return '${s['code']} · ${s['status']}';
      case 'devices':
        return '${s['status']}${s['battery'] != null ? ' · ${s['battery']}%' : ''}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final index = '${hit['_index']}';
    final source = (hit['_source'] as Map).cast<String, dynamic>();
    final title = _first('title');
    final body = _first('body');
    final detail = _detail(index, source);
    return FpCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconBadge(_indexIcon[index] ?? Icons.search_rounded, color: FP.red, size: 40),
        hgap(12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((_indexLabel[index] ?? index).toUpperCase(), style: T.label.copyWith(color: FP.red, fontSize: 11)),
            gap(2),
            HighlightText(title ?? _plainTitle(source), style: T.bodyStrong),
            if (body != null) ...[gap(3), HighlightText(body, style: T.small)],
            if (detail.isNotEmpty) ...[gap(3), Text(detail, style: T.small)],
          ]),
        ),
      ]),
    );
  }
}

/// Muestra texto con las coincidencias marcadas por el servidor como `<em>…</em>`.
class HighlightText extends StatelessWidget {
  const HighlightText(this.html, {super.key, required this.style});
  final String html;
  final TextStyle style;

  static String _unescape(String s) =>
      s.replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&quot;', '"').replaceAll('&amp;', '&');

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp(r'<em>(.*?)</em>');
    var pos = 0;
    for (final m in re.allMatches(html)) {
      if (m.start > pos) spans.add(TextSpan(text: _unescape(html.substring(pos, m.start))));
      spans.add(TextSpan(
        text: _unescape(m.group(1)!),
        style: const TextStyle(fontWeight: FontWeight.w800, backgroundColor: Color(0x55F2A33A)),
      ));
      pos = m.end;
    }
    if (pos < html.length) spans.add(TextSpan(text: _unescape(html.substring(pos))));
    return Text.rich(TextSpan(style: style, children: spans));
  }
}
