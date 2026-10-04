import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_alert_model.dart';
import '../repositories/flood_alert_repository.dart';
import '../repositories/mock_flood_alert_repository.dart';

/// Instance [FloodAlertRepository] untuk seluruh app.
///
/// Ganti `MockFloodAlertRepository()` menjadi `RealFloodAlertRepository(...)`
/// begitu sumber data resmi & push notification sungguhan sudah ada
/// (Phase 12) — tidak ada widget yang perlu ditulis ulang.
final floodAlertRepositoryProvider = Provider<FloodAlertRepository>((ref) {
  return MockFloodAlertRepository();
});

/// Daftar peringatan banjir aktif untuk lokasi pengguna saat ini. List
/// kosong berarti memang tidak ada alert aktif (state "empty" yang legit).
final floodAlertProvider = FutureProvider.autoDispose<List<FloodAlert>>((ref) {
  return ref.watch(floodAlertRepositoryProvider).getActiveAlerts();
});
