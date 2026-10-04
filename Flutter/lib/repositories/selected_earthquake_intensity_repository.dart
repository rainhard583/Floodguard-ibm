import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../core/utils/geo.dart';
import '../models/selected_earthquake_intensity.dart';
import '../core/config/api_config.dart';

/// Resolves earthquake intensity for a user-selected point.
///
/// Japan: uses the official JMA Bosai earthquake feed. JMA publishes
/// seismic intensity by affected area/city for domestic earthquakes.
/// Other countries: uses USGS global events and the event's ShakeMap MMI
/// when available. We never turn an event-wide maximum MMI into a fake
/// point measurement.
class SelectedEarthquakeIntensityRepository {
  Future<SelectedEarthquakeIntensity?> getForLocation({
    required double latitude,
    required double longitude,
    String? displayName,
  }) async {
    final uri = Uri.parse(ApiConfig.earthquakeLocationUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      if (displayName != null && displayName.trim().isNotEmpty) 'display_name': displayName.trim(),
    });
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;
    final root = jsonDecode(response.body);
    if (root is! Map || root['result'] is! Map) return null;
    final result = Map<String, dynamic>.from(root['result'] as Map);
    if (result['found'] != true || result['event'] is! Map) return null;
    final e = Map<String, dynamic>.from(result['event'] as Map);
    final eventTime = DateTime.tryParse(e['time']?.toString() ?? '');
    return SelectedEarthquakeIntensity(
      source: result['source']?.toString() ?? 'Earthquake source',
      eventId: e['id']?.toString(),
      magnitude: (e['magnitude'] as num?)?.toDouble(),
      place: e['place']?.toString(),
      depthKm: (e['depth_km'] as num?)?.toDouble(),
      eventTime: eventTime,
      intensity: (e['intensity'] as num?)?.toDouble(),
      intensityScale: e['intensity_scale']?.toString() ?? 'MMI',
      intensityScope: e['intensity_scope']?.toString(),
      distanceKm: (e['distance_km'] as num?)?.toDouble(),
      updatedAt: DateTime.now(),
      exactLocation: e['exact_location'] == true,
      note: e['note']?.toString() ?? '',
    );
  }
}
