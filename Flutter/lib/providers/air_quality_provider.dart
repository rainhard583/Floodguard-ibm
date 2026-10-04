import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/air_quality_model.dart';
import '../repositories/air_quality_repository.dart';
import '../repositories/open_meteo_air_quality_repository.dart';

final airQualityRepositoryProvider = Provider<AirQualityRepository>((ref) {
  return OpenMeteoAirQualityRepository();
});

/// Kualitas udara untuk titik APAPUN di peta (dipakai layer Air Quality) —
/// pola sama dengan [weatherForLocationProvider]/[earthquakeRiskProvider]:
/// `.family` + `.autoDispose` supaya cache dibuang saat titik tidak lagi
/// dipakai widget manapun.
final airQualityForLocationProvider =
    FutureProvider.autoDispose.family<AirQuality?, LatLng>((ref, point) {
  return ref.watch(airQualityRepositoryProvider).getAirQualityForLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
});
