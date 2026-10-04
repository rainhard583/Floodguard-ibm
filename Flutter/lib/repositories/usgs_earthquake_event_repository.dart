import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/earthquake_event_model.dart';
import 'earthquake_event_repository.dart';

/// Direct USGS GeoJSON feed. No Laravel dependency.
/// USGS says its real-time GeoJSON feeds are intended for programmatic use
/// and are updated every minute.
class UsgsEarthquakeEventRepository implements EarthquakeEventRepository {
  static const _url = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';

  final http.Client _client;
  UsgsEarthquakeEventRepository({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<List<EarthquakeEvent>> getRecentEvents() async {
    final response = await _client.get(Uri.parse(_url)).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat gempa global USGS (${response.statusCode})');
    }

    final root = jsonDecode(response.body);
    final features = root is Map && root['features'] is List ? root['features'] as List : const [];
    final result = <EarthquakeEvent>[];

    for (final raw in features) {
      if (raw is! Map) continue;
      final feature = Map<String, dynamic>.from(raw);
      final properties = feature['properties'];
      final geometry = feature['geometry'];
      if (properties is! Map || geometry is! Map || geometry['coordinates'] is! List) continue;
      final p = Map<String, dynamic>.from(properties);
      final c = geometry['coordinates'] as List;
      if (c.length < 3) continue;

      final lat = _num(c[1]);
      final lon = _num(c[0]);
      final depth = _num(c[2]);
      final magnitude = _num(p['mag']);
      final timeMs = p['time'] is num ? (p['time'] as num).toInt() : int.tryParse('${p['time']}');
      final id = feature['id']?.toString();
      if (lat == null || lon == null || depth == null || magnitude == null || timeMs == null || id == null) continue;

      result.add(EarthquakeEvent(
        id: id,
        latitude: lat,
        longitude: lon,
        depthKm: depth,
        magnitude: magnitude,
        place: p['place']?.toString() ?? 'Lokasi tidak diketahui',
        time: DateTime.fromMillisecondsSinceEpoch(timeMs, isUtc: true),
        source: 'USGS',
        url: p['url']?.toString(),
        mmi: _num(p['mmi']),
        felt: p['felt'] is num ? (p['felt'] as num).toInt() : null,
        tsunami: p['tsunami'] == 1,
      ));
    }

    result.sort((a, b) => b.time.compareTo(a.time));
    return result;
  }

  double? _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
}
