import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DriverNotificationsPage extends StatefulWidget {
  const DriverNotificationsPage({Key? key}) : super(key: key);

  @override
  State<DriverNotificationsPage> createState() => _DriverNotificationsPageState();
}

class _DriverNotificationsPageState extends State<DriverNotificationsPage> {
  // Sample notification data - in real app, fetch from Firebase
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'New Delivery Request',
      message: 'You have a new delivery request from Shell Station. Pickup time: 10:30 AM',
      time: DateTime.now().subtract(const Duration(minutes: 15)),
      isRead: false,
      type: NotificationType.delivery,
    ),
    NotificationItem(
      id: '2',
      title: 'Payment Received',
      message: 'Payment of \$45.60 has been credited to your account for delivery #D-7890',
      time: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: true,
      type: NotificationType.payment,
    ),
    NotificationItem(
      id: '3',
      title: 'Station Update',
      message: 'Total Station has updated their fuel prices. Check the latest rates.',
      time: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: false,
      type: NotificationType.station,
    ),
    NotificationItem(
      id: '4',
      title: 'Delivery Completed',
      message: 'Delivery #D-7889 has been completed successfully. Rating: 5 stars',
      time: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      type: NotificationType.success,
    ),
    NotificationItem(
      id: '5',
      title: 'Weekly Earnings Summary',
      message: 'Your weekly earnings: \$342.80. 15 deliveries completed.',
      time: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      type: NotificationType.earnings,
    ),
    NotificationItem(
      id: '6',
      title: 'System Maintenance',
      message: 'App will be down for maintenance on Sunday, 2:00 AM - 4:00 AM',
      time: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
      type: NotificationType.system,
    ),
    NotificationItem(
      id: '7',
      title: 'New Feature Available',
      message: 'Route optimization feature is now available. Try it on your next delivery!',
      time: DateTime.now().subtract(const Duration(days: 4)),
      isRead: true,
      type: NotificationType.feature,
    ),
  ];

  bool _showOnlyUnread = false;

  List<NotificationItem> get _filteredNotifications {
    if (_showOnlyUnread) {
      return _notifications.where((n) => !n.isRead).toList();
    }
    return _notifications;
  }

  int get _unreadCount {
    return _notifications.where((n) => !n.isRead).length;
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  void _toggleReadStatus(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index].isRead = !_notifications[index].isRead;
      }
    });
  }

  void _deleteNotification(String id) {
    setState(() {
      _notifications.removeWhere((n) => n.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification deleted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                FilterChip(
                  label: Text('All (${_notifications.length})'),
                  selected: !_showOnlyUnread,
                  onSelected: (selected) {
                    setState(() => _showOnlyUnread = false);
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text('Unread ($_unreadCount)'),
                  selected: _showOnlyUnread,
                  onSelected: (selected) {
                    setState(() => _showOnlyUnread = true);
                  },
                ),
              ],
            ),
          ),
          
          // Notifications list
          Expanded(
            child: _filteredNotifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showOnlyUnread 
                            ? 'No unread notifications'
                            : 'No notifications yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 20),
                    itemCount: _filteredNotifications.length,
                    itemBuilder: (context, index) {
                      final notification = _filteredNotifications[index];
                      return _buildNotificationCard(notification);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text('Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) {
        _deleteNotification(notification.id);
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        color: notification.isRead ? null : Colors.blue[50],
        elevation: 1,
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: _getNotificationIcon(notification.type),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                notification.message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(notification.time),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  if (!notification.isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'NEW',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          trailing: IconButton(
            icon: Icon(
              notification.isRead ? Icons.mark_email_unread_outlined : Icons.mark_email_read_outlined,
              color: Colors.blue,
            ),
            tooltip: notification.isRead ? 'Mark as unread' : 'Mark as read',
            onPressed: () => _toggleReadStatus(notification.id),
          ),
          onTap: () {
            _toggleReadStatus(notification.id);
            // In real app, you might navigate to a detail page or specific screen
            _showNotificationDetail(notification);
          },
        ),
      ),
    );
  }

  Widget _getNotificationIcon(NotificationType type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case NotificationType.delivery:
        icon = Icons.delivery_dining;
        color = Colors.orange;
        break;
      case NotificationType.payment:
        icon = Icons.payment;
        color = Colors.green;
        break;
      case NotificationType.station:
        icon = Icons.local_gas_station;
        color = Colors.blue;
        break;
      case NotificationType.success:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case NotificationType.earnings:
        icon = Icons.attach_money;
        color = Colors.amber;
        break;
      case NotificationType.system:
        icon = Icons.settings;
        color = Colors.grey;
        break;
      case NotificationType.feature:
        icon = Icons.new_releases;
        color = Colors.purple;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.blue;
    }
    
    return CircleAvatar(
      backgroundColor: color.withOpacity(0.1),
      child: Icon(icon, color: color),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(time);
    }
  }

  void _showNotificationDetail(NotificationItem notification) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notification.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                notification.message,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Divider(color: Colors.grey[300]),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat('MMM d, yyyy • h:mm a').format(notification.time),
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

enum NotificationType {
  delivery,
  payment,
  station,
  success,
  earnings,
  system,
  feature,
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  bool isRead;
  final NotificationType type;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
    required this.type,
  });
}