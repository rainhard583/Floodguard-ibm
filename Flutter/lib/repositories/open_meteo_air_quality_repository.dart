import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/air_quality_model.dart';
import '../models/layer_sample_point.dart';
import '../models/map_layer_type.dart';
import 'air_quality_repository.dart';

/// Implementasi NYATA — Open-Meteo Air Quality API
/// (air-quality-api.open-meteo.com), sumber data Copernicus Atmosphere
/// Monitoring Service (CAMS). Gratis, tanpa API key. Ini data MODEL/
/// FORECAST (bukan sensor FloodGuard sendiri) — karena itu [AirQuality]
/// selalu membawa `source` & `isForecast` supaya UI tidak pernah
/// mengklaimnya sebagai pengukuran lokal.
class OpenMeteoAirQualityRepository implements AirQualityRepository {
  static const _baseUrl = 'https://air-quality-api.open-meteo.com/v1/air-quality';

  static const Map<WeatherLayerType, String> _fieldForLayer = {
    WeatherLayerType.airQuality: 'european_aqi',
    WeatherLayerType.pm25: 'pm2_5',
    WeatherLayerType.pm10: 'pm10',
    WeatherLayerType.so2: 'sulphur_dioxide',
    WeatherLayerType.no2: 'nitrogen_dioxide',
    WeatherLayerType.co: 'carbon_monoxide',
    WeatherLayerType.ozone: 'ozone',
  };

  @override
  Future<List<LayerSamplePoint>> getGridSamples({
    required WeatherLayerType layer,
    required List<LatLng> points,
  }) async {
    final field = _fieldForLayer[layer];
    if (field == null || points.isEmpty) return const [];

    const batchSize = 50;
    final batches = <List<LatLng>>[];
    for (var start = 0; start < points.length; start += batchSize) {
      final end = math.min(start + batchSize, points.length);
      batches.add(points.sublist(start, end));
    }
    // A few concurrent requests reduce layer-switch latency without
    // flooding the API or the phone with dozens of sockets.
    final chunks = <List<List<LatLng>>>[];
    for (var i = 0; i < batches.length; i += 3) {
      chunks.add(batches.sublist(i, math.min(i + 3, batches.length)));
    }
    final results = <LayerSamplePoint>[];
    for (final chunk in chunks) {
      final partial = await Future.wait(chunk.map((batch) => _getGridBatch(field, batch)));
      for (final list in partial) {
        results.addAll(list);
      }
    }
    return results;
  }

  Future<List<LayerSamplePoint>> _getGridBatch(
    String field,
    List<LatLng> points,
  ) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': points.map((p) => p.latitude.toStringAsFixed(4)).join(','),
      'longitude': points.map((p) => p.longitude.toStringAsFixed(4)).join(','),
      'current': field,
      'timezone': 'GMT',
      // Explicitly request the global CAMS domain for worldwide coverage.
      'domains': 'cams_global',
    });

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');
        final decoded = jsonDecode(response.body);
        final list = decoded is List ? decoded : [decoded];
        final samples = <LayerSamplePoint>[];
        for (var i = 0; i < list.length && i < points.length; i++) {
          final current = (list[i] as Map<String, dynamic>)['current'] as Map<String, dynamic>?;
          final value = (current?[field] as num?)?.toDouble();
          if (value == null) continue;
          samples.add(LayerSamplePoint(
            point: points[i],
            value: value,
            source: 'CAMS / Open-Meteo',
            updatedAt: DateTime.tryParse((current?['time'] as String?) ?? ''),
            isForecast: true,
          ));
        }
        return samples;
      } catch (error) {
        lastError = error;
        if (attempt < 2) {
          await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
        }
      }
    }
    throw Exception('Gagal memuat data kualitas udara: $lastError');
  }

  @override
  Future<AirQuality?> getAirQualityForLocation({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current':
          'european_aqi,pm2_5,pm10,sulphur_dioxide,nitrogen_dioxide,carbon_monoxide,ozone,dust',
      'timezone': 'auto',
      // FloodGuard covers Indonesia/global locations. Use the global CAMS
      // composition domain so point values are consistent with the map grid.
      'domains': 'cams_global',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data kualitas udara (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    final aqi = (current['european_aqi'] as num?)?.toInt() ?? 0;
    final updatedAt = DateTime.tryParse(current['time'] as String? ?? '') ?? DateTime.now();

    return AirQuality(
      europeanAqi: aqi,
      category: AqiCategoryX.fromEuropeanAqi(aqi),
      pm25: PollutantReading(value: (current['pm2_5'] as num?)?.toDouble() ?? 0, unit: 'µg/m³'),
      pm10: PollutantReading(value: (current['pm10'] as num?)?.toDouble() ?? 0, unit: 'µg/m³'),
      so2: PollutantReading(value: (current['sulphur_dioxide'] as num?)?.toDouble() ?? 0, unit: 'µg/m³'),
      no2: PollutantReading(value: (current['nitrogen_dioxide'] as num?)?.toDouble() ?? 0, unit: 'µg/m³'),
      co: PollutantReading(value: (current['carbon_monoxide'] as num?)?.toDouble() ?? 0, unit: 'µg/m³'),
      ozone: PollutantReading(value: (current['ozone'] as num?)?.toDouble() ?? 0, unit: 'µg/m³'),
      dust: current['dust'] != null
          ? PollutantReading(value: (current['dust'] as num).toDouble(), unit: 'µg/m³')
          : null,
      source: 'CAMS / Open-Meteo',
      isForecast: true,
      updatedAt: updatedAt,
    );
  }
}
