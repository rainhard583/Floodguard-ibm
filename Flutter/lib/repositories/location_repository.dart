import '../models/app_location_model.dart';

/// Kontrak sumber data lokasi pengguna saat ini.
///
/// Implementasi GPS asli berada di `RealLocationRepository` dan memakai Geolocator.
/// Widget hanya bergantung pada kontrak ini.
abstract class LocationRepository {
  Future<AppLocation> getCurrentLocation();
}
