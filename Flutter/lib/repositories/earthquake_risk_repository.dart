import '../models/earthquake_risk_model.dart';

/// Kontrak sumber data risiko gempa bumi untuk satu titik koordinat.
/// Diberi lat/lng eksplisit (bukan "lokasi saat ini" seperti di Home)
/// karena dipakai untuk titik APAPUN yang dipilih user di Peta.
abstract class EarthquakeRiskRepository {
  Future<EarthquakeRisk?> getRiskForLocation({
    required double latitude,
    required double longitude,
  });
}
