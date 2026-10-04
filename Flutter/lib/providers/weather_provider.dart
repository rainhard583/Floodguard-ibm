import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/weather_model.dart';
import 'location_provider.dart';
import '../repositories/hybrid_weather_repository.dart';
import '../repositories/open_meteo_weather_repository.dart';
import '../repositories/weather_repository.dart';

/// WeatherAPI is the primary source for the current observation.
/// Open-Meteo remains the map/grid source and emergency fallback.
final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return HybridWeatherRepository();
});

/// Repository khusus Peta/point-check yang membaca Open-Meteo langsung.
/// Home tetap memakai HybridWeatherRepository (WeatherAPI/Laravel), tetapi
/// layer peta dan pemeriksaan titik menggunakan Open-Meteo agar tidak
/// bergantung pada backend WeatherAPI.
final openMeteoWeatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return OpenMeteoWeatherRepository();
});

/// Home weather is refreshed automatically while the screen is listening.
/// This does NOT manufacture a newer timestamp: every cycle performs a new
/// WeatherAPI request and the returned `last_updated` remains the source of
/// truth for the observation age.
final weatherProvider = StreamProvider.autoDispose<Weather?>((ref) async* {
  final repository = ref.watch(weatherRepositoryProvider);

  // Depend directly on the location state. When the user chooses a new
  // location, Riverpod disposes this provider and creates a new one, so the
  // old city's weather can never remain visible until the next timer tick.
  final location = await ref.watch(locationProvider.future);

  Future<Weather?> load() async {
    if (location.latitude != null && location.longitude != null) {
      return repository.getWeatherForLocation(
        latitude: location.latitude!,
        longitude: location.longitude!,
      );
    }
    return repository.getCurrentWeather();
  }

  while (true) {
    try {
      yield await load();
    } catch (e, st) {
      debugPrint('[WeatherProvider] refresh gagal: $e\n$st');
      rethrow;
    }

    // WeatherAPI current observations are provider-limited; polling more
    // often cannot manufacture a newer observation. Five minutes keeps the
    // app responsive while the UI still displays WeatherAPI last_updated.
    await Future<void>.delayed(const Duration(minutes: 5));
  }
});

final weatherForLocationProvider =
    FutureProvider.autoDispose.family<Weather?, LatLng>((ref, point) {
  return ref.watch(weatherRepositoryProvider).getWeatherForLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
});

/// Point-check di Peta memakai Open-Meteo langsung.
final openMeteoWeatherForLocationProvider =
    FutureProvider.autoDispose.family<Weather?, LatLng>((ref, point) {
  return ref.watch(openMeteoWeatherRepositoryProvider).getWeatherForLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
});
