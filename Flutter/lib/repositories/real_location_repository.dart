import 'package:geolocator/geolocator.dart';
import '../models/app_location_model.dart';
import 'location_repository.dart';

/// GPS asli perangkat.
///
/// Tidak memakai lokasi hard-code/mock. Jika permission ditolak atau GPS
/// perangkat tidak tersedia, status dikembalikan ke UI agar user bisa retry.
class RealLocationRepository implements LocationRepository {
  @override
  Future<AppLocation> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return AppLocation(
        status: LocationStatus.unavailable,
        label: 'GPS perangkat tidak aktif',
        updatedAt: DateTime.now(),
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return AppLocation(
        status: LocationStatus.permissionRequired,
        label: 'Izin lokasi diperlukan',
        updatedAt: DateTime.now(),
      );
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 25,
      ),
    );

    return AppLocation(
      status: LocationStatus.available,
      label: 'Lokasi saya saat ini',
      latitude: position.latitude,
      longitude: position.longitude,
      updatedAt: DateTime.now(),
    );
  }
}
