import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// Global location + realtime/near-realtime public feeds used by FloodGuard.
/// This service is intentionally independent from Laravel for public feeds.
/// AI analysis itself remains backend-only so API secrets never enter the APK.
class GlobalRealtimeService {
  static const geocodeUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const weatherUrl = 'https://api.open-meteo.com/v1/forecast';
  static const usgsUrl = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';
  static const gdacsUrl = 'https://www.gdacs.org/gdacsapi/api/Events/geteventlist/SEARCH';

  final http.Client _client;
  GlobalRealtimeService({http.Client? client}) : _client = client ?? http.Client();

  Future<GlobalLocation?> resolveLocation(String query) async {
    final q = query.trim();
    if (q.isEmpty) return null;
    final uri = Uri.parse(geocodeUrl).replace(queryParameters: {
      'name': q,
      'count': '5',
      'language': 'en',
      'format': 'json',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final root = jsonDecode(response.body);
    final results = root is Map && root['results'] is List ? root['results'] as List : const [];
    if (results.isEmpty || results.first is! Map) return null;
    final r = Map<String, dynamic>.from(results.first as Map);
    final lat = _num(r['latitude']);
    final lon = _num(r['longitude']);
    if (lat == null || lon == null) return null;
    return GlobalLocation(
      name: r['name']?.toString() ?? q,
      country: r['country']?.toString(),
      countryCode: r['country_code']?.toString(),
      latitude: lat,
      longitude: lon,
      timezone: r['timezone']?.toString(),
    );
  }

  Future<GlobalWeatherSnapshot?> getWeather(double latitude, double longitude) async {
    final uri = Uri.parse(weatherUrl).replace(queryParameters: {
      'latitude': '$latitude',
      'longitude': '$longitude',
      'current': 'temperature_2m,relative_humidity_2m,precipitation,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,cloud_cover,visibility,dew_point_2m',
      'hourly': 'temperature_2m,precipitation,weather_code,wind_speed_10m,relative_humidity_2m',
      'forecast_days': '3',
      'timezone': 'auto',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;
    final root = jsonDecode(response.body);
    if (root is! Map) return null;
    final current = root['current'];
    if (current is! Map) return null;
    return GlobalWeatherSnapshot(
      latitude: latitude,
      longitude: longitude,
      timezone: root['timezone']?.toString(),
      current: Map<String, dynamic>.from(current),
      hourly: root['hourly'] is Map ? Map<String, dynamic>.from(root['hourly'] as Map) : null,
      fetchedAt: DateTime.now(),
    );
  }

  Future<List<GlobalEarthquake>> getEarthquakes({double? latitude, double? longitude, double radiusKm = 500}) async {
    Uri uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse('https://earthquake.usgs.gov/fdsnws/event/1/query').replace(queryParameters: {
        'format': 'geojson',
        'starttime': DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String(),
        'endtime': DateTime.now().toUtc().toIso8601String(),
        'latitude': '$latitude',
        'longitude': '$longitude',
        'maxradiuskm': '$radiusKm',
        'orderby': 'time',
        'limit': '200',
      });
    } else {
      uri = Uri.parse(usgsUrl);
    }
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return const [];
    final root = jsonDecode(response.body);
    final features = root is Map && root['features'] is List ? root['features'] as List : const [];
    return features.whereType<Map>().map((f) {
      final p = f['properties'];
      final g = f['geometry'];
      if (p is! Map || g is! Map || g['coordinates'] is! List) return null;
      final c = g['coordinates'] as List;
      if (c.length < 3) return null;
      return GlobalEarthquake(
        id: f['id']?.toString() ?? '',
        place: p['place']?.toString() ?? 'Unknown',
        magnitude: _num(p['mag']),
        depthKm: _num(c[2]),
        latitude: _num(c[1]),
        longitude: _num(c[0]),
        time: _epochToDate(p['time']),
        tsunami: p['tsunami'] == 1,
      );
    }).whereType<GlobalEarthquake>().toList();
  }

  Future<List<Map<String, dynamic>>> getGdacsEvents({double? latitude, double? longitude}) async {
    final uri = Uri.parse(gdacsUrl).replace(queryParameters: {
      'eventlist': 'EQ;TC;FL;WF',
      'fromdate': DateTime.now().toUtc().subtract(const Duration(days: 2)).toIso8601String().substring(0, 10),
      'todate': DateTime.now().toUtc().toIso8601String().substring(0, 10),
      'alertlevel': 'red;orange;green',
    });
    try {
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];
      final root = jsonDecode(response.body);
      final features = root is Map && root['features'] is List ? root['features'] as List : const [];
      return features.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  double? _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
  DateTime? _epochToDate(dynamic value) => value is num ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true) : null;

  double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  void dispose() => _client.close();
}

class GlobalLocation {
  final String name;
  final String? country;
  final String? countryCode;
  final double latitude;
  final double longitude;
  final String? timezone;
  const GlobalLocation({required this.name, this.country, this.countryCode, required this.latitude, required this.longitude, this.timezone});
}

class GlobalWeatherSnapshot {
  final double latitude;
  final double longitude;
  final String? timezone;
  final Map<String, dynamic> current;
  final Map<String, dynamic>? hourly;
  final DateTime fetchedAt;
  const GlobalWeatherSnapshot({required this.latitude, required this.longitude, this.timezone, required this.current, this.hourly, required this.fetchedAt});
}

class GlobalEarthquake {
  final String id;
  final String place;
  final double? magnitude;
  final double? depthKm;
  final double? latitude;
  final double? longitude;
  final DateTime? time;
  final bool tsunami;
  const GlobalEarthquake({required this.id, required this.place, this.magnitude, this.depthKm, this.latitude, this.longitude, this.time, required this.tsunami});
}
