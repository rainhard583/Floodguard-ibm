import 'package:flutter/foundation.dart';
import 'flood_risk_model.dart';

/// Model satu peringatan banjir aktif untuk lokasi pengguna.
///
/// Severity memakai [FloodRiskLevel] yang sama dengan kartu risiko banjir
/// supaya warna & label tetap konsisten di seluruh app (tidak ada skema
/// warna kedua untuk hal yang secara konsep sama).
///
/// CATATAN: ini BUKAN push notification sungguhan — hanya representasi
/// data alert yang untuk sekarang berasal dari [MockFloodAlertRepository].
/// Integrasi notifikasi asli & sumber data resmi (BMKG/BPBD/dll) adalah
/// pekerjaan Phase 12.
@immutable
class FloodAlert {
  final String id;
  final String title;
  final String message;
  final FloodRiskLevel severity;
  final DateTime timestamp;
  final String location;
  final bool isActive;

  const FloodAlert({
    required this.id,
    required this.title,
    required this.message,
    required this.severity,
    required this.timestamp,
    required this.location,
    this.isActive = true,
  });
}
