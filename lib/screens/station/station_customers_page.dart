import 'package:flutter/material.dart';

class StationCustomersPage extends StatelessWidget {
  const StationCustomersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: const Center(
        child: Text(
          'Customers List & Management\n(loyalty, history, contact info)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}// TODO Implement this library.
