import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StationNotificationsPage extends StatefulWidget {
  const StationNotificationsPage({super.key});

  @override
  State<StationNotificationsPage> createState() => _StationNotificationsPageState();
}

class _StationNotificationsPageState extends State<StationNotificationsPage> {
  final _currentUser = FirebaseAuth.instance.currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // You can do initial setup here if needed
  }

  Future<void> _markAsRead(String notificationId) async {
    if (_currentUser == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('stations')
          .doc(_currentUser!.uid)           // or use station document ID if different
          .collection('notifications')
          .doc(notificationId)
          .update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    if (_currentUser == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection('stations')
          .doc(_currentUser!.uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark all as read'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please sign in to view notifications')),
      );
    }

    final stationRef = FirebaseFirestore.instance
        .collection('stations')
        .doc(_currentUser!.uid); // ← adjust if your station doc ID ≠ user UID

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Mark all as read?'),
                  content: const Text('This action cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Mark All'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await _markAllAsRead();
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: stationRef
            .collection('notifications')
            .orderBy('createdAt', descending: true)
            .limit(60) // ← prevent loading too many at once
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 72, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No notifications yet', style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              final title = data['title'] as String? ?? 'Notification';
              final body = data['body'] as String? ?? '';
              final createdAt = data['createdAt'] as Timestamp?;
              final isRead = data['read'] as bool? ?? false;
              final type = data['type'] as String? ?? 'general'; // e.g. preorder, payment, low_stock

              final timeStr = createdAt != null
                  ? DateFormat('MMM d, HH:mm').format(createdAt.toDate())
                  : '—';

              Color? accentColor;
              IconData? leadingIcon;

              switch (type) {
                case 'preorder':
                  accentColor = Colors.blue.shade700;
                  leadingIcon = Icons.schedule;
                  break;
                case 'payment':
                  accentColor = Colors.green.shade700;
                  leadingIcon = Icons.payment;
                  break;
                case 'low_stock':
                  accentColor = Colors.orange.shade800;
                  leadingIcon = Icons.warning_amber_rounded;
                  break;
                case 'customer':
                  accentColor = Colors.purple.shade600;
                  leadingIcon = Icons.person;
                  break;
                default:
                  accentColor = Colors.grey.shade700;
                  leadingIcon = Icons.notifications;
              }

              return Dismissible(
                key: ValueKey(doc.id),
                background: Container(
                  color: Colors.red.shade700,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                direction: DismissDirection.endToStart,
                onDismissed: (_) {
                  // Optional: delete from Firestore
                  doc.reference.delete();
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead ? Colors.grey.shade300 : accentColor,
                    foregroundColor: isRead ? Colors.grey.shade700 : Colors.white,
                    child: Icon(leadingIcon),
                  ),
                  title: Text(
                    title,
                    style: TextStyle(
                      fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(body, maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: isRead
                      ? null
                      : Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                  onTap: () async {
                    // Mark as read when tapped
                    if (!isRead) {
                      await _markAsRead(doc.id);
                    }

                    // Optional: navigate somewhere depending on type
                    if (type == 'preorder') {
                      // Navigator.pushNamed(context, '/preorders', arguments: someId);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening related pre-order…')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}// TODO Implement this library.
