import '../models/flood_alert_model.dart';
import '../models/flood_risk_model.dart';
import 'flood_alert_repository.dart';

/// Implementasi MOCK — belum terhubung ke sumber data resmi (BMKG/BPBD)
/// maupun push notification sungguhan (keduanya Phase 12). Mengembalikan
/// satu contoh alert aktif supaya AlertCard bisa dikembangkan dan diuji.
///
/// Ganti nanti dengan `RealFloodAlertRepository` tanpa mengubah
/// HomeScreen/AlertCard.
class MockFloodAlertRepository implements FloodAlertRepository {
  @override
  Future<List<FloodAlert>> getActiveAlerts() async {
    await Future.delayed(const Duration(milliseconds: 550));
    return [
      FloodAlert(
        id: 'mock-alert-1',
        title: 'Peringatan Dini Banjir',
        message:
            'Genangan air dilaporkan di beberapa titik jalan utama. Hindari area rawan genangan.',
        severity: FloodRiskLevel.siaga,
        timestamp: DateTime.now().subtract(const Duration(minutes: 25)),
        location: 'Kelurahan Sukamaju, Bandung',
        isActive: true,
      ),
    ];
  }
}
