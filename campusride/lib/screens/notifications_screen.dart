import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../widgets/common_widgets.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final user = state.currentUser;
    if (user == null) return const SizedBox();

    final notifs = state.repository.getNotificationsForUser(user.userId);
    notifs.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Updates'),
        automaticallyImplyLeading: false,
        actions: [
          if (notifs.any((n) => !n.isRead))
            TextButton(
              onPressed: state.markAllNotificationsRead,
              child: const Text('Mark all read', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: notifs.isEmpty
          ? const EmptyState(icon: Icons.notifications_none, title: 'No updates', message: 'Ride requests, confirmations and reminders will appear here.')
          : ListView.separated(
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
                    onTap: () => state.repository.markNotificationRead(n.id),
                  ),
                );
              },
            ),
    );
  }

  IconData _iconFor(dynamic type) {
    const map = {
      0: Icons.chair_alt,
      1: Icons.task_alt,
      2: Icons.cancel,
      3: Icons.play_circle,
      4: Icons.event_busy,
      5: Icons.event_seat,
      6: Icons.notifications,
    };
    return map[type] ?? Icons.notifications;
  }
}