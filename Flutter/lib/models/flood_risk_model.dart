import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Tingkat risiko banjir. Nama enum sengaja disamakan dengan penamaan
/// warna yang sudah ada di [AppColors] (riskAman/riskWaspada/riskSiaga/
/// riskBahaya) supaya keduanya tetap konsisten satu sama lain:
///
/// aman     -> LOW
/// waspada  -> MODERATE
/// siaga    -> HIGH
/// bahaya   -> CRITICAL
enum FloodRiskLevel { aman, waspada, siaga, bahaya }

extension FloodRiskLevelX on FloodRiskLevel {
  String get label {
    switch (this) {
      case FloodRiskLevel.aman:
        return 'AMAN';
      case FloodRiskLevel.waspada:
        return 'WASPADA';
      case FloodRiskLevel.siaga:
        return 'SIAGA';
      case FloodRiskLevel.bahaya:
        return 'BAHAYA';
    }
  }

  Color get color {
    switch (this) {
      case FloodRiskLevel.aman:
        return AppColors.riskAman;
      case FloodRiskLevel.waspada:
        return AppColors.riskWaspada;
      case FloodRiskLevel.siaga:
        return AppColors.riskSiaga;
      case FloodRiskLevel.bahaya:
        return AppColors.riskBahaya;
    }
  }

  IconData get icon {
    switch (this) {
      case FloodRiskLevel.aman:
        return Icons.check_circle_rounded;
      case FloodRiskLevel.waspada:
        return Icons.info_rounded;
      case FloodRiskLevel.siaga:
        return Icons.warning_rounded;
      case FloodRiskLevel.bahaya:
        return Icons.dangerous_rounded;
    }
  }
}

/// Model tingkat risiko banjir untuk lokasi pengguna saat ini.
///
/// CATATAN: mesin/algoritma penghitung risiko banjir belum ada — model ini
/// hanya wadah data. Sumber datanya untuk sekarang adalah
/// [MockFloodRiskRepository] (lihat repositories/mock_flood_risk_repository.dart),
/// nanti digantikan implementasi asli (RealFloodRiskRepository) di fase lain
/// tanpa HomeScreen/FloodRiskCard perlu ditulis ulang.
@immutable
class FloodRisk {
  final FloodRiskLevel level;
  final int score; // 0-100
  final String description;
  final DateTime updatedAt;

  const FloodRisk({
    required this.level,
    required this.score,
    required this.description,
    required this.updatedAt,
  });
}
