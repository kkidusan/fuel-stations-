// TODO Implement this library.
import 'package:flutter/material.dart';

class DriverNotificationsPage extends StatefulWidget {
  const DriverNotificationsPage({super.key});

  @override
  State<DriverNotificationsPage> createState() => _DriverNotificationsPageState();
}

class _DriverNotificationsPageState extends State<DriverNotificationsPage> {
  // ────────────────────────────────────────────────
  // In real app: replace this list with Firestore StreamBuilder
  // ────────────────────────────────────────────────
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'New Order Assigned',
      'body': 'Order #38492 – Pick up at Bole Michael, deliver to CMC',
      'time': '10 min ago',
      'read': false,
      'type': 'order',
    },
    {
      'title': 'Payment Received',
      'body': 'ETB 1,450.00 received for order #38112',
      'time': '2 hours ago',
      'read': true,
      'type': 'payment',
    },
    {
      'title': 'Station Update',
      'body': 'Total fuel price increased by 3% at all Oilibya stations',
      'time': 'Yesterday',
      'read': true,
      'type': 'system',
    },
    {
      'title': 'Account Warning',
      'body': 'Please complete your vehicle documents before next week',
      'time': '3 days ago',
      'read': false,
      'type': 'alert',
    },
    {
      'title': 'Order Completed',
      'body': 'Order #38501 marked as delivered – rate your customer',
      'time': '1 hour ago',
      'read': false,
      'type': 'order',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _notifications.any((n) => !n['read'])
                ? () {
                    setState(() {
                      for (var n in _notifications) {
                        n['read'] = true;
                      }
                    });
                  }
                : null,
          ),
        ],
      ),
      body: _notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notif = _notifications[index];
                final isUnread = !notif['read'];

                return Dismissible(
                  key: Key(notif['title'] + notif['time']),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) {
                    setState(() {
                      _notifications.removeAt(index);
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification deleted')),
                    );
                  },
                  child: ListTile(
                    leading: _buildLeadingIcon(notif['type'], isUnread, theme),
                    title: Text(
                      notif['title'],
                      style: TextStyle(
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      notif['body'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          notif['time'],
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (isUnread)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Icon(Icons.circle, size: 10, color: Colors.blue),
                          ),
                      ],
                    ),
                    tileColor: isUnread
                        ? theme.colorScheme.primaryContainer.withOpacity(0.12)
                        : null,
                    onTap: () {
                      setState(() {
                        notif['read'] = true;
                      });

                      // You can navigate to order detail, payment screen, etc.
                      if (notif['type'] == 'order') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Opening order ${notif['title']}...')),
                        );
                      }
                    },
                  ),
                );
              },
            ),
    );
  }

  Widget _buildLeadingIcon(String type, bool unread, ThemeData theme) {
    IconData icon;
    Color color;

    switch (type) {
      case 'order':
        icon = Icons.local_shipping;
        color = Colors.blue;
        break;
      case 'payment':
        icon = Icons.attach_money_rounded;
        color = Colors.green;
        break;
      case 'alert':
        icon = Icons.warning_amber_rounded;
        color = Colors.orange;
        break;
      case 'system':
        icon = Icons.info_outline;
        color = theme.colorScheme.primary;
        break;
      default:
        icon = Icons.notifications;
        color = theme.colorScheme.primary;
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color, size: 28),
        ),
        if (unread)
          Positioned(
            right: 2,
            top: 2,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: theme.colorScheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}