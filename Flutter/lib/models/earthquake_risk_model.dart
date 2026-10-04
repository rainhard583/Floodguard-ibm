import 'package:flutter/foundation.dart';
import 'disaster_risk_level.dart';

/// Estimasi risiko gempa bumi untuk satu titik lokasi di peta.
///
/// Dihasilkan dari feed gempa BMKG dari data gempa nyata (BMKG
/// Earthquake Catalog, 90 hari terakhir) — bukan lagi hash acak dari
/// koordinat seperti versi mock sebelumnya. Tetap bukan prediksi resmi
/// BMKG: ini murni ringkasan riwayat gempa yang SUDAH terjadi di
/// sekitar lokasi. Ganti lewat `earthquakeRiskRepositoryProvider` tanpa
/// mengubah widget peta.
@immutable
class EarthquakeRisk {
  final DisasterRiskLevel level;
  final double distanceKm; // jarak perkiraan ke jalur sesar aktif terdekat
  final String description;
  final DateTime updatedAt;

  const EarthquakeRisk({
    required this.level,
    required this.distanceKm,
    required this.description,
    required this.updatedAt,
  });
}
