import '../models/flood_risk_model.dart';

/// Kontrak sumber data risiko banjir. HomeScreen/provider hanya bergantung
/// pada abstraksi ini, bukan implementasi konkretnya — sehingga
/// [MockFloodRiskRepository] bisa digantikan `RealFloodRiskRepository`
/// (yang nanti bicara ke mesin/algoritma risiko banjir di Phase 6) tanpa
/// mengubah kode UI sama sekali.
///
/// Mengembalikan `null` berarti risiko banjir memang belum tersedia untuk
/// lokasi ini (state legit, bukan error). Melempar exception berarti
/// proses pengambilan datanya yang gagal (network, dsb).
abstract class FloodRiskRepository {
  Future<FloodRisk?> getCurrentFloodRisk();

  /// Risiko banjir untuk titik [latitude]/[longitude] TERTENTU — dipakai
  /// supaya kartu Risiko Banjir di Beranda ikut berubah saat user GANTI
  /// lokasi (lewat [manualLocationOverrideProvider]), bukan selalu
  /// menampilkan angka yang sama.
  Future<FloodRisk?> getFloodRiskForLocation({
    required double latitude,
    required double longitude,
  });
}
