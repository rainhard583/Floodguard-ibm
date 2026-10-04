import 'package:flutter/foundation.dart';

@immutable
class BmkgLatestEarthquake {
  final String? date;
  final String? time;
  final double magnitude;
  final String? depth;
  final String? coordinates;
  final String? region;
  final String? potential;
  final String? felt;
  final DateTime eventTime;
  final double? latitude;
  final double? longitude;

  const BmkgLatestEarthquake({
    this.date,
    this.time,
    required this.magnitude,
    this.depth,
    this.coordinates,
    this.region,
    this.potential,
    this.felt,
    required this.eventTime,
    this.latitude,
    this.longitude,
  });

  factory BmkgLatestEarthquake.fromBmkgMap(
    Map<String, dynamic> data, {
    required double magnitude,
  }) {
    final eventTime = _parseBmkgEventTime(data) ??
        _parseDateTime(
          data['Tanggal']?.toString(),
          data['Jam']?.toString(),
        ) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final coords = _parseCoordinates(data['Coordinates']?.toString());

    return BmkgLatestEarthquake(
      date: data['Tanggal']?.toString(),
      time: data['Jam']?.toString(),
      magnitude: magnitude,
      depth: data['Kedalaman']?.toString(),
      coordinates: data['Coordinates']?.toString(),
      region: data['Wilayah']?.toString(),
      potential: data['Potensi']?.toString(),
      felt: data['Dirasakan']?.toString(),
      eventTime: eventTime,
      latitude: coords?.$1,
      longitude: coords?.$2,
    );
  }

  String get displayMagnitude => 'M${magnitude.toStringAsFixed(1)} SR';

  String get displayDateTime {
    final d = (date ?? '').trim();
    final t = (time ?? '').trim();
    if (d.isEmpty) return t;
    if (t.isEmpty) return d;
    return '$d • $t';
  }

  String get eventId {
    final c = coordinates ?? '';
    return '${eventTime.toUtc().toIso8601String()}|$magnitude|$c';
  }


  static DateTime? _parseBmkgEventTime(Map<String, dynamic> data) {
    final raw = data['DateTime']?.toString().trim();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.toLocal();
  }

  static DateTime? _parseDateTime(String? date, String? time) {
    if (date == null || time == null) return null;
    final d = RegExp(r'(\d{2})-(\d{2})-(\d{4})').firstMatch(date);
    final t = RegExp(r'(\d{2}):(\d{2}):(\d{2})').firstMatch(time);
    if (d == null || t == null) return null;
    return DateTime.tryParse(
      '${d.group(3)}-${d.group(2)}-${d.group(1)}T${t.group(1)}:${t.group(2)}:${t.group(3)}+07:00',
    )?.toLocal();
  }

  static (double, double)? _parseCoordinates(String? value) {
    if (value == null) return null;
    final parts = value.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lon = double.tryParse(parts[1].trim());
    if (lat == null || lon == null) return null;
    return (lat, lon);
  }
}
