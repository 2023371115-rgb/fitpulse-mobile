import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

Color goalColor(Goal g) => g.done || g.progress >= .75 ? FP.green : FP.red;

/// Figura 5: Metas.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final goals = app.goals;
    final done = goals.where((g) => g.done).length;
    final avg = goals.isEmpty ? 0.0 : goals.fold<double>(0, (a, g) => a + g.progress) / goals.length;

    return FpPage(
      title: 'Metas',
      showBack: false,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: GestureDetector(
              onTap: () => showNewGoalSheet(context),
              child: const FpTag('+ Nueva meta', textColor: FP.ink),
            ),
          ),
        ),
      ],
      children: [
        // Resumen
        FpCard(
          color: FP.ink,
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            ProgressRing(
              value: avg,
              size: 78,
              stroke: 9,
              color: FP.mint,
              track: Colors.white.withValues(alpha: .14),
              child: Text('${(avg * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            hgap(16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$done de ${goals.length} metas cumplidas', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                gap(4),
                Text(
                  done == goals.length && goals.isNotEmpty ? '¡Completaste todo! 🎉' : 'Vas muy bien, sigue sumando actividad.',
                  style: TextStyle(color: Colors.white.withValues(alpha: .7), fontSize: 13.5),
                ),
              ]),
            ),
          ]),
        ),
        gap(16),
        if (goals.isEmpty)
          const EmptyState(icon: Icons.flag_rounded, title: 'Sin metas', message: 'Crea tu primera meta con el botón "+ Nueva meta".')
        else
          for (final g in goals) ...[
            _GoalCard(goal: g, onTap: () => _showGoalDetail(context, g)),
            gap(10),
          ],
        gap(6),
        OutlinedButton.icon(
          onPressed: () => showNewGoalSheet(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Agregar meta'),
        ),
      ],
    );
  }

  void _showGoalDetail(BuildContext context, Goal g) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final color = goalColor(g);
        const days = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              IconBadge(g.type.icon, color: color, size: 46),
              hgap(12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(g.title, style: T.h2),
                  Text(g.period == GoalPeriod.daily ? 'Meta diaria' : 'Meta semanal', style: T.muted),
                ]),
              ),
            ]),
            gap(22),
            Center(
              child: ProgressRing(
                value: g.progress,
                size: 150,
                stroke: 14,
                color: color,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(g.progress * 100).round()}%', style: T.h1),
                  Text(g.done ? 'Cumplida' : 'completado', style: T.small),
                ]),
              ),
            ),
            gap(18),
            Row(children: [
              Expanded(child: StatBlock(label: 'Actual', value: Fmt.compact(g.current), unit: g.type.unit, size: 22, center: true)),
              Container(width: 1, height: 40, color: FP.border),
              Expanded(child: StatBlock(label: 'Objetivo', value: Fmt.compact(g.target), unit: g.type.unit, size: 22, center: true)),
            ]),
            gap(18),
            Text(g.period == GoalPeriod.daily ? 'Últimos 7 días' : 'Últimas 7 semanas', style: T.h3),
            gap(8),
            FpBarChart(
              values: g.history.map((h) => h * 100).toList(),
              labels: g.period == GoalPeriod.daily ? days : const ['S1', 'S2', 'S3', 'S4', 'S5', 'S6', 'S7'],
              highlight: 6,
              height: 120,
              goal: 100,
              highlightColor: color,
              format: (v) => '${v.round()}%',
            ),
            gap(16),
            TextButton.icon(
              onPressed: () async {
                final ok = await confirmDialog(ctx, title: '¿Eliminar meta?', message: '"${g.title}" dejará de aparecer en tu lista.', confirm: 'Eliminar', destructive: true);
                if (!ok || !ctx.mounted) return;
                AppScope.read(context).deleteGoal(g.id);
                Navigator.pop(ctx);
                toast(context, 'Meta eliminada', icon: Icons.delete_outline_rounded);
              },
              icon: const Icon(Icons.delete_outline_rounded, color: FP.redDark),
              label: const Text('Eliminar meta', style: TextStyle(color: FP.redDark)),
            ),
          ]),
        );
      },
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal, required this.onTap});
  final Goal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = goal;
    final color = goalColor(g);
    final right = switch (g.type) {
      GoalType.steps when g.period == GoalPeriod.daily => '${(g.progress * 100).round()}%',
      GoalType.workouts => '${g.current.round()} de ${g.target.round()}',
      _ => '${g.periodLabel} · ${Fmt.goalValue(g.current, g.type.unit)}',
    };
    return FpCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconBadge(g.type.icon, color: color, size: 38),
          hgap(12),
          Expanded(child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(g.title, style: T.h3))),
          hgap(8),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: g.done ? const FpTag('Cumplida', icon: Icons.check_rounded) : Text(right, style: T.muted.copyWith(fontSize: 13)),
          ),
        ]),
        gap(12),
        ProgressBar(value: g.progress, color: color),
      ]),
    );
  }
}

/// Hoja para crear una nueva meta.
void showNewGoalSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _NewGoalSheet(),
  );
}

class _NewGoalSheet extends StatefulWidget {
  const _NewGoalSheet();
  @override
  State<_NewGoalSheet> createState() => _NewGoalSheetState();
}

class _NewGoalSheetState extends State<_NewGoalSheet> {
  GoalType _type = GoalType.steps;
  GoalPeriod _period = GoalPeriod.daily;
  late final TextEditingController _target = TextEditingController(text: _fmt(_type.suggested));

  String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();

  double _suggest(GoalType t, GoalPeriod p) {
    if (p == GoalPeriod.daily) return t.suggested;
    return switch (t) {
      GoalType.steps => 70000,
      GoalType.distance => 15,
      GoalType.workouts => 4,
      GoalType.calories => 3000,
      GoalType.sleep => 8,
      GoalType.active => 300,
    };
  }

  void _update({GoalType? type, GoalPeriod? period}) {
    setState(() {
      _type = type ?? _type;
      _period = period ?? _period;
      if (_type == GoalType.sleep) _period = GoalPeriod.daily;
      _target.text = _fmt(_suggest(_type, _period));
    });
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(_target.text.replaceAll(',', '')) ?? 0;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Nueva meta', style: T.h2),
        gap(4),
        const Text('Elige qué quieres lograr.', style: T.muted),
        gap(16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
          children: [
            for (final t in GoalType.values)
              GestureDetector(
                onTap: () => _update(type: t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: t == _type ? FP.redSoft : FP.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: t == _type ? FP.red : Colors.transparent, width: 1.6),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(t.icon, color: t == _type ? FP.red : FP.muted),
                    gap(6),
                    Text(t.label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: t == _type ? FP.red : FP.ink)),
                  ]),
                ),
              ),
          ],
        ),
        gap(16),
        Row(children: [
          Expanded(child: Center(child: FpPill('Diaria', selected: _period == GoalPeriod.daily, onTap: () => _update(period: GoalPeriod.daily)))),
          hgap(8),
          Expanded(
            child: Center(
              child: Opacity(
                opacity: _type == GoalType.sleep ? .4 : 1,
                child: FpPill('Semanal', selected: _period == GoalPeriod.weekly, onTap: () {
                  if (_type != GoalType.sleep) _update(period: GoalPeriod.weekly);
                }),
              ),
            ),
          ),
        ]),
        gap(16),
        TextField(
          controller: _target,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          decoration: InputDecoration(
            labelText: 'Objetivo',
            suffixText: _type.unit,
            prefixIcon: Icon(_type.icon, color: FP.subtle),
          ),
        ),
        gap(10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: FP.mintSoft, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.flag_rounded, color: FP.green, size: 18),
            hgap(8),
            Expanded(
              child: Text(value > 0 ? AppState.goalTitle(_type, value, _period) : 'Escribe un objetivo mayor a 0', style: T.bodyStrong),
            ),
          ]),
        ),
        gap(16),
        FilledButton(
          onPressed: value <= 0
              ? null
              : () {
                  AppScope.read(context).addGoal(type: _type, target: value, period: _period);
                  Navigator.pop(context);
                  toast(context, 'Meta creada');
                },
          child: const Text('Guardar meta'),
        ),
      ]),
    );
  }
}
