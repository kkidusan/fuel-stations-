// TODO Implement this library.
import 'package:flutter/material.dart';

class StationHistoryPage extends StatelessWidget {
  const StationHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order History'),
      ),
      body: const Center(
        child: Text(
          'Last 30 days orders appear here\n(Total revenue, stats, etc.)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ),
    );
  }
}