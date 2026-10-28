import 'package:flutter/material.dart';
import '../data/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'profile_screen.dart';

/// Figura 9: Notificaciones.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final today = app.notices.where((n) => DateTime.now().difference(n.time).inHours < 24).toList();
    final older = app.notices.where((n) => DateTime.now().difference(n.time).inHours >= 24).toList();

    return FpPage(
      title: 'Notificaciones',
      actions: [
        if (app.unreadCount > 0)
          TextButton(onPressed: app.markAllRead, child: const Text('Marcar leídas', style: TextStyle(color: FP.red, fontWeight: FontWeight.w700))),
        IconButton(
          tooltip: 'Preferencias',
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => push(context, const NotificationSettingsScreen()),
        ),
      ],
      children: [
        if (app.notices.isEmpty)
          const EmptyState(icon: Icons.notifications_off_outlined, title: 'Todo al día', message: 'Aquí verás tus metas cumplidas, sincronizaciones y alertas.')
        else ...[
          if (today.isNotEmpty) ...[
            const Text('Hoy', style: T.label),
            gap(8),
            for (final n in today) _NoticeTile(notice: n),
          ],
          if (older.isNotEmpty) ...[
            gap(8),
            const Text('Anteriores', style: T.label),
            gap(8),
            for (final n in older) _NoticeTile(notice: n),
          ],
          gap(6),
          const Center(child: Text('Desliza una notificación para eliminarla.', style: T.small)),
        ],
      ],
    );
  }
}

class _NoticeTile extends StatelessWidget {
  const _NoticeTile({required this.notice});
  final AppNotice notice;

  @override
  Widget build(BuildContext context) {
    final n = notice;
    final app = AppScope.read(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey(n.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) {
          app.removeNotice(n.id);
          toast(context, 'Notificación eliminada', icon: Icons.delete_outline_rounded);
        },
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(color: FP.redSoft, borderRadius: BorderRadius.circular(FP.radius)),
          child: const Icon(Icons.delete_outline_rounded, color: FP.red),
        ),
        child: FpCard(
          color: n.read ? FP.card : FP.mintSoft,
          onTap: () => app.markRead(n.id),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            IconBadge(n.kind.icon, color: n.kind.color, background: Colors.white, size: 42),
            hgap(12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(n.title, style: T.h3.copyWith(fontSize: 16))),
                  hgap(8),
                  Text(Fmt.ago(n.time), style: T.small),
                ]),
                gap(3),
                Text(n.body, style: T.muted.copyWith(fontSize: 13.5)),
              ]),
            ),
            if (!n.read) ...[
              hgap(8),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(color: FP.red, shape: BoxShape.circle),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
