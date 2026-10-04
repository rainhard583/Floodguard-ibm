import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// Skala Likert 5-tingkat, dipakai bersama oleh risiko gempa bumi dan
/// tsunami di Peta (lihat [earthquake_risk_model.dart] &
/// [tsunami_risk_model.dart]) supaya keduanya tampil dengan bahasa visual
/// yang sama alih-alih dua skema warna/level yang berbeda-beda.
enum DisasterRiskLevel { sangatRendah, rendah, sedang, tinggi, sangatTinggi }

extension DisasterRiskLevelX on DisasterRiskLevel {
  String get label {
    switch (this) {
      case DisasterRiskLevel.sangatRendah:
        return 'Sangat Rendah';
      case DisasterRiskLevel.rendah:
        return 'Rendah';
      case DisasterRiskLevel.sedang:
        return 'Sedang';
      case DisasterRiskLevel.tinggi:
        return 'Tinggi';
      case DisasterRiskLevel.sangatTinggi:
        return 'Sangat Tinggi';
    }
  }

  /// Posisi 1-5 di skala Likert (dipakai untuk mengisi bar segmen).
  int get step {
    switch (this) {
      case DisasterRiskLevel.sangatRendah:
        return 1;
      case DisasterRiskLevel.rendah:
        return 2;
      case DisasterRiskLevel.sedang:
        return 3;
      case DisasterRiskLevel.tinggi:
        return 4;
      case DisasterRiskLevel.sangatTinggi:
        return 5;
    }
  }

  Color get color {
    switch (this) {
      case DisasterRiskLevel.sangatRendah:
        return AppColors.scaleLevel1;
      case DisasterRiskLevel.rendah:
        return AppColors.scaleLevel2;
      case DisasterRiskLevel.sedang:
        return AppColors.scaleLevel3;
      case DisasterRiskLevel.tinggi:
        return AppColors.scaleLevel4;
      case DisasterRiskLevel.sangatTinggi:
        return AppColors.scaleLevel5;
    }
  }
}
