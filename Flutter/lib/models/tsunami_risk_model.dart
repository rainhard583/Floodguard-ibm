import 'package:flutter/foundation.dart';
import 'disaster_risk_level.dart';

/// Estimasi risiko tsunami untuk satu titik lokasi di peta.
///
/// Dihasilkan [RealTsunamiRiskRepository] dari jarak-ke-pantai perkiraan
/// (elevasi tanah nyata di sekeliling titik, Open-Meteo) + riwayat gempa
/// besar nyata di dekat pantai tsb (USGS) — BUKAN prediksi resmi BMKG
/// InaTEWS, dan bukan lagi hash acak dari koordinat seperti versi mock
/// sebelumnya. Ganti lewat `tsunamiRiskRepositoryProvider` tanpa mengubah
/// widget peta.
@immutable
class TsunamiRisk {
  final DisasterRiskLevel level;
  final double distanceKm; // jarak perkiraan ke garis pantai terdekat
  final String description;
  final DateTime updatedAt;

  const TsunamiRisk({
    required this.level,
    required this.distanceKm,
    required this.description,
    required this.updatedAt,
  });
}
