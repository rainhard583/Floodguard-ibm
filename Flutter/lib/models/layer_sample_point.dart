import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// One real provider sample used by weather/environment map fields.
/// For wind, u/v are the eastward/northward components in km/h.
@immutable
class LayerSamplePoint {
  final LatLng point;
  final double value;
  final double? directionDegrees;
  final double? u;
  final double? v;
  final String? source;
  final DateTime? updatedAt;
  final bool? isForecast;

  const LayerSamplePoint({
    required this.point,
    required this.value,
    this.directionDegrees,
    this.u,
    this.v,
    this.source,
    this.updatedAt,
    this.isForecast,
  });
}
