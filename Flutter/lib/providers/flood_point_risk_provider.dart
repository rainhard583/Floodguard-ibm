import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_point_risk.dart';
import '../services/flood_point_risk_service.dart';

final floodPointRiskServiceProvider = Provider<FloodPointRiskService>((ref) {
  final service = FloodPointRiskService();
  ref.onDispose(service.dispose);
  return service;
});

final floodPointRiskProvider = FutureProvider.autoDispose.family<FloodPointRisk, FloodPointRiskRequest>((ref, request) {
  return ref.watch(floodPointRiskServiceProvider).check(
        latitude: request.latitude,
        longitude: request.longitude,
      );
});

class FloodPointRiskRequest {
  final double latitude;
  final double longitude;

  const FloodPointRiskRequest(this.latitude, this.longitude);

  @override
  bool operator ==(Object other) => other is FloodPointRiskRequest && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}
