import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'devices_screen.dart';
import 'metrics_screen.dart';
import 'notifications_screen.dart';
import 'sessions_screen.dart';

/// Figura 3: Página principal ("Tu día").
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.onStartActivity, required this.onOpenGoals});
  final VoidCallback onStartActivity;
  final VoidCallback onOpenGoals;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final now = DateTime.now();
    final goal = app.user.dailyStepGoal <= 0 ? 10000 : app.user.dailyStepGoal;
    final progress = app.todaySteps / goal;
    final week = app.summary.days.length > 7 ? app.summary.days.sublist(app.summary.days.length - 7) : app.summary.days;
    final hr = app.heartRate;
    final last = app.lastSession;
    final device = app.mainDevice;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          color: FP.red,
          onRefresh: app.refreshAll,
          child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
          // Encabezado
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Hola, ${app.user.firstName}', style: T.muted.copyWith(fontSize: 15)),
                const Text('Tu día', style: T.h1),
              ]),
            ),
            _BellButton(count: app.unreadCount, onTap: () => push(context, const NotificationsScreen())),
          ]),
          gap(4),
          Row(children: [
            Text(Fmt.longDate(now), style: T.small),
            if (app.isDemo) ...[hgap(8), const FpTag('Modo demo', color: FP.redSoft, textColor: FP.red)],
            if (app.loading) ...[
              hgap(8),
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: FP.subtle)),
            ],
          ]),
          if (app.loadError != null) ...[
            gap(12),
            FpCard(
              color: FP.redSoft,
              onTap: app.refreshAll,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                const Icon(Icons.cloud_off_rounded, color: FP.redDark, size: 20),
                hgap(10),
                Expanded(child: Text(app.loadError!, style: T.small.copyWith(color: FP.redDark, fontWeight: FontWeight.w600))),
                const Text('Reintentar', style: TextStyle(color: FP.red, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          ],
          gap(16),

          // Pasos
          FpCard(
            padding: const EdgeInsets.all(18),
            onTap: () => push(context, const MetricsScreen()),
            child: Row(children: [
              ProgressRing(
                value: progress,
                size: 112,
                stroke: 13,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('${(progress * 100).clamp(0, 100).round()}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: FP.ink)),
                  const Text('meta', style: T.small),
                ]),
              ),
              hgap(18),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(Fmt.number(app.todaySteps), style: T.display),
                  Text('de ${Fmt.number(goal)} pasos', style: T.muted),
                  gap(12),
                  Row(children: [
                    _MiniStat(icon: Icons.timeline_rounded, text: '${Fmt.km(app.todayKm)} km'),
                    hgap(12),
                    _MiniStat(icon: Icons.timer_rounded, text: '${app.activeMinutes} min'),
                  ]),
                ]),
              ),
            ]),
          ),
          gap(),

          // Ritmo + calorías
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(
                child: FpCard(
                  onTap: () => push(context, const MetricsScreen()),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Expanded(child: Text('Ritmo cardíaco', style: T.muted)),
                      if (hr != null) BeatingHeart(bpm: hr, size: 18) else const Icon(Icons.favorite_border_rounded, color: FP.subtle, size: 18),
                    ]),
                    gap(6),
                    _BigValue(value: hr == null ? '--' : '$hr', unit: 'bpm', color: FP.red),
                    gap(8),
                    if (app.summary.hrToday.length >= 2)
                      FpLineChart(data: app.summary.hrToday, height: 36, strokeWidth: 2, fill: true)
                    else
                      const SizedBox(height: 36, child: Align(alignment: Alignment.bottomLeft, child: Text('Sin lecturas hoy', style: T.small))),
                  ]),
                ),
              ),
              hgap(10),
              Expanded(
                child: FpCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Row(children: [
                      Expanded(child: Text('Calorías', style: T.muted)),
                      Icon(Icons.local_fire_department_rounded, color: FP.amber, size: 20),
                    ]),
                    gap(6),
                    _BigValue(value: Fmt.number(app.todayCalories), unit: 'kcal'),
                    const Spacer(),
                    ProgressBar(value: app.todayCalories / 500, color: FP.amber, height: 7),
                    gap(6),
                    const Text('Meta 500 kcal', style: T.small),
                  ]),
                ),
              ),
            ]),
          ),
          gap(),

          // Último entrenamiento
          if (last != null)
            FpCard(
              onTap: () => push(context, SessionDetailScreen(session: last)),
              child: Row(children: [
                IconBadge(last.type.icon, color: last.type.color, size: 48),
                hgap(14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Último entrenamiento', style: T.h3),
                    gap(3),
                    Text(
                      '${Fmt.day(last.start)} · ${Fmt.duration(last.duration)}${last.km > 0 ? ' · ${Fmt.km(last.km)} km' : ''}',
                      style: T.muted,
                    ),
                  ]),
                ),
                FpTag(last.type.label),
              ]),
            ),
          gap(),

          // Semana
          FpCard(
            onTap: () => push(context, const MetricsScreen()),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Row(children: [
                Expanded(child: Text('Esta semana', style: T.h3)),
                Text('Ver métricas', style: TextStyle(color: FP.red, fontWeight: FontWeight.w700, fontSize: 13)),
                Icon(Icons.chevron_right_rounded, color: FP.red, size: 18),
              ]),
              gap(8),
              if (week.isEmpty)
                const SizedBox(height: 120, child: Center(child: Text('Aún no hay actividad esta semana', style: T.muted)))
              else
              FpBarChart(
                values: week.map((d) => d.steps.toDouble()).toList(),
                labels: week.map((d) => d.weekdayLetter).toList(),
                highlight: week.length - 1,
                height: 120,
                goal: goal.toDouble(),
                format: (v) => Fmt.number(v),
              ),
            ]),
          ),
          gap(),

          // Dispositivo
          if (device != null)
            FpCard(
              color: FP.mintSoft,
              onTap: () => push(context, const DevicesScreen()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(children: [
                Icon(device.icon, color: FP.green),
                hgap(10),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: device.name, style: const TextStyle(fontWeight: FontWeight.w800, color: FP.ink)),
                    TextSpan(
                      text: device.syncing
                          ? ' · sincronizando…'
                          : ' · ${device.battery == null ? '--' : '${device.battery}%'} · ${device.lastSync == null ? 'sin sincronizar' : Fmt.ago(device.lastSync!)}',
                      style: const TextStyle(color: FP.muted),
                    ),
                  ])),
                ),
                Icon(device.connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded, color: device.connected ? FP.green : FP.subtle, size: 20),
              ]),
            )
          else
            FpCard(
              color: FP.mintSoft,
              onTap: () => push(context, const DevicesScreen()),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: const Row(children: [
                Icon(Icons.bluetooth_searching_rounded, color: FP.green),
                SizedBox(width: 10),
                Expanded(child: Text('Vincula tu wearable para registrar pasos y ritmo cardíaco', style: T.bodyStrong)),
                Icon(Icons.chevron_right_rounded, color: FP.subtle),
              ]),
            ),
          gap(16),

          FilledButton(
            onPressed: onStartActivity,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.play_arrow_rounded),
              SizedBox(width: 6),
              Text('Iniciar actividad'),
            ]),
          ),
          gap(10),
          OutlinedButton(
            onPressed: () => push(context, const SessionsScreen()),
            child: const Text('Ver mis sesiones'),
          ),
        ]),
        ),
      ),
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue({required this.value, required this.unit, this.color = FP.ink});
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) => RichText(
        text: TextSpan(children: [
          TextSpan(text: value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.4)),
          TextSpan(text: ' $unit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: color)),
        ]),
      );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: FP.muted),
        hgap(4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w700, color: FP.ink, fontSize: 13)),
      ]);
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Stack(clipBehavior: Clip.none, children: [
        FpCard(
          color: FP.mint,
          padding: const EdgeInsets.all(11),
          radius: 14,
          onTap: onTap,
          child: const Icon(Icons.notifications_none_rounded, color: FP.ink, size: 24),
        ),
        if (count > 0)
          Positioned(
            right: -3,
            top: -3,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: FP.red, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
      ]);
}
