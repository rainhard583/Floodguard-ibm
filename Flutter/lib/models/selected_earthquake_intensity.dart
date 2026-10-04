import 'package:flutter/foundation.dart';

@immutable
class SelectedEarthquakeIntensity {
  final String source;
  final String? eventId;
  final double? magnitude;
  final String? place;
  final double? depthKm;
  final DateTime? eventTime;
  final double? intensity;
  final String intensityScale;
  final String? intensityScope;
  final double? distanceKm;
  final DateTime updatedAt;
  final bool exactLocation;
  final String note;

  const SelectedEarthquakeIntensity({
    required this.source,
    this.eventId,
    this.magnitude,
    this.place,
    this.depthKm,
    this.eventTime,
    this.intensity,
    this.intensityScale = 'MMI',
    this.intensityScope,
    this.distanceKm,
    required this.updatedAt,
    required this.exactLocation,
    this.note = '',
  });

  String get magnitudeText => magnitude == null ? '—' : 'M${magnitude!.toStringAsFixed(1)}';
  String get intensityText => intensity == null ? 'Belum tersedia' : '${intensity!.toStringAsFixed(intensity!.truncateToDouble() == intensity ? 0 : 1)} $intensityScale';
}
