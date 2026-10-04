import 'package:flutter/foundation.dart';

@immutable
class TsunamiWarningEvent {
  final String id;
  final double latitude;
  final double longitude;
  final double magnitude;
  final double depthKm;
  final String region;
  final String potential;
  final DateTime time;

  const TsunamiWarningEvent({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.magnitude,
    required this.depthKm,
    required this.region,
    required this.potential,
    required this.time,
  });

  bool get hasTsunamiPotential =>
      potential.toLowerCase().contains('berpotensi tsunami');
}
