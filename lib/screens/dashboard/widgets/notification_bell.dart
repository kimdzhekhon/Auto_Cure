import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../../services/notification_service.dart';

/// Notification bell icon with badge and popup list.
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, service, _) {
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => _showNotifications(context, service),
            ),
            if (service.unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints:
                      const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    service.unreadCount > 99
                        ? '99+'
                        : '${service.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotifications(
      BuildContext context, NotificationService service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) {
          return Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    if (service.unreadCount > 0)
                      TextButton(
                        onPressed: () => service.markAllAsRead(),
                        child: const Text('Mark all read'),
                      ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep),
                      onPressed: () {
                        service.clear();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: service.notifications.isEmpty
                    ? const Center(
                        child: Text('No notifications',
                            style: TextStyle(color: Colors.grey)),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        itemCount: service.notifications.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (ctx, index) {
                          final n = service.notifications[index];
                          return ListTile(
                            leading: Icon(n.icon, color: n.color),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: n.read
                                    ? FontWeight.normal
                                    : FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.message,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                Text(
                                  DateFormat.yMd()
                                      .add_Hms()
                                      .format(n.timestamp),
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500]),
                                ),
                              ],
                            ),
                            tileColor: n.read
                                ? null
                                : n.color.withValues(alpha: 0.04),
                            onTap: () => service.markAsRead(n.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
