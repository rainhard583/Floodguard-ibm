import 'package:flutter/foundation.dart';

@immutable
class WeatherPointReading {
  final String dataset;
  final double value;
  final double? secondaryValue;
  final String unit;
  final String? direction;
  final double? directionDegrees;
  final String? cycle;
  final String? forecastHour;

  const WeatherPointReading({
    required this.dataset,
    required this.value,
    this.secondaryValue,
    required this.unit,
    this.direction,
    this.directionDegrees,
    this.cycle,
    this.forecastHour,
  });

  factory WeatherPointReading.fromJson(Map<String, dynamic> json) {
    return WeatherPointReading(
      dataset: json['dataset'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble() ?? double.nan,
      secondaryValue: (json['secondaryValue'] as num?)?.toDouble(),
      unit: json['unit'] as String? ?? '',
      direction: json['direction'] as String?,
      directionDegrees: (json['directionDegrees'] as num?)?.toDouble(),
      cycle: json['cycle'] as String?,
      forecastHour: json['forecastHour'] as String?,
    );
  }
}
