import 'dart:math';
import '../models/flood_risk_model.dart';
import 'flood_risk_repository.dart';

/// Implementasi MOCK — dipakai selama Phase 3 untuk pengembangan UI saja.
/// Mesin/algoritma risiko banjir sungguhan adalah pekerjaan Phase 6.
///
/// Ganti nanti dengan `RealFloodRiskRepository` (tanpa mengubah
/// HomeScreen/FloodRiskCard) begitu mesin risikonya sudah ada.
class MockFloodRiskRepository implements FloodRiskRepository {
  @override
  Future<FloodRisk?> getCurrentFloodRisk() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return FloodRisk(
      level: FloodRiskLevel.waspada,
      score: 42,
      description:
          'Curah hujan meningkat di area sekitar Anda. Tetap waspada dan pantau kondisi sekitar.',
      updatedAt: DateTime.now(),
    );
  }

  /// Sama-sama MOCK — dibuat deterministik dari koordinat (pakai koordinat
  /// sebagai seed) supaya lokasi berbeda yang dipilih user di Beranda
  /// menampilkan skor yang berbeda pula (bukan selalu WASPADA 42/100),
  /// tapi tetap konsisten tiap dibuka ulang untuk lokasi yang sama.
  @override
  Future<FloodRisk?> getFloodRiskForLocation({
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final seed = ((latitude * 10000).round() * 17 + (longitude * 10000).round()).abs();
    final random = Random(seed);
    final score = 5 + random.nextInt(95);

    final FloodRiskLevel level;
    final String description;
    if (score < 30) {
      level = FloodRiskLevel.aman;
      description = 'Kondisi di area ini aman. Tidak ada indikasi genangan atau banjir.';
    } else if (score < 55) {
      level = FloodRiskLevel.waspada;
      description = 'Curah hujan meningkat di area ini. Tetap waspada dan pantau kondisi sekitar.';
    } else if (score < 80) {
      level = FloodRiskLevel.siaga;
      description = 'Genangan mulai terpantau di beberapa titik area ini. Siaga & siapkan rencana evakuasi.';
    } else {
      level = FloodRiskLevel.bahaya;
      description = 'Risiko banjir tinggi di area ini. Segera pindah ke tempat yang lebih tinggi bila perlu.';
    }

    return FloodRisk(
      level: level,
      score: score,
      description: description,
      updatedAt: DateTime.now(),
    );
  }
}
