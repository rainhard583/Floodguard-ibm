import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/tsunami_risk_model.dart';
import '../repositories/real_tsunami_risk_repository.dart';
import '../repositories/tsunami_risk_repository.dart';

/// Sudah pakai elevasi tanah NYATA + data gempa besar NYATA di dekatnya
/// (lihat [RealTsunamiRiskRepository]) — bukan lagi
/// [MockTsunamiRiskRepository] yang cuma hash koordinat.
final tsunamiRiskRepositoryProvider = Provider<TsunamiRiskRepository>((ref) {
  return RealTsunamiRiskRepository();
});

/// Risiko tsunami untuk titik [point] yang dipilih di Peta.
final tsunamiRiskProvider =
    FutureProvider.autoDispose.family<TsunamiRisk?, LatLng>((ref, point) {
  return ref.watch(tsunamiRiskRepositoryProvider).getRiskForLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
});
