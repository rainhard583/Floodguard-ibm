import 'package:flutter/material.dart';

/// Kategori AQI (skala AQI Eropa, dipakai Open-Meteo Air Quality API).
enum AqiCategory { good, fair, moderate, poor, veryPoor, extremelyPoor }

extension AqiCategoryX on AqiCategory {
  String get label {
    switch (this) {
      case AqiCategory.good:
        return 'Baik';
      case AqiCategory.fair:
        return 'Cukup Baik';
      case AqiCategory.moderate:
        return 'Sedang';
      case AqiCategory.poor:
        return 'Tidak Sehat';
      case AqiCategory.veryPoor:
        return 'Sangat Tidak Sehat';
      case AqiCategory.extremelyPoor:
        return 'Berbahaya';
    }
  }

  Color get color {
    switch (this) {
      case AqiCategory.good:
        return const Color(0xFF4CAF50);
      case AqiCategory.fair:
        return const Color(0xFF8BC34A);
      case AqiCategory.moderate:
        return const Color(0xFFFFC107);
      case AqiCategory.poor:
        return const Color(0xFFFF9800);
      case AqiCategory.veryPoor:
        return const Color(0xFFF44336);
      case AqiCategory.extremelyPoor:
        return const Color(0xFF880E4F);
    }
  }

  static AqiCategory fromEuropeanAqi(int aqi) {
    if (aqi <= 20) return AqiCategory.good;
    if (aqi <= 40) return AqiCategory.fair;
    if (aqi <= 60) return AqiCategory.moderate;
    if (aqi <= 80) return AqiCategory.poor;
    if (aqi <= 100) return AqiCategory.veryPoor;
    return AqiCategory.extremelyPoor;
  }
}

/// Satu polutan dengan nilai + satuan — dipakai supaya UI selalu bisa
/// menampilkan "18.4 µg/m³ — Source: CAMS/Open-Meteo", bukan angka telanjang.
@immutable
class PollutantReading {
  final double value;
  final String unit;

  const PollutantReading({required this.value, required this.unit});
}

/// Data kualitas udara untuk 1 titik koordinat. SELALU dari model CAMS
/// (Copernicus Atmosphere Monitoring Service) lewat Open-Meteo — bukan
/// sensor lokal FloodGuard sendiri, karena itu field [source] &
/// [isForecast] wajib ditampilkan UI, tidak boleh diklaim "sensor kami".
@immutable
class AirQuality {
  final int europeanAqi;
  final AqiCategory category;
  final PollutantReading pm25;
  final PollutantReading pm10;
  final PollutantReading so2;
  final PollutantReading no2;
  final PollutantReading co;
  final PollutantReading ozone;
  final PollutantReading? dust;
  final String source;
  final bool isForecast;
  final DateTime updatedAt;

  const AirQuality({
    required this.europeanAqi,
    required this.category,
    required this.pm25,
    required this.pm10,
    required this.so2,
    required this.no2,
    required this.co,
    required this.ozone,
    this.dust,
    required this.source,
    required this.isForecast,
    required this.updatedAt,
  });
}
