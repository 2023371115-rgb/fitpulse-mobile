import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Figura 8: Dispositivos conectados (simulación de Bluetooth/sensores).
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});
  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  Timer? _clock;
  int _step = 0;
  Timer? _stepTimer;

  static const _syncSteps = ['Conectando por Bluetooth…', 'Leyendo sensores…', 'Guardando datos…'];

  @override
  void initState() {
    super.initState();
    // Refresca "hace X min" cada 30 s.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _stepTimer?.cancel();
    super.dispose();
  }

  Future<void> _sync(Device d) async {
    final app = AppScope.read(context);
    setState(() => _step = 0);
    _stepTimer?.cancel();
    _stepTimer = Timer.periodic(const Duration(milliseconds: 800), (t) {
      if (!mounted) return;
      setState(() => _step = min(_step + 1, _syncSteps.length - 1));
    });
    final n = await app.syncDevice(d);
    _stepTimer?.cancel();
    if (!mounted) return;
    toast(context, 'Sincronizado: ${Fmt.number(n)} pasos nuevos', icon: Icons.sync_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final main = app.mainDevice;
    final others = app.devices.skip(1).toList();

    return FpPage(
      title: 'Dispositivos',
      children: [
        if (main == null)
          const EmptyState(icon: Icons.watch_rounded, title: 'Sin dispositivos', message: 'Vincula tu smartwatch o banda para registrar tu actividad automáticamente.')
        else ...[
          _MainDeviceCard(device: main, stepLabel: main.syncing ? _syncSteps[_step] : null, onToggle: () => app.toggleConnection(main)),
          gap(),
          FilledButton(
            onPressed: main.syncing || !main.connected ? null : () => _sync(main),
            style: FilledButton.styleFrom(disabledBackgroundColor: FP.red.withValues(alpha: .55), disabledForegroundColor: Colors.white),
            child: main.syncing
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Sincronizando…'),
                  ])
                : Text(main.connected ? 'Sincronizar ahora' : 'Dispositivo desconectado'),
          ),
        ],
        gap(18),
        const Text('Datos que se comparten', style: T.label),
        gap(8),
        for (final k in app.sharedData.keys) ...[
          FpCard(
            padding: const EdgeInsets.fromLTRB(16, 6, 10, 6),
            onTap: () => app.setShared(k, !app.sharedData[k]!),
            child: Row(children: [
              Icon(_iconFor(k), color: FP.muted, size: 22),
              hgap(12),
              Expanded(child: Text(k, style: const TextStyle(fontSize: 16, color: FP.ink))),
              FpTag(app.sharedData[k]! ? 'Activo' : 'Inactivo', color: app.sharedData[k]! ? FP.mint : FP.track),
              hgap(4),
              Switch(value: app.sharedData[k]!, onChanged: (v) => app.setShared(k, v)),
            ]),
          ),
          gap(8),
        ],
        if (others.isNotEmpty) ...[
          gap(10),
          const Text('Otros dispositivos', style: T.label),
          gap(8),
          for (final d in others) ...[
            FpCard(
              child: Row(children: [
                IconBadge(d.icon, color: FP.ink, background: FP.mint, size: 42),
                hgap(12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d.name, style: T.bodyStrong),
                    Text('${d.model} · ${d.connected ? 'Conectado' : 'Desconectado'}', style: T.small),
                  ]),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: FP.muted),
                  onSelected: (v) async {
                    if (v == 'toggle') {
                      app.toggleConnection(d);
                    } else if (v == 'remove') {
                      final ok = await confirmDialog(context, title: '¿Olvidar ${d.name}?', message: 'Dejará de compartir datos con FitPulse.', confirm: 'Olvidar', destructive: true);
                      if (ok) app.removeDevice(d.id);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'toggle', child: Text(d.connected ? 'Desconectar' : 'Conectar')),
                    const PopupMenuItem(value: 'remove', child: Text('Olvidar dispositivo')),
                  ],
                ),
              ]),
            ),
            gap(8),
          ],
        ],
        gap(8),
        MintButton(
          label: 'Buscar otro dispositivo',
          icon: Icons.bluetooth_searching_rounded,
          onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => const _ScanSheet()),
        ),
        gap(14),
        const Row(children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: FP.subtle),
          SizedBox(width: 6),
          Expanded(child: Text('Tus datos se cifran y solo se comparten con tu cuenta de FitPulse.', style: T.small)),
        ]),
      ],
    );
  }

  IconData _iconFor(String k) => switch (k) {
        'Pasos' => Icons.directions_walk_rounded,
        'Ritmo cardíaco' => Icons.favorite_border_rounded,
        'Movimiento' => Icons.sensors_rounded,
        _ => Icons.bedtime_outlined,
      };
}

class _MainDeviceCard extends StatelessWidget {
  const _MainDeviceCard({required this.device, required this.onToggle, this.stepLabel});
  final Device device;
  final VoidCallback onToggle;
  final String? stepLabel;

  @override
  Widget build(BuildContext context) {
    final d = device;
    final batteryColor = d.battery <= 20 ? FP.red : d.battery <= 50 ? FP.amber : FP.green;
    return FpCard(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _WatchAvatar(active: d.syncing),
          hgap(14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: T.h3.copyWith(fontSize: 19)),
              gap(3),
              Row(children: [
                Icon(Icons.circle, size: 10, color: d.connected ? FP.green : FP.subtle),
                hgap(6),
                Text('${d.connected ? 'Conectado' : 'Desconectado'} · ${d.battery}%', style: T.muted.copyWith(fontSize: 13)),
              ]),
            ]),
          ),
          Switch(value: d.connected, onChanged: (_) => onToggle()),
        ]),
        gap(14),
        Row(children: [
          Icon(Icons.battery_std_rounded, size: 18, color: batteryColor),
          hgap(8),
          Expanded(child: ProgressBar(value: d.battery / 100, color: batteryColor, height: 7)),
          hgap(10),
          Text('${d.battery}%', style: T.small),
        ]),
        gap(12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Text(
            stepLabel ?? 'Última sincronización: ${Fmt.ago(d.lastSync)}',
            key: ValueKey(stepLabel ?? 'idle'),
            style: T.muted.copyWith(fontSize: 13, color: stepLabel != null ? FP.red : FP.muted, fontWeight: stepLabel != null ? FontWeight.w700 : FontWeight.w400),
          ),
        ),
        gap(10),
        Wrap(spacing: 6, runSpacing: 6, children: [
          FpTag(d.model, color: Colors.white),
          FpTag('Firmware ${d.firmware}', color: Colors.white),
          const FpTag('BLE 5.2', color: Colors.white),
        ]),
      ]),
    );
  }
}

class _WatchAvatar extends StatefulWidget {
  const _WatchAvatar({required this.active});
  final bool active;
  @override
  State<_WatchAvatar> createState() => _WatchAvatarState();
}

class _WatchAvatarState extends State<_WatchAvatar> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didUpdateWidget(covariant _WatchAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_c.isAnimating) _c.repeat();
    if (!widget.active && _c.isAnimating) {
      _c
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 54,
        height: 54,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => Stack(alignment: Alignment.center, children: [
            if (widget.active)
              Container(
                width: 54 * (0.8 + _c.value * .4),
                height: 54 * (0.8 + _c.value * .4),
                decoration: BoxDecoration(shape: BoxShape.circle, color: FP.green.withValues(alpha: .25 * (1 - _c.value))),
              ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(color: FP.mint, borderRadius: BorderRadius.circular(15)),
              child: const Icon(Icons.watch_rounded, color: FP.ink, size: 28),
            ),
          ]),
        ),
      );
}

/// Búsqueda simulada de dispositivos cercanos con efecto de radar.
class _ScanSheet extends StatefulWidget {
  const _ScanSheet();
  @override
  State<_ScanSheet> createState() => _ScanSheetState();
}

class _ScanSheetState extends State<_ScanSheet> with SingleTickerProviderStateMixin {
  late final AnimationController _radar = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  final List<FoundDevice> _found = [];
  final List<Timer> _timers = [];
  String? _pairing;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < MockData.nearbyDevices.length; i++) {
      _timers.add(Timer(Duration(milliseconds: 900 + i * 900), () {
        if (mounted) setState(() => _found.add(MockData.nearbyDevices[i]));
      }));
    }
    _timers.add(Timer(const Duration(milliseconds: 3600), () {
      if (mounted) setState(() => _radar.stop());
    }));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _radar.dispose();
    super.dispose();
  }

  Future<void> _pair(FoundDevice f) async {
    final app = AppScope.read(context);
    final already = app.devices.any((d) => d.name == f.name);
    if (already) {
      toast(context, '${f.name} ya está vinculado', icon: Icons.info_rounded);
      return;
    }
    final code = (100000 + Random().nextInt(900000)).toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Código de vinculación', style: T.h2),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Confirma que ${f.name} muestra este código:', style: T.muted, textAlign: TextAlign.center),
          gap(16),
          Text(
            '${code.substring(0, 3)} ${code.substring(3)}',
            style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: 4, color: FP.ink, fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ]),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(minimumSize: const Size(110, 46)), child: const Text('Vincular')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _pairing = f.name);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    app.pairDevice(f);
    Navigator.pop(context);
    toast(context, '${f.name} vinculado correctamente', icon: Icons.bluetooth_connected_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final scanning = _radar.isAnimating;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Buscar dispositivos', style: T.h2),
        gap(4),
        Text(scanning ? 'Mantén tu dispositivo cerca y con Bluetooth activo.' : '${_found.length} dispositivos encontrados.', style: T.muted),
        gap(14),
        SizedBox(
          height: 170,
          child: AnimatedBuilder(
            animation: _radar,
            builder: (_, __) => CustomPaint(painter: _RadarPainter(t: _radar.value, active: scanning), child: const Center(child: Icon(Icons.bluetooth_rounded, color: FP.red, size: 34))),
          ),
        ),
        gap(10),
        for (final f in _found)
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutCubic,
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: child)),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FpCard(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(children: [
                  IconBadge(f.kind == DeviceKind.band ? Icons.watch_rounded : Icons.watch_outlined, color: FP.ink, background: FP.mint, size: 40),
                  hgap(12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(f.name, style: T.bodyStrong),
                      Text(f.model, style: T.small),
                    ]),
                  ),
                  _Signal(level: f.signal),
                  hgap(10),
                  SizedBox(
                    height: 36,
                    child: _pairing == f.name
                        ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: FP.red)))
                        : FilledButton(
                            onPressed: _pairing != null ? null : () => _pair(f),
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14), textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                            child: const Text('Vincular'),
                          ),
                  ),
                ]),
              ),
            ),
          ),
        if (!scanning) ...[
          gap(6),
          OutlinedButton.icon(
            onPressed: () => setState(() {
              _found.clear();
              _radar.repeat();
              for (var i = 0; i < MockData.nearbyDevices.length; i++) {
                _timers.add(Timer(Duration(milliseconds: 700 + i * 700), () {
                  if (mounted) setState(() => _found.add(MockData.nearbyDevices[i]));
                }));
              }
              _timers.add(Timer(const Duration(milliseconds: 2800), () {
                if (mounted) setState(() => _radar.stop());
              }));
            }),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Buscar de nuevo'),
          ),
        ],
      ]),
    );
  }
}

class _Signal extends StatelessWidget {
  const _Signal({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < 4; i++)
          Container(
            width: 4,
            height: 6.0 + i * 4,
            margin: const EdgeInsets.only(left: 2),
            decoration: BoxDecoration(color: i < level ? FP.green : FP.track, borderRadius: BorderRadius.circular(2)),
          ),
      ]);
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.t, required this.active});
  final double t;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final maxR = size.height / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..color = FP.border
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      canvas.drawCircle(c, maxR * i / 3, ring);
    }
    canvas.drawCircle(c, 30, Paint()..color = FP.redSoft);
    if (!active) return;
    for (var k = 0; k < 2; k++) {
      final p = (t + k * .5) % 1;
      canvas.drawCircle(
        c,
        30 + (maxR - 30) * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = FP.red.withValues(alpha: .5 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t || old.active != active;
}
