import '../models/tsunami_risk_model.dart';

/// Kontrak sumber data risiko tsunami untuk satu titik koordinat.
abstract class TsunamiRiskRepository {
  Future<TsunamiRisk?> getRiskForLocation({
    required double latitude,
    required double longitude,
  });
}
