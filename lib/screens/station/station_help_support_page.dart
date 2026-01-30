import 'package:flutter/material.dart';

class StationHelpSupportPage extends StatelessWidget {
  const StationHelpSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Support'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          Text('Frequently Asked Questions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Text('• How to add new fuel product?'),
          Text('• How to handle pre-order disputes?'),
          Text('• Contact support: support@yourapp.com'),
          SizedBox(height: 32),
          Text('Need urgent help? Call: +251-XXX-XXXXXX'),
        ],
      ),
    );
  }
}// TODO Implement this library.
