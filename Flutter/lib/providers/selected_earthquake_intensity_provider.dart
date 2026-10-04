import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/selected_location.dart';
import '../models/selected_earthquake_intensity.dart';
import '../repositories/selected_earthquake_intensity_repository.dart';

final selectedEarthquakeIntensityRepositoryProvider = Provider<SelectedEarthquakeIntensityRepository>((ref) {
  return SelectedEarthquakeIntensityRepository();
});

final selectedEarthquakeIntensityProvider = FutureProvider.autoDispose.family<SelectedEarthquakeIntensity?, SelectedLocation>((ref, location) {
  return ref.watch(selectedEarthquakeIntensityRepositoryProvider).getForLocation(
    latitude: location.latitude,
    longitude: location.longitude,
    displayName: location.displayName,
  );
});
