/// Canonical shared values.
///
/// Single source of truth for the enumerations exchanged with the backend.
/// Keep in sync with `backend/lib/enums.ts`.
///
///   Fuel:    petrol | diesel | kerosene   ("Benzene" == petrol)
///   Queue:   petrol | diesel | both       (which fuels a vehicle accepts)
///   Vehicle: car | taxi | minibus | pickup | truck | motorcycle | other
///
/// Screens should store/send the canonical value and use the `*Label`
/// helpers only for display.
library;

const List<String> kFuelTypes = ['petrol', 'diesel', 'kerosene'];
const List<String> kQueueFuelTypes = ['petrol', 'diesel', 'both'];
const List<String> kVehicleTypes = [
  'car',
  'taxi',
  'minibus',
  'pickup',
  'truck',
  'motorcycle',
  'other',
];

const Map<String, String> _fuelAliases = {
  'petrol': 'petrol',
  'gas': 'petrol',
  'gasoline': 'petrol',
  'benzene': 'petrol',
  'benzine': 'petrol',
  'regular': 'petrol',
  'premium': 'petrol',
  'petrol regular': 'petrol',
  'petrol premium': 'petrol',
  'petrol (regular)': 'petrol',
  'petrol (premium)': 'petrol',
  'diesel': 'diesel',
  'bio-diesel': 'diesel',
  'biodiesel': 'diesel',
  'gasoil': 'diesel',
  'gas oil': 'diesel',
  'kerosene': 'kerosene',
  'kerosine': 'kerosene',
  'both': 'both',
  'all': 'both',
};

const Map<String, String> _vehicleAliases = {
  'car': 'car',
  'private car': 'car',
  'private vehicle': 'car',
  'sedan': 'car',
  'automobile': 'car',
  'taxi': 'taxi',
  'cab': 'taxi',
  'taxicab': 'taxi',
  'minibus': 'minibus',
  'mini-bus': 'minibus',
  'mini bus': 'minibus',
  'microbus': 'minibus',
  'van': 'minibus',
  'coaster': 'minibus',
  'bus': 'minibus',
  'pickup': 'pickup',
  'pick-up': 'pickup',
  'pick up': 'pickup',
  'isuzu': 'pickup',
  'isuzu / pickup': 'pickup',
  'light truck': 'pickup',
  'truck': 'truck',
  'heavy truck': 'truck',
  'lorry': 'truck',
  'trailer': 'truck',
  'motorcycle': 'motorcycle',
  'motorbike': 'motorcycle',
  'bike': 'motorcycle',
  'scooter': 'motorcycle',
  'other': 'other',
  'unknown': 'other',
};

String _key(String? value) =>
    (value ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Map any fuel label to a canonical value (`both` only when [allowBoth]).
String? normalizeFuelType(String? value, {bool allowBoth = false}) {
  final hit = _fuelAliases[_key(value)];
  if (hit == null) return null;
  if (hit == 'both') return allowBoth ? 'both' : null;
  return hit;
}

/// Normalise a list of fuel labels, dropping unknowns and duplicates.
List<String> normalizeFuelTypes(dynamic value) {
  if (value is! List) return const [];
  final out = <String>[];
  for (final item in value) {
    final type = normalizeFuelType(item?.toString());
    if (type != null && !out.contains(type)) out.add(type);
  }
  return out;
}

/// Map any vehicle label to a canonical code (`other` when unrecognised).
String? normalizeVehicleType(String? value) {
  final key = _key(value);
  if (key.isEmpty) return null;
  return _vehicleAliases[key] ?? 'other';
}

/// Human-readable fuel label for a canonical value.
String fuelTypeLabel(String? value) =>
    switch (normalizeFuelType(value, allowBoth: true)) {
      'petrol' => 'Petrol',
      'diesel' => 'Diesel',
      'kerosene' => 'Kerosene',
      'both' => 'Both',
      _ => '—',
    };

/// Human-readable vehicle label for a canonical code.
String vehicleTypeLabel(String? value) => switch (normalizeVehicleType(value)) {
      'car' => 'Car',
      'taxi' => 'Taxi',
      'minibus' => 'Minibus',
      'pickup' => 'Pickup',
      'truck' => 'Truck',
      'motorcycle' => 'Motorcycle',
      'other' => 'Other',
      _ => '—',
    };
