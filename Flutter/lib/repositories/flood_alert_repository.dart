import '../models/flood_alert_model.dart';

/// Kontrak sumber data peringatan banjir aktif.
///
/// Push notification sungguhan & sumber data resmi (BMKG/BPBD API) adalah
/// pekerjaan Phase 12. Untuk sekarang HomeScreen hanya membaca lewat
/// abstraksi ini melalui [FloodAlertProvider].
abstract class FloodAlertRepository {
  Future<List<FloodAlert>> getActiveAlerts();
}
