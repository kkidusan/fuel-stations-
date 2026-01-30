import 'package:flutter/material.dart';

class StationInventoryPage extends StatelessWidget {
  const StationInventoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory'),
      ),
      body: const Center(
        child: Text(
          'Inventory Management\n(Add, edit, view fuel/products stock here)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}// TODO Implement this library.
