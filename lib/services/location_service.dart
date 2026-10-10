import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

class LocationService {
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationPermission> checkAndRequestPermission(
    BuildContext context,
    String lang, {
    required bool forceRequest,   // ← comma moved here, inside named params
  }) async {
    final serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'en'
                  ? 'Location services are disabled. Please enable them.'
                  : 'የአካባቢ አገልግሎቶች ተሰናክለዋል። እባክዎ ያንቁዋቸው።',
            ),
            action: SnackBarAction(
              label: lang == 'en' ? 'Settings' : 'ቅንብሮች',
              onPressed: () => Geolocator.openLocationSettings(),
            ),
          ),
        );
      }
      return LocationPermission.denied;
    }

    var permission = await Permission.location.status;

    // Only request if forced or currently denied (not permanently denied)
    if (forceRequest || permission.isDenied) {
      permission = await Permission.location.request();
    }

    if (permission.isPermanentlyDenied) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang == 'en'
                  ? 'Location permission permanently denied. Please enable in settings.'
                  : 'የአካባቢ ፍቃድ በቋሚነት ውድቅ ተደርጓል። እባክዎ በቅንብሮች ውስጥ ያንቁ።',
            ),
            action: SnackBarAction(
              label: lang == 'en' ? 'Open Settings' : 'ቅንብሮች ክፈት',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return LocationPermission.deniedForever;
    }

    // Return the final permission status after possible request
    return await Geolocator.checkPermission();
  }

  static Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 25),
      );
    } catch (e) {
      debugPrint("Location error: $e");
      return null;
    }
  }
}