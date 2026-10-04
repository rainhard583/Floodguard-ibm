import 'package:flutter/foundation.dart';

@immutable
class EarthquakeEvent {
  final String id;
  final double latitude;
  final double longitude;
  final double depthKm;
  final double magnitude;
  final String place;
  final DateTime time;
  final String source;
  final String? url;
  final double? mmi;
  final int? felt;
  final bool? tsunami;

  const EarthquakeEvent({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.depthKm,
    required this.magnitude,
    required this.place,
    required this.time,
    required this.source,
    this.url,
    this.mmi,
    this.felt,
    this.tsunami,
  });
}
