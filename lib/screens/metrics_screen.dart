import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Figura 7: Métricas. Datos de GET /api/metrics/summary (semana o mes).
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});
  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  bool _week = true;
  ActivitySummary? _month;
  bool _loading = false;
  String? _error;

  Future<void> _select(bool week) async {
    setState(() {
      _week = week;
      _error = null;
    });
    if (week || _month != null) return;
    setState(() => _loading = true);
    try {
      final m = await AppScope.read(context).summaryFor(month: true);
      if (mounted) setState(() => _month = m);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final ActivitySummary? data = _week ? app.summary : _month;

    return FpPage(
      title: 'Métricas',
      children: [
        Row(children: [
          FpPill('Semana', selected: _week, dense: true, onTap: () => _select(true)),
          hgap(8),
          FpPill('Mes', selected: !_week, dense: true, onTap: () => _select(false)),
          const Spacer(),
          Text(_week ? 'Últimos 7 días' : 'Últimos 30 días', style: T.small),
        ]),
        gap(14),
        if (_loading)
          const Padding(padding: EdgeInsets.symmetric(vertical: 80), child: Center(child: CircularProgressIndicator(color: FP.red)))
        else if (_error != null)
          FpCard(
            color: FP.redSoft,
            onTap: () => _select(false),
            child: Row(children: [
              const Icon(Icons.cloud_off_rounded, color: FP.redDark),
              hgap(10),
              Expanded(child: Text(_error!, style: T.bodyStrong.copyWith(color: FP.redDark))),
              const Text('Reintentar', style: TextStyle(color: FP.red, fontWeight: FontWeight.w800)),
            ]),
          )
        else if (data == null || data.days.isEmpty)
          const EmptyState(icon: Icons.bar_chart_rounded, title: 'Sin datos todavía', message: 'Registra una actividad o sincroniza tu wearable para ver tus métricas.')
        else
          ..._content(app, data),
      ],
    );
  }

  List<Widget> _content(AppState app, ActivitySummary m) {
    final values = m.days.map((d) => d.steps.toDouble()).toList();
    final total = values.fold<double>(0, (a, b) => a + b);
    final avg = total / values.length;
    final best = values.reduce((a, b) => a > b ? a : b);
    final labels = _week ? m.days.map((d) => d.weekdayLetter).toList() : m.days.map((d) => '${d.date.day}').toList();
    final types = ActivityType.values.where((t) => (m.byType[t]?.minutes ?? 0) > 0 || ActivityType.selectable.contains(t)).toList();
    final totalMin = types.fold<int>(0, (a, t) => a + (m.byType[t]?.minutes ?? 0));

    return [
      FpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Pasos por día', style: T.h3),
          gap(10),
          Row(children: [
            Expanded(child: StatBlock(label: 'Promedio', value: Fmt.number(avg), size: 20)),
            Expanded(child: StatBlock(label: 'Mejor día', value: Fmt.number(best), size: 20)),
            Expanded(child: StatBlock(label: 'Total', value: total >= 100000 ? '${(total / 1000).toStringAsFixed(0)}k' : Fmt.number(total), size: 20)),
          ]),
          gap(14),
          FpBarChart(
            key: ValueKey(_week),
            values: values,
            labels: labels,
            highlight: values.length - 1,
            goal: app.user.dailyStepGoal.toDouble(),
            height: 180,
            showEveryLabel: _week ? 1 : 5,
            format: (v) => Fmt.number(v),
          ),
          gap(4),
          const Text('Toca una barra para ver el valor.', style: T.small),
        ]),
      ),
      gap(),
      FpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: StatBlock(
                label: 'Ritmo cardíaco en reposo',
                value: m.restingHr == null ? '--' : '${m.restingHr}',
                unit: 'bpm',
                valueColor: FP.red,
                size: 28,
              ),
            ),
            if (m.restingDelta != null)
              FpTag(
                '${m.restingDelta! > 0 ? '+' : ''}${m.restingDelta} vs. semana pasada',
                icon: m.restingDelta! <= 0 ? Icons.trending_down_rounded : Icons.trending_up_rounded,
                color: m.restingDelta! <= 0 ? FP.mintSoft : FP.redSoft,
                textColor: m.restingDelta! <= 0 ? FP.green : FP.red,
              ),
          ]),
          gap(12),
          if (m.restingTrend.length >= 2)
            FpLineChart(data: m.restingTrend, height: 70, showDots: true, strokeWidth: 2.2)
          else
            const Text('Se calcula con las lecturas de tu wearable.', style: T.small),
          gap(4),
          const Text('Bajar tu ritmo en reposo es señal de mejor condición física.', style: T.small),
        ]),
      ),
      gap(),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: FpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.timeline_rounded, color: FP.green),
                gap(8),
                StatBlock(label: 'Distancia total', value: Fmt.km(m.totalKm), unit: 'km'),
              ]),
            ),
          ),
          hgap(10),
          Expanded(
            child: FpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.local_fire_department_rounded, color: FP.amber),
                gap(8),
                StatBlock(label: 'Calorías', value: Fmt.number(m.totalKcal), unit: 'kcal'),
              ]),
            ),
          ),
        ]),
      ),
      gap(),
      FpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Tiempo por actividad', style: T.h3),
          gap(12),
          if (totalMin > 0) StackedBar(parts: [for (final t in types) ((m.byType[t]?.minutes ?? 0).toDouble(), t.color)]),
          gap(14),
          for (final t in types)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                IconBadge(t.icon, color: t.color, size: 32),
                hgap(10),
                Expanded(child: Text(t.title, style: T.body)),
                Text(Fmt.duration(Duration(minutes: m.byType[t]?.minutes ?? 0)), style: T.bodyStrong),
                hgap(10),
                SizedBox(
                  width: 40,
                  child: Text(
                    totalMin == 0 ? '0%' : '${((m.byType[t]?.minutes ?? 0) / totalMin * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: T.muted,
                  ),
                ),
              ]),
            ),
        ]),
      ),
      gap(),
      FpCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Expanded(child: Text('Ritmo cardíaco de hoy', style: T.h3)),
            Text('por hora', style: T.small),
          ]),
          gap(12),
          if (app.summary.hrToday.length >= 2) ...[
            FpLineChart(data: app.summary.hrToday, height: 100),
            gap(8),
            Row(children: [
              _Legend(label: 'Mín', value: '${app.summary.hrToday.reduce((a, b) => a < b ? a : b).round()} bpm'),
              _Legend(label: 'Máx', value: '${app.summary.hrToday.reduce((a, b) => a > b ? a : b).round()} bpm'),
              _Legend(label: 'Actual', value: app.heartRate == null ? '--' : '${app.heartRate} bpm'),
            ]),
          ] else
            const Text('Sincroniza tu wearable para ver tu ritmo cardíaco del día.', style: T.muted),
        ]),
      ),
    ];
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: T.small),
          Text(value, style: T.bodyStrong),
        ]),
      );
}
