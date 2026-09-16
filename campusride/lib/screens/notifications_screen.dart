import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_notification.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) return const SizedBox();

    final notifs = state.notifications;
    notifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        automaticallyImplyLeading: false,
        actions: [
          if (notifs.any((n) => !n.isRead))
            TextButton(
              onPressed: () => state.markAllNotificationsRead(),
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: notifs.isEmpty
          ? const EmptyState(icon: Icons.notifications_none, title: 'No updates', message: 'Ride requests, confirmations and reminders will appear here.')
          : RefreshIndicator(
              onRefresh: () => state.loadNotifications(),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final n = notifs[i];
                  return Card(
                    margin: EdgeInsets.zero,
                    color: n.isRead ? null : Colors.green.shade50,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.green.shade100,
                        child: Icon(_iconFor(n.type), color: Colors.green.shade800),
                      ),
                      title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(n.message),
                      trailing: n.isRead
                          ? null
                          : Container(width: 10, height: 10, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      onTap: () => state.markNotificationRead(n.id),
                    ),
                  );
                },
              ),
            ),
    );
  }

  IconData _iconFor(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.rideRequest:
        return Icons.chair_alt;
      case AppNotificationType.rideAccepted:
        return Icons.task_alt;
      case AppNotificationType.rideRejected:
        return Icons.cancel;
      case AppNotificationType.rideStarted:
        return Icons.play_circle;
      case AppNotificationType.rideCancelled:
        return Icons.event_busy;
      case AppNotificationType.waitlist:
        return Icons.event_seat;
      case AppNotificationType.general:
        return Icons.notifications;
    }
  }
}