// TODO Implement this library.
import 'package:flutter/material.dart';

class DriverHistoryPage extends StatelessWidget {
  const DriverHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            'Trip & Earnings History',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Last 30 days • Total: 38 trips • ETB 24,850',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 32),

          // Placeholder for list – replace with real ListView.builder later
          _buildHistoryItem(
            context,
            date: 'Jan 25, 2026',
            route: 'Bole → Piassa',
            amount: '+ ETB 680',
            status: 'Completed',
          ),
          _buildHistoryItem(
            context,
            date: 'Jan 23, 2026',
            route: 'CMC → Meskel Square',
            amount: '+ ETB 520',
            status: 'Completed',
          ),
          _buildHistoryItem(
            context,
            date: 'Jan 20, 2026',
            route: 'Airport → Kazanchis',
            amount: '+ ETB 950',
            status: 'Completed',
          ),

          const SizedBox(height: 40),
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Export History (CSV)'),
              onPressed: () {
                // TODO
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(
    BuildContext context, {
    required String date,
    required String route,
    required String amount,
    required String status,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.local_taxi),
        ),
        title: Text(route, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              amount,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}