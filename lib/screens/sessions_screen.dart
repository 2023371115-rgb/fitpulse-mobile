import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Figura 6: Sesiones.
class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key});
  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> {
  ActivityType? _filter;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final list = app.sessions.where((s) => _filter == null || s.type == _filter).toList();
    final totalKm = list.fold<double>(0, (a, s) => a + s.km);
    final totalMin = list.fold<int>(0, (a, s) => a + s.duration.inMinutes);

    return FpPage(
      title: 'Sesiones',
      children: [
        SizedBox(
          height: 42,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            FpPill('Todas', dense: true, selected: _filter == null, onTap: () => setState(() => _filter = null)),
            for (final t in ActivityType.values) ...[
              hgap(8),
              FpPill(t.label, dense: true, selected: _filter == t, onTap: () => setState(() => _filter = t)),
            ],
          ]),
        ),
        gap(14),
        Row(children: [
          Expanded(child: _SummaryChip(value: '${list.length}', label: 'sesiones')),
          hgap(8),
          Expanded(child: _SummaryChip(value: Fmt.km(totalKm), label: 'km')),
          hgap(8),
          Expanded(child: _SummaryChip(value: Fmt.duration(Duration(minutes: totalMin)), label: 'en total')),
        ]),
        gap(14),
        if (list.isEmpty)
          const EmptyState(icon: Icons.directions_run_rounded, title: 'Sin sesiones', message: 'Todavía no registras actividades de este tipo.')
        else
          for (final s in list) ...[
            SessionCard(session: s, onTap: () => push(context, SessionDetailScreen(session: s))),
            gap(10),
          ],
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(border: Border.all(color: FP.border), borderRadius: BorderRadius.circular(14)),
        child: Column(children: [
          FittedBox(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: FP.ink))),
          Text(label, style: T.small),
        ]),
      );
}

class SessionCard extends StatelessWidget {
  const SessionCard({super.key, required this.session, this.onTap});
  final Session session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final parts = [
      Fmt.duration(s.duration),
      if (s.km > 0) '${Fmt.km(s.km)} km',
      '${s.avgHr} bpm prom.',
    ];
    return FpCard(
      onTap: onTap,
      child: Row(children: [
        IconBadge(s.type.icon, color: s.type.color, size: 46),
        hgap(14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(s.type.title, style: T.h3)),
              Text(Fmt.day(s.start), style: T.muted),
            ]),
            gap(4),
            Text(parts.join(' · '), style: T.muted),
          ]),
        ),
      ]),
    );
  }
}

/// Cuadrícula de estadísticas de una sesión (también se usa en el resumen).
class SessionStatsGrid extends StatelessWidget {
  const SessionStatsGrid({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final items = <(String, String, String?, IconData, Color)>[
      ('Duración', Fmt.duration(s.duration), null, Icons.timer_rounded, FP.ink),
      ('Distancia', s.km > 0 ? Fmt.km(s.km) : '--', s.km > 0 ? 'km' : null, Icons.timeline_rounded, FP.ink),
      ('Ritmo prom.', Fmt.pace(s.paceMinPerKm), s.km > 0 ? '/km' : null, Icons.speed_rounded, FP.ink),
      ('Calorías', Fmt.number(s.kcal), 'kcal', Icons.local_fire_department_rounded, FP.amber),
      ('Ritmo cardíaco', '${s.avgHr}', 'bpm', Icons.favorite_rounded, FP.red),
      ('Máximo', '${s.maxHr}', 'bpm', Icons.trending_up_rounded, FP.red),
    ];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: .95,
      children: [
        for (final it in items)
          FpCard(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(it.$4, size: 18, color: it.$5 == FP.ink ? FP.muted : it.$5),
              const Spacer(),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: it.$2, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: it.$5)),
                  if (it.$3 != null) TextSpan(text: ' ${it.$3}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: it.$5)),
                ])),
              ),
              Text(it.$1, style: T.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
      ],
    );
  }
}

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.session});
  final Session session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    const zoneNames = ['Z1 Recuperación', 'Z2 Quema grasa', 'Z3 Aeróbica', 'Z4 Umbral', 'Z5 Máxima'];
    const zoneColors = [Color(0xFF9FCFB7), FP.green, FP.amber, Color(0xFFEF7A45), FP.red];
    final zones = s.zones;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.type.title),
        actions: [
          IconButton(
            tooltip: 'Eliminar',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final ok = await confirmDialog(context, title: '¿Eliminar sesión?', message: 'Esta acción no se puede deshacer.', confirm: 'Eliminar', destructive: true);
              if (!ok || !context.mounted) return;
              AppScope.read(context).deleteSession(s.id);
              Navigator.pop(context);
              toast(context, 'Sesión eliminada', icon: Icons.delete_outline_rounded);
            },
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Row(children: [
          IconBadge(s.type.icon, color: s.type.color, size: 52),
          hgap(14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${Fmt.day(s.start)} · ${Fmt.time(s.start)}', style: T.h3),
              gap(2),
              Text('Registrado con ${s.device}', style: T.muted),
            ]),
          ),
        ]),
        gap(18),
        SessionStatsGrid(session: s),
        gap(12),
        FpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(child: Text('Ritmo cardíaco', style: T.h3)),
              FpTag('${s.avgHr} bpm prom.', color: FP.redSoft, textColor: FP.red),
            ]),
            gap(12),
            FpLineChart(data: s.hrSeries, height: 130),
            gap(6),
            Row(children: [
              const Text('Inicio', style: T.small),
              const Spacer(),
              Text(Fmt.duration(s.duration), style: T.small),
            ]),
          ]),
        ),
        gap(12),
        FpCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Zonas de ritmo cardíaco', style: T.h3),
            gap(12),
            StackedBar(parts: [for (var i = 0; i < 5; i++) (zones[i], zoneColors[i])]),
            gap(12),
            for (var i = 4; i >= 0; i--)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: zoneColors[i], borderRadius: BorderRadius.circular(3))),
                  hgap(10),
                  Expanded(child: Text(zoneNames[i], style: T.body)),
                  Text('${(zones[i] * 100).round()}%', style: T.bodyStrong),
                ]),
              ),
          ]),
        ),
        if (s.steps > 0) ...[
          gap(12),
          FpCard(
            color: FP.mintSoft,
            child: Row(children: [
              const Icon(Icons.directions_walk_rounded, color: FP.green),
              hgap(10),
              Expanded(child: Text('${Fmt.number(s.steps)} pasos durante esta sesión', style: T.bodyStrong)),
            ]),
          ),
        ],
      ]),
    );
  }
}
