import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'metrics_screen.dart';
import 'sessions_screen.dart';

enum _Phase { ready, running, paused }

/// Figura 4: Actividad física. Cronómetro con datos de sensores simulados.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  ActivityType _type = ActivityType.running;
  _Phase _phase = _Phase.ready;
  Timer? _timer;
  int _secs = 0;
  double _km = 0;
  double _kcal = 0;
  double _steps = 0;
  int _hr = 0;
  final List<double> _hrSeries = [];
  bool _fast = false;
  final _rnd = Random();

  void _start() {
    setState(() {
      _phase = _Phase.running;
      if (_hr == 0) _hr = _type.baseHr - 28;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick(_fast ? 10 : 1));
  }

  void _tick(int seconds) {
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < seconds; i++) {
        _secs++;
        _km += _type.kmPerSecond * (0.9 + _rnd.nextDouble() * 0.2);
        _kcal += _type.kcalPerMinute / 60;
        _steps += _type.stepsPerSecond * (0.9 + _rnd.nextDouble() * 0.2);
        final target = _type.baseHr + sin(_secs / 40) * 9;
        _hr = (_hr + (target - _hr) * .08 + _rnd.nextInt(5) - 2).round().clamp(60, 195).toInt();
        if (_secs % 5 == 0) _hrSeries.add(_hr.toDouble());
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    _timer = null;
    setState(() => _phase = _Phase.paused);
  }

  Future<void> _finish() async {
    final wasRunning = _phase == _Phase.running;
    if (wasRunning) _pause();
    if (_secs < 10) {
      final discard = await confirmDialog(context,
          title: '¿Terminar actividad?', message: 'La actividad duró muy poco y no se guardará.', confirm: 'Terminar', destructive: true);
      if (!mounted) return;
      if (discard) _reset();
      return;
    }
    final app = AppScope.read(context);
    final session = app.buildSession(type: _type, seconds: _secs, km: _km, hr: _hrSeries, kcal: _kcal.round(), steps: _steps.round());
    final saved = await Navigator.of(context).push<bool>(fadeRoute(ActivitySummaryScreen(session: session)));
    if (!mounted) return;
    if (saved == true) {
      _reset();
      toast(context, 'Sesión guardada en tu historial');
    } else if (saved == false) {
      _reset();
      toast(context, 'Actividad descartada', icon: Icons.delete_outline_rounded);
    }
  }

  void _reset() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _phase = _Phase.ready;
      _secs = 0;
      _km = 0;
      _kcal = 0;
      _steps = 0;
      _hr = 0;
      _hrSeries.clear();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _phase != _Phase.ready;
    final device = AppScope.of(context).mainDevice;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad física'),
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Tooltip(
              message: 'Modo demo: el tiempo avanza 10 veces más rápido',
              child: FpPill('×10', selected: _fast, dense: true, icon: Icons.speed_rounded, onTap: () => setState(() => _fast = !_fast)),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
        Text(active ? 'Registrando ${_type.title.toLowerCase()}' : 'Elige qué vas a hacer', style: T.muted.copyWith(fontSize: 15)),
        gap(),
        SizedBox(
          height: 46,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ActivityType.selectable.length,
            separatorBuilder: (_, __) => hgap(8),
            itemBuilder: (_, i) {
              final t = ActivityType.selectable[i];
              return Opacity(
                opacity: active && t != _type ? .45 : 1,
                child: FpPill(t.label, icon: t.icon, selected: t == _type, onTap: active ? () {} : () => setState(() => _type = t)),
              );
            },
          ),
        ),
        gap(14),

        // Cronómetro
        FpCard(
          padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
          child: Column(children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: FpTag(
                key: ValueKey(_phase),
                _phase == _Phase.running ? 'En curso' : _phase == _Phase.paused ? 'En pausa' : 'Listo para empezar',
                icon: _phase == _Phase.running ? Icons.fiber_manual_record_rounded : _phase == _Phase.paused ? Icons.pause_rounded : Icons.check_rounded,
                color: _phase == _Phase.running ? FP.redSoft : FP.mint,
                textColor: _phase == _Phase.running ? FP.red : FP.ink,
              ),
            ),
            gap(10),
            FittedBox(
              child: Text(
                Fmt.clock(_secs),
                style: const TextStyle(fontSize: 60, fontWeight: FontWeight.w800, color: FP.ink, letterSpacing: -1.5, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
            const Text('Duración', style: T.muted),
          ]),
        ),
        gap(10),

        // Métricas en vivo
        Row(children: [
          Expanded(child: _LiveTile(value: _type.hasDistance ? Fmt.km(_km) : '--', unit: 'km')),
          hgap(10),
          Expanded(
            child: _LiveTile(
              value: _hr == 0 ? '--' : '$_hr',
              unit: 'bpm',
              color: FP.red,
              leading: _phase == _Phase.running ? BeatingHeart(bpm: _hr, size: 16) : null,
            ),
          ),
        ]),
        gap(10),
        Row(children: [
          Expanded(child: _LiveTile(value: '${_kcal.round()}', unit: 'kcal', small: true)),
          hgap(10),
          Expanded(child: _LiveTile(value: _type.hasDistance ? Fmt.pace(_km > 0.02 ? _secs / 60 / _km : null) : '--', unit: 'min/km', small: true)),
          hgap(10),
          Expanded(child: _LiveTile(value: Fmt.number(_steps), unit: 'pasos', small: true)),
        ]),

        if (_hrSeries.length >= 3) ...[
          gap(10),
          FpCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Ritmo cardíaco en vivo', style: T.muted),
              gap(8),
              FpLineChart(data: List<double>.from(_hrSeries), height: 70, animate: false),
            ]),
          ),
        ],
        gap(14),

        // Controles
        if (!active)
          FilledButton(
            onPressed: _start,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.play_arrow_rounded), SizedBox(width: 6), Text('Iniciar')]),
          )
        else
          Row(children: [
            Expanded(
              child: MintButton(
                label: _phase == _Phase.running ? 'Pausar' : 'Reanudar',
                icon: _phase == _Phase.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onPressed: _phase == _Phase.running ? _pause : _start,
              ),
            ),
            hgap(10),
            Expanded(
              child: FilledButton(
                onPressed: _finish,
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.stop_rounded), SizedBox(width: 6), Text('Terminar')]),
              ),
            ),
          ]),
        gap(12),

        if (device != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(device.connected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded, size: 16, color: device.connected ? FP.green : FP.subtle),
            hgap(6),
            Text(device.connected ? 'Sensores de ${device.name} conectados' : '${device.name} desconectado', style: T.small),
          ]),
        gap(18),
        Row(children: [
          Expanded(child: OutlinedButton.icon(onPressed: () => push(context, const SessionsScreen()), icon: const Icon(Icons.history_rounded), label: const Text('Sesiones'))),
          hgap(10),
          Expanded(child: OutlinedButton.icon(onPressed: () => push(context, const MetricsScreen()), icon: const Icon(Icons.bar_chart_rounded), label: const Text('Métricas'))),
        ]),
      ]),
    );
  }
}

class _LiveTile extends StatelessWidget {
  const _LiveTile({required this.value, required this.unit, this.color = FP.ink, this.small = false, this.leading});
  final String value;
  final String unit;
  final Color color;
  final bool small;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => FpCard(
        padding: EdgeInsets.symmetric(vertical: small ? 14 : 20, horizontal: 8),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (leading != null) ...[leading!, hgap(6)],
            Flexible(
              child: FittedBox(
                child: Text(
                  value,
                  style: TextStyle(fontSize: small ? 20 : 28, fontWeight: FontWeight.w800, color: color, fontFeatures: const [FontFeature.tabularFigures()]),
                ),
              ),
            ),
          ]),
          gap(2),
          Text(unit, style: T.small),
        ]),
      );
}

/// Resumen al terminar una actividad. "Guardar sesión" la envía a la API.
class ActivitySummaryScreen extends StatefulWidget {
  const ActivitySummaryScreen({super.key, required this.session});
  final Session session;

  @override
  State<ActivitySummaryScreen> createState() => _ActivitySummaryScreenState();
}

class _ActivitySummaryScreenState extends State<ActivitySummaryScreen> {
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await AppScope.read(context).addSession(widget.session);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, '${e.message} Tu actividad sigue aquí, intenta guardar de nuevo.', icon: Icons.cloud_off_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.close_rounded), onPressed: _saving ? null : () => Navigator.pop(context)),
          title: const Text('Resumen'),
        ),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 0, 20, 28), children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: .6, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: Container(
                width: 92,
                height: 92,
                decoration: BoxDecoration(color: s.type.color, shape: BoxShape.circle, boxShadow: [
                  BoxShadow(color: s.type.color.withValues(alpha: .35), blurRadius: 28, offset: const Offset(0, 10)),
                ]),
                child: const Icon(Icons.emoji_events_rounded, color: Colors.white, size: 46),
              ),
            ),
          ),
          gap(16),
          const Center(child: Text('¡Buen trabajo!', style: T.h1)),
          gap(4),
          Center(child: Text('${s.type.title} · ${Fmt.day(s.start)} ${Fmt.time(s.start)}', style: T.muted)),
          gap(20),
          SessionStatsGrid(session: s),
          if (s.hrSeries.length >= 2) ...[
            gap(12),
            FpCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ritmo cardíaco', style: T.h3),
                gap(10),
                FpLineChart(data: s.hrSeries, height: 110),
              ]),
            ),
          ],
          gap(20),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(disabledBackgroundColor: FP.red.withValues(alpha: .7), disabledForegroundColor: Colors.white),
            child: _saving
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Guardando…'),
                  ])
                : const Text('Guardar sesión'),
          ),
          gap(10),
          TextButton(
            onPressed: _saving
                ? null
                : () async {
                    final ok = await confirmDialog(context, title: '¿Descartar actividad?', message: 'Los datos de esta actividad no se guardarán.', confirm: 'Descartar', destructive: true);
                    if (ok && context.mounted) Navigator.pop(context, false);
                  },
            child: const Text('Descartar', style: TextStyle(color: FP.redDark)),
          ),
        ]),
      ),
    );
  }
}
