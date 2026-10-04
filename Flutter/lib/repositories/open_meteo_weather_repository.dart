import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/layer_sample_point.dart';
import '../models/map_layer_type.dart';
import '../models/weather_model.dart';
import 'weather_repository.dart';

/// Implementasi NYATA — memanggil Open-Meteo Forecast API
/// (api.open-meteo.com), gratis untuk pemakaian non-komersial, TANPA API
/// key. Menggantikan [MockWeatherRepository] yang sebelumnya menampilkan
/// angka acak/deterministik-palsu (bukan cuaca sungguhan).
class OpenMeteoWeatherRepository implements WeatherRepository {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Field Open-Meteo yang dipakai tiap [WeatherLayerType] untuk overlay
  /// grid — 1 tempat pemetaan, dipakai juga saat parsing respons batch.
  static const Map<WeatherLayerType, String> _fieldForLayer = {
    WeatherLayerType.wind: 'wind_speed_10m',
    WeatherLayerType.windGust: 'wind_gusts_10m',
    WeatherLayerType.rain: 'precipitation',
    WeatherLayerType.temperature: 'temperature_2m',
    WeatherLayerType.dewPoint: 'dew_point_2m',
    WeatherLayerType.humidity: 'relative_humidity_2m',
    WeatherLayerType.pressure: 'surface_pressure',
    WeatherLayerType.cloudCover: 'cloud_cover',
    WeatherLayerType.uvIndex: 'uv_index',
    WeatherLayerType.visibility: 'visibility',
  };

  @override
  Future<Weather?> getCurrentWeather() {
    // Tidak ada koordinat "saat ini" tanpa lokasi. Dalam alur app ini,
    // weatherProvider SELALU memanggil getWeatherForLocation begitu
    // koordinat lokasi (GPS/manual) diketahui, jadi method ini praktis
    // tidak pernah terpakai — fallback ke Jakarta sekadar jaga-jaga.
    return getWeatherForLocation(latitude: -6.2088, longitude: 106.8456);
  }

  @override
  Future<List<LayerSamplePoint>> getGridSamples({
    required WeatherLayerType layer,
    required List<LatLng> points,
  }) async {
    final field = _fieldForLayer[layer];
    if (field == null || points.isEmpty) return const [];

    // Keep each URL small and isolate transient failures. Open-Meteo accepts
    // multiple coordinates in one request, but a mobile map can easily create
    // hundreds of coordinates after zooming in. Small batches are much more
    // reliable than one very long URL and still avoid one-request-per-point.
    const batchSize = 50;
    final batches = <List<LatLng>>[];
    for (var start = 0; start < points.length; start += batchSize) {
      final end = math.min(start + batchSize, points.length);
      batches.add(points.sublist(start, end));
    }
    final chunks = <List<List<LatLng>>>[];
    for (var i = 0; i < batches.length; i += 3) {
      chunks.add(batches.sublist(i, math.min(i + 3, batches.length)));
    }
    final results = <LayerSamplePoint>[];
    for (final chunk in chunks) {
      final partial = await Future.wait(chunk.map((batch) => _getGridBatch(layer, field, batch)));
      for (final list in partial) {
        results.addAll(list);
      }
    }
    return results;
  }

  Future<List<LayerSamplePoint>> _getGridBatch(
    WeatherLayerType layer,
    String field,
    List<LatLng> points,
  ) async {
    final currentFields = (layer == WeatherLayerType.wind || layer == WeatherLayerType.windGust)
        ? 'wind_speed_10m,wind_direction_10m,wind_gusts_10m'
        : field;
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': points.map((p) => p.latitude.toStringAsFixed(4)).join(','),
      'longitude': points.map((p) => p.longitude.toStringAsFixed(4)).join(','),
      'current': currentFields,
      'timezone': 'GMT',
    });

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw Exception('HTTP ${response.statusCode}');
        }
        final decoded = jsonDecode(response.body);
        final list = decoded is List ? decoded : [decoded];
        final samples = <LayerSamplePoint>[];
        for (var i = 0; i < list.length && i < points.length; i++) {
          final current = (list[i] as Map<String, dynamic>)['current'] as Map<String, dynamic>?;
          if (current == null) continue;
          final valueField = layer == WeatherLayerType.windGust ? 'wind_gusts_10m' : field;
          final value = (current[valueField] as num?)?.toDouble();
          if (value == null) continue;

          final direction = (current['wind_direction_10m'] as num?)?.toDouble();
          double? u;
          double? v;
          if (direction != null &&
              (layer == WeatherLayerType.wind || layer == WeatherLayerType.windGust)) {
            final radians = direction * math.pi / 180.0;
            final speed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 0.0;
            u = -speed * math.sin(radians);
            v = -speed * math.cos(radians);
          }
          samples.add(LayerSamplePoint(
            point: points[i],
            value: value,
            directionDegrees: direction,
            u: u,
            v: v,
            source: 'Open-Meteo',
            updatedAt: DateTime.tryParse((current['time'] as String?) ?? ''),
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
    throw Exception('Gagal memuat data cuaca: $lastError');
  }

  @override
  Future<Weather?> getWeatherForLocation({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'current': 'temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,'
          'wind_direction_10m,wind_gusts_10m,weather_code,surface_pressure,'
          'cloud_cover,uv_index,visibility,dew_point_2m',
      'hourly': 'temperature_2m,weather_code,precipitation',
      'timezone': 'auto',
      'forecast_days': '2',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data cuaca (${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) return null;

    final currentTime = DateTime.tryParse(current['time'] as String? ?? '') ?? DateTime.now();

    return Weather(
      temperatureCelsius: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      feelsLikeCelsius: null,
      condition: _mapWeatherCode(current['weather_code'] as num?),
      // Open-Meteo current payload does not need a guessed icon: derive day/night
      // from the returned local observation timestamp for fallback rendering.
      isDay: _isDayFromLocalTime(currentTime),
      rainfallMm: (current['precipitation'] as num?)?.toDouble() ?? 0,
      humidityPercent: (current['relative_humidity_2m'] as num?)?.toDouble() ?? 0,
      windKph: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      updatedAt: currentTime,
      forecast: _buildForecast(json['hourly'] as Map<String, dynamic>?, currentTime),
      windDirectionDeg: (current['wind_direction_10m'] as num?)?.toDouble(),
      windGustKph: (current['wind_gusts_10m'] as num?)?.toDouble(),
      pressureHpa: (current['surface_pressure'] as num?)?.toDouble(),
      cloudCoverPercent: (current['cloud_cover'] as num?)?.toDouble(),
      uvIndex: (current['uv_index'] as num?)?.toDouble(),
      // API mengembalikan visibility dalam meter -> dikonversi ke km.
      visibilityKm: (current['visibility'] as num?) != null
          ? (current['visibility'] as num).toDouble() / 1000
          : null,
      dewPointCelsius: (current['dew_point_2m'] as num?)?.toDouble(),
      source: 'Open-Meteo',
      observationType: WeatherObservationType.forecastModel,
    );
  }

  bool _isDayFromLocalTime(DateTime time) {
    final hour = time.hour + (time.minute / 60.0);
    return hour >= 6.0 && hour < 18.0;
  }

  /// Ambil ~4 titik pratinjau ke depan (jarak 3 jam) dari data per-jam,
  /// mulai dari jam saat ini/berikutnya — supaya "Ramalan Hari Ini" di
  /// [WeatherSummaryCard] menampilkan prakiraan nyata, bukan mock.
  List<WeatherForecastItem> _buildForecast(Map<String, dynamic>? hourly, DateTime now) {
    if (hourly == null) return const [];
    final times = (hourly['time'] as List<dynamic>?)?.cast<String>() ?? const [];
    final temps = (hourly['temperature_2m'] as List<dynamic>?)?.cast<num>() ?? const [];
    final codes = (hourly['weather_code'] as List<dynamic>?)?.cast<num>() ?? const [];
    if (times.isEmpty) return const [];

    var startIndex = times.indexWhere((t) {
      final parsed = DateTime.tryParse(t);
      return parsed != null && !parsed.isBefore(now);
    });
    if (startIndex == -1) startIndex = 0;

    final items = <WeatherForecastItem>[];
    for (var step = 0; step < 4; step++) {
      final index = startIndex + step * 3;
      if (index >= times.length || index >= temps.length) break;
      final time = DateTime.tryParse(times[index]);
      final label = time == null
          ? '-'
          : (time.day != now.day ? 'Besok' : '${time.hour.toString().padLeft(2, '0')}.00');
      items.add(WeatherForecastItem(
        label: label,
        condition: index < codes.length ? _mapWeatherCode(codes[index]) : WeatherCondition.berawan,
        temperatureCelsius: temps[index].toDouble(),
        isDay: time?.hour != null ? (time!.hour >= 6 && time.hour < 18) : true,
      ));
    }
    return items;
  }

  /// Mapping kode cuaca WMO (dipakai Open-Meteo) ke [WeatherCondition].
  /// Referensi resmi: https://open-meteo.com/en/docs
  WeatherCondition _mapWeatherCode(num? code) {
    final c = code?.toInt() ?? 0;
    if (c == 0 || c == 1) return WeatherCondition.cerah;
    if (c == 2 || c == 3 || (c >= 45 && c <= 48)) return WeatherCondition.berawan;
    if ((c >= 51 && c <= 57) || c == 61 || c == 80) return WeatherCondition.hujanRingan;
    if (c == 63 ||
        c == 65 ||
        c == 66 ||
        c == 67 ||
        c == 81 ||
        c == 82 ||
        (c >= 71 && c <= 77) ||
        c == 85 ||
        c == 86) {
      return WeatherCondition.hujanLebat;
    }
    if (c == 95 || c == 96 || c == 99) return WeatherCondition.badai;
    return WeatherCondition.berawan;
  }
}
