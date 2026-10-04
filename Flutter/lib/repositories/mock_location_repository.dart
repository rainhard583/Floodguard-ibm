import '../models/app_location_model.dart';
import 'location_repository.dart';

/// Implementasi MOCK — GPS sungguhan belum diimplementasikan (Phase 4).
/// Selalu mengembalikan status `available` dengan lokasi contoh, supaya
/// LocationCard bisa dikembangkan dan diuji dulu sebelum GPS asli ada.
///
/// Ganti nanti dengan `RealLocationRepository` (Geolocator + permission
/// handling) tanpa mengubah HomeScreen/LocationCard.
class MockLocationRepository implements LocationRepository {
  @override
  Future<AppLocation> getCurrentLocation() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return AppLocation(
      status: LocationStatus.available,
      label: 'Kelurahan Sukamaju, Bandung',
      latitude: -6.9147,
      longitude: 107.6098,
      updatedAt: DateTime.now(),
    );
  }
}
