import 'package:flutter/material.dart';

/// Kondisi cuaca yang disederhanakan. Cukup untuk kebutuhan ikon & label
/// di UI; mapping dari kode/kondisi mentah API cuaca asli akan dilakukan
/// di RealWeatherService pada fase berikutnya.
enum WeatherCondition { cerah, berawan, hujanRingan, hujanLebat, badai }

extension WeatherConditionX on WeatherCondition {
  String get label {
    switch (this) {
      case WeatherCondition.cerah:
        return 'Cerah';
      case WeatherCondition.berawan:
        return 'Berawan';
      case WeatherCondition.hujanRingan:
        return 'Hujan Ringan';
      case WeatherCondition.hujanLebat:
        return 'Hujan Lebat';
      case WeatherCondition.badai:
        return 'Badai';
    }
  }

  IconData get icon {
    switch (this) {
      case WeatherCondition.cerah:
        return Icons.wb_sunny_rounded;
      case WeatherCondition.berawan:
        return Icons.cloud_rounded;
      case WeatherCondition.hujanRingan:
        return Icons.grain_rounded;
      case WeatherCondition.hujanLebat:
        return Icons.water_drop_rounded;
      case WeatherCondition.badai:
        return Icons.thunderstorm_rounded;
    }
  }
}

/// Satu titik pratinjau prakiraan (misal per beberapa jam ke depan).
@immutable
class WeatherForecastItem {
  final String label; // contoh: "15.00", "Besok"
  final WeatherCondition condition;
  final double temperatureCelsius;
  final bool isDay;
  final double precipitationMm;
  final double? chanceOfRainPercent;
  final double? humidityPercent;
  final double? windKph;
  final DateTime? forecastTime;

  const WeatherForecastItem({
    required this.label,
    required this.condition,
    required this.temperatureCelsius,
    this.isDay = true,
    this.precipitationMm = 0,
    this.chanceOfRainPercent,
    this.humidityPercent,
    this.windKph,
    this.forecastTime,
  });
}

/// Dari mana [Weather] ini berasal — WAJIB ditampilkan UI (mis. "ECMWF
/// forecast" vs "Weather station observation") supaya tidak mengklaim
/// data model sebagai observasi langsung.
enum WeatherObservationType { observation, forecastModel }

/// Model ringkasan cuaca untuk lokasi pengguna saat ini.
///
/// Sumber utama kondisi saat ini adalah WeatherAPI; Open-Meteo dipakai untuk map/grid dan fallback.
/// Field baru (windDirection dst.) OPSIONAL dengan default aman supaya
/// kode lama (HomeScreen/WeatherSummaryCard) yang belum pakai field ini
/// tetap compile tanpa perubahan.
@immutable
class Weather {
  final double temperatureCelsius;
  /// Optional current-hour model value supplied when the station observation
  /// is stale. The app keeps the measured observation as the primary value.
  final double? currentHourModelTemperatureCelsius;
  /// Suhu yang terasa menurut provider cuaca (bukan suhu udara aktual).
  final double? feelsLikeCelsius;
  final WeatherCondition condition;
  /// True when the observation/forecast hour is daytime.
  /// Used so a clear night is rendered with a moon icon instead of a sun.
  final bool isDay;
  final double rainfallMm;
  final double humidityPercent;
  final double windKph;
  final DateTime updatedAt;
  final List<WeatherForecastItem> forecast;

  // --- Field baru untuk Map Weather Layers (semua REAL, dari Open-Meteo) ---
  final double? windDirectionDeg;
  final double? windGustKph;
  final double? pressureHpa;
  final double? cloudCoverPercent;
  final double? uvIndex;
  final double? visibilityKm;
  final double? dewPointCelsius;
  final String source;
  final WeatherObservationType observationType;

  const Weather({
    required this.temperatureCelsius,
    this.currentHourModelTemperatureCelsius,
    this.feelsLikeCelsius,
    required this.condition,
    this.isDay = true,
    required this.rainfallMm,
    required this.humidityPercent,
    required this.windKph,
    required this.updatedAt,
    this.forecast = const [],
    this.windDirectionDeg,
    this.windGustKph,
    this.pressureHpa,
    this.cloudCoverPercent,
    this.uvIndex,
    this.visibilityKm,
    this.dewPointCelsius,
    this.source = 'Open-Meteo',
    this.observationType = WeatherObservationType.forecastModel,
  });
}
