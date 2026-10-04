import 'package:flutter/material.dart';

enum VolcanoAlertLevel { levelI, levelII, levelIII, levelIV }

extension VolcanoAlertLevelX on VolcanoAlertLevel {
  String get label {
    switch (this) {
      case VolcanoAlertLevel.levelI:
        return 'Level I — Normal';
      case VolcanoAlertLevel.levelII:
        return 'Level II — Waspada';
      case VolcanoAlertLevel.levelIII:
        return 'Level III — Siaga';
      case VolcanoAlertLevel.levelIV:
        return 'Level IV — Awas';
    }
  }

  Color get color {
    switch (this) {
      case VolcanoAlertLevel.levelI:
        return const Color(0xFF4CAF50);
      case VolcanoAlertLevel.levelII:
        return const Color(0xFFFFC107);
      case VolcanoAlertLevel.levelIII:
        return const Color(0xFFFF9800);
      case VolcanoAlertLevel.levelIV:
        return const Color(0xFFF44336);
    }
  }
}

enum VolcanoActivityStatus { normal, increasedActivity, erupting, unknown }

@immutable
class VolcanoModel {
  final String id;
  final String name;
  final String region;
  final double latitude;
  final double longitude;
  final double elevationMeters;
  // Nullable dengan sengaja: `null` berarti status TERKINI memang tidak
  // diketahui app ini (lihat catatan di StaticVolcanoRepository) — bukan
  // di-default ke suatu level supaya tidak terkesan tahu padahal tidak.
  final VolcanoAlertLevel? statusLevel;
  final VolcanoActivityStatus activityStatus;
  final DateTime lastUpdate;
  final String? lastEruption;
  final String source;
  final double? dangerRadiusKm;
  final String? description;

  const VolcanoModel({
    required this.id,
    required this.name,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
    this.statusLevel,
    required this.activityStatus,
    required this.lastUpdate,
    this.lastEruption,
    required this.source,
    this.dangerRadiusKm,
    this.description,
  });
}
