import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StationNotificationsPage extends StatefulWidget {
  const StationNotificationsPage({Key? key}) : super(key: key);

  @override
  State<StationNotificationsPage> createState() => _StationNotificationsPageState();
}

class _StationNotificationsPageState extends State<StationNotificationsPage> {
  // Sample station notification data
  final List<StationNotification> _notifications = [
    StationNotification(
      id: '1',
      title: 'New Pre-order Received',
      message: 'John Doe placed a pre-order for 20L of Premium Gasoline. Delivery time: 3:00 PM',
      time: DateTime.now().subtract(const Duration(minutes: 10)),
      isRead: false,
      type: StationNotificationType.preorder,
    ),
    StationNotification(
      id: '2',
      title: 'Payment Confirmed',
      message: 'Payment of \$65.40 received for order #ORD-7890 from Jane Smith',
      time: DateTime.now().subtract(const Duration(hours: 1)),
      isRead: true,
      type: StationNotificationType.payment,
    ),
    StationNotification(
      id: '3',
      title: 'Low Stock Alert',
      message: 'Premium Gasoline is running low (less than 500L remaining). Consider restocking.',
      time: DateTime.now().subtract(const Duration(hours: 3)),
      isRead: false,
      type: StationNotificationType.stock,
    ),
    StationNotification(
      id: '4',
      title: 'New Driver Registered',
      message: 'Michael Johnson has registered as a delivery driver for your station',
      time: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      type: StationNotificationType.driver,
    ),
    StationNotification(
      id: '5',
      title: 'Customer Review',
      message: 'Sarah Williams left a 5-star review: "Great service and timely delivery!"',
      time: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      type: StationNotificationType.review,
    ),
    StationNotification(
      id: '6',
      title: 'Weekly Sales Report',
      message: 'Your station sold 2,450L of fuel this week. Revenue: \$3,675.00',
      time: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      type: StationNotificationType.report,
    ),
    StationNotification(
      id: '7',
      title: 'Maintenance Reminder',
      message: 'Scheduled equipment maintenance due next week. Please confirm availability.',
      time: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
      type: StationNotificationType.maintenance,
    ),
    StationNotification(
      id: '8',
      title: 'New Feature Available',
      message: 'Bulk order management feature is now available. Manage multiple orders at once.',
      time: DateTime.now().subtract(const Duration(days: 4)),
      isRead: true,
      type: StationNotificationType.system,
    ),
  ];

  bool _showOnlyUnread = false;

  List<StationNotification> get _filteredNotifications {
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

  Widget _buildNotificationCard(StationNotification notification) {
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
            _showNotificationDetail(notification);
          },
        ),
      ),
    );
  }

  Widget _getNotificationIcon(StationNotificationType type) {
    IconData icon;
    Color color;
    
    switch (type) {
      case StationNotificationType.preorder:
        icon = Icons.shopping_cart;
        color = Colors.orange;
        break;
      case StationNotificationType.payment:
        icon = Icons.payment;
        color = Colors.green;
        break;
      case StationNotificationType.stock:
        icon = Icons.inventory;
        color = Colors.red;
        break;
      case StationNotificationType.driver:
        icon = Icons.delivery_dining;
        color = Colors.blue;
        break;
      case StationNotificationType.review:
        icon = Icons.star;
        color = Colors.amber;
        break;
      case StationNotificationType.report:
        icon = Icons.analytics;
        color = Colors.purple;
        break;
      case StationNotificationType.maintenance:
        icon = Icons.build;
        color = Colors.grey;
        break;
      case StationNotificationType.system:
        icon = Icons.settings;
        color = Colors.blueGrey;
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

  void _showNotificationDetail(StationNotification notification) {
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

enum StationNotificationType {
  preorder,
  payment,
  stock,
  driver,
  review,
  report,
  maintenance,
  system,
}

class StationNotification {
  final String id;
  final String title;
  final String message;
  final DateTime time;
  bool isRead;
  final StationNotificationType type;

  StationNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    required this.isRead,
    required this.type,
  });
}