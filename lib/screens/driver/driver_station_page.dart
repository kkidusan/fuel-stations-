// TODO Implement this library.
import 'package:flutter/material.dart';

class DriverStationPage extends StatelessWidget {
  const DriverStationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_gas_station_rounded,
              size: 100,
              color: Colors.green.shade700,
            ),
            const SizedBox(height: 32),
            Text(
              'Find Nearby Fuel Stations',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Text(
              '• Nearest petrol & diesel stations\n'
              '• Current fuel prices in Addis Ababa\n'
              '• Rest areas & service points\n'
              '• Map view coming soon',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    height: 1.5,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('Open Map'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: () {
                // TODO: integrate google_maps_flutter or flutter_map
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.filter_list),
              label: const Text('Filter Stations'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
              ),
              onPressed: () {
                // TODO
              },
            ),
          ],
        ),
      ),
    );
  }
}