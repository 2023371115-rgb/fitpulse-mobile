import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Figura 7: Métricas.
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});
  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  bool _week = true;
  late final List<double> _month = MockData.monthSteps();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final week = [...MockData.weekSteps.sublist(0, 6), app.todaySteps.toDouble()];
    final data = _week ? week : _month;
    final total = data.fold<double>(0, (a, b) => a + b);
    final avg = total / data.length;
    final best = data.reduce((a, b) => a > b ? a : b);
    final labels = _week ? MockData.weekLabels : [for (var i = 0; i < 30; i++) '${i + 1}'];

    // Distribución por tipo de actividad
    final byType = <ActivityType, int>{for (final t in ActivityType.values) t: 0};
    for (final s in app.sessions) {
      byType[s.type] = byType[s.type]! + s.duration.inMinutes;
    }
    final totalMin = byType.values.fold<int>(0, (a, b) => a + b);
    final distance = _week ? 27.4 : 112.8;
    final kcal = _week ? 2860 : 11940;

    return FpPage(
      title: 'Métricas',
      children: [
        Row(children: [
          FpPill('Semana', selected: _week, dense: true, onTap: () => setState(() => _week = true)),
          hgap(8),
          FpPill('Mes', selected: !_week, dense: true, onTap: () => setState(() => _week = false)),
          const Spacer(),
          Text(_week ? 'Últimos 7 días' : 'Últimos 30 días', style: T.small),
        ]),
        gap(14),
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
              values: data,
              labels: labels,
              highlight: data.length - 1,
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
                child: StatBlock(label: 'Ritmo cardíaco en reposo', value: '${MockData.restingHr}', unit: 'bpm', valueColor: FP.red, size: 28),
              ),
              FpTag('${MockData.restingHrDelta} vs. semana pasada', icon: Icons.trending_down_rounded, color: FP.mintSoft, textColor: FP.green),
            ]),
            gap(12),
            const FpLineChart(data: MockData.restingHrTrend, height: 70, showDots: true, strokeWidth: 2.2),
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
                  StatBlock(label: 'Distancia total', value: Fmt.km(distance), unit: 'km'),
                ]),
              ),
            ),
            hgap(10),
            Expanded(
              child: FpCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.local_fire_department_rounded, color: FP.amber),
                  gap(8),
                  StatBlock(label: 'Calorías', value: Fmt.number(kcal), unit: 'kcal'),
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
            StackedBar(parts: [for (final t in ActivityType.values) (byType[t]!.toDouble(), t.color)]),
            gap(14),
            for (final t in ActivityType.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(children: [
                  IconBadge(t.icon, color: t.color, size: 32),
                  hgap(10),
                  Expanded(child: Text(t.title, style: T.body)),
                  Text(Fmt.duration(Duration(minutes: byType[t]!)), style: T.bodyStrong),
                  hgap(10),
                  SizedBox(
                    width: 40,
                    child: Text(
                      totalMin == 0 ? '0%' : '${(byType[t]! / totalMin * 100).round()}%',
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
              Text('06:00 – ahora', style: T.small),
            ]),
            gap(12),
            const FpLineChart(data: MockData.todayHr, height: 100),
            gap(8),
            Row(children: [
              _Legend(label: 'Mín', value: '${MockData.todayHr.reduce((a, b) => a < b ? a : b).round()} bpm'),
              _Legend(label: 'Máx', value: '${MockData.todayHr.reduce((a, b) => a > b ? a : b).round()} bpm'),
              _Legend(label: 'Actual', value: '${app.heartRate} bpm'),
            ]),
          ]),
        ),
      ],
    );
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
