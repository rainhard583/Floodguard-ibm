import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/earthquake.dart';
import '../services/earthquake_service.dart';

final earthquakeServiceProvider = Provider<EarthquakeService>(
      (ref) => EarthquakeService(),
);

final globalEarthquakesProvider =
FutureProvider.autoDispose<List<Earthquake>>((ref) async {
  final service = ref.read(earthquakeServiceProvider);
  final overview = await service.getOverview();
  return overview.global;
});

final earthquakeOverviewProvider = FutureProvider.autoDispose
    .family<EarthquakeOverview, EarthquakeQuery>((ref, query) async {
  final service = ref.read(earthquakeServiceProvider);

  return service.getOverview(
    latitude: query.latitude,
    longitude: query.longitude,
    radiusKm: query.radiusKm,
  );
});

class EarthquakeQuery {
  final double? latitude;
  final double? longitude;
  final double radiusKm;

  const EarthquakeQuery({
    this.latitude,
    this.longitude,
    this.radiusKm = 500,
  });

  @override
  bool operator ==(Object other) {
    return other is EarthquakeQuery &&
        other.latitude == latitude &&
        other.longitude == longitude &&
        other.radiusKm == radiusKm;
  }

  @override
  int get hashCode {
    return Object.hash(latitude, longitude, radiusKm);
  }
}