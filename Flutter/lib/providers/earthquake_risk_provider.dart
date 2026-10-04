import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/earthquake_risk_model.dart';
import '../repositories/earthquake_risk_repository.dart';
import '../repositories/bmkg_earthquake_risk_repository.dart';

/// Sudah pakai data gempa NYATA (USGS Earthquake Catalog, gratis, tanpa
/// API key) — bukan lagi [MockEarthquakeRiskRepository] yang cuma hash
/// koordinat.
final earthquakeRiskRepositoryProvider = Provider<EarthquakeRiskRepository>((ref) {
  return BmkgEarthquakeRiskRepository();
});

/// Risiko gempa bumi untuk titik [point] yang dipilih di Peta. `.family`
/// dipakai karena titiknya bisa berbeda-beda tergantung lokasi mana yang
/// user pilih (search atau tap langsung di peta).
final earthquakeRiskProvider =
    FutureProvider.autoDispose.family<EarthquakeRisk?, LatLng>((ref, point) {
  return ref.watch(earthquakeRiskRepositoryProvider).getRiskForLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
});
