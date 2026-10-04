import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../core/config/api_config.dart';
import '../models/layer_sample_point.dart';
import '../models/map_layer_type.dart';
import '../models/weather_model.dart';
import 'open_meteo_weather_repository.dart';
import 'weather_repository.dart';

/// FloodGuard weather architecture:
///
/// 1. Current Home weather + forecast -> Laravel -> WeatherAPI.
/// 2. Open-Meteo remains available directly for map/grid model layers.
/// 3. WeatherAPI secrets never enter the Flutter APK.
class HybridWeatherRepository implements WeatherRepository {
  final OpenMeteoWeatherRepository _global = OpenMeteoWeatherRepository();
  final http.Client _client;

  // Menyimpan observasi terakhir per-koordinat selama aplikasi hidup.
  // Ini hanya fallback singkat saat request berikutnya gagal sementara.
  //
  // _lastGood  : data cuaca yang berhasil diperoleh.
  // _cachedAt  : waktu Flutter MENYIMPAN data tersebut (bukan waktu
  //              observasi WeatherAPI). Dipakai sebagai dasar umur cache
  //              agar entri yang sudah > 20 menit tidak dipakai lagi
  //              meski `weather.updatedAt` (timestamp observasi dari
  //              WeatherAPI) tampak masih baru.
  final Map<String, Weather> _lastGood = <String, Weather>{};
  final Map<String, DateTime> _cachedAt = <String, DateTime>{};

  HybridWeatherRepository({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<Weather?> getCurrentWeather() => getWeatherForLocation(
        latitude: -6.2088,
        longitude: 106.8456,
      );

  @override
  Future<List<LayerSamplePoint>> getGridSamples({
    required WeatherLayerType layer,
    required List<LatLng> points,
  }) {
    // Map/grid layers intentionally use Open-Meteo so one map does not create
    // dozens or hundreds of WeatherAPI requests.
    return _global.getGridSamples(layer: layer, points: points);
  }

  @override
  Future<Weather?> getWeatherForLocation({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(ApiConfig.currentWeatherUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        // Cache-buster only; Laravel ignores this parameter.
        '_fg': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );

    final cacheKey = '${latitude.toStringAsFixed(4)},${longitude.toStringAsFixed(4)}';
    Object? lastError;

    // Laravel -> WeatherAPI can occasionally take a few seconds. Do not
    // fail a perfectly healthy request just because the first attempt is slow.
    for (var attempt = 1; attempt <= 2; attempt++) {
      try {
        final response = await _client.get(
          uri,
          headers: const {
            'Accept': 'application/json',
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        ).timeout(const Duration(seconds: 20));

        final rawBody = utf8.decode(response.bodyBytes, allowMalformed: true);
        final body = _decodeMap(rawBody);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          lastError = WeatherApiUnavailableException(
            _serverError(response.statusCode, body, rawBody),
          );
        } else if (body == null) {
          lastError = const WeatherApiUnavailableException(
            'Respons server cuaca bukan JSON yang valid.',
          );
        } else {
          // Laravel's contract is { success: true, provider: WeatherAPI,
          // current: {...}, forecast: [...] }. Accept bool true and the
          // string form as well so harmless serialization differences do not
          // make Home show an error.
          final success = body['success'] == true ||
              body['success']?.toString().toLowerCase() == 'true';

          final rootData = body['data'];
          final data = rootData is Map
              ? Map<String, dynamic>.from(rootData)
              : body;

          final currentRaw = data['current'] ?? data['weather'];
          final provider = (data['provider'] ?? body['provider'] ?? '')
              .toString()
              .trim()
              .toLowerCase();

          if (!success) {
            lastError = WeatherApiUnavailableException(
              _messageFromBody(body) ??
                  'Laravel belum berhasil mengirim data cuaca realtime.',
            );
          } else if (currentRaw is! Map) {
            lastError = const WeatherApiUnavailableException(
              'Respons Laravel berhasil, tetapi objek current/weather tidak ditemukan.',
            );
          } else {
            // Do not reject valid weather data merely because the provider
            // label has whitespace/casing differences. The Laravel endpoint
            // is the trusted gateway and already hides the WeatherAPI key.
            final current = Map<String, dynamic>.from(currentRaw);
            final forecast = data['forecast'] ?? body['forecast'];
            final weather = _toWeather(current, forecast);

            // Keep the backend provider as source metadata when available,
            // but never block a valid response because of its label.
            if (provider.isNotEmpty && provider != 'weatherapi') {
              debugPrint('[WeatherRepository] provider dari server: $provider');
            }

            _lastGood[cacheKey] = weather;
            _cachedAt[cacheKey] = DateTime.now();
            return weather;
          }
        }
      } on TimeoutException catch (e) {
        lastError = WeatherApiUnavailableException(
          'Request cuaca timeout setelah 20 detik: $e',
        );
      } on FormatException catch (e) {
        lastError = WeatherApiUnavailableException(
          'Respons cuaca tidak dapat diproses: $e',
        );
      } catch (e) {
        lastError = e;
      }

      debugPrint(
        '[WeatherRepository] percobaan $attempt gagal untuk $latitude,$longitude: $lastError',
      );

      if (attempt < 2) {
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }

    final cached = _lastGood[cacheKey];
    final storedAt = _cachedAt[cacheKey];
    if (cached != null && storedAt != null) {
      final age = DateTime.now().difference(storedAt);
      if (age <= const Duration(minutes: 20)) return cached;
    }

    if (lastError is WeatherApiUnavailableException) {
      throw lastError as WeatherApiUnavailableException;
    }

    throw WeatherApiUnavailableException(
      'Gagal mengambil cuaca dari Laravel: ${lastError ?? 'error tidak diketahui'}.',
    );
  }

  Weather _toWeather(
    Map<String, dynamic> current,
    dynamic forecastRaw,
  ) {
    final now = DateTime.now();
    final lastUpdated = DateTime.tryParse(
          current['last_updated']?.toString() ?? '',
        ) ??
        now;

    return Weather(
      temperatureCelsius: _num(current['temperature_c'] ?? current['temp_c']),
      currentHourModelTemperatureCelsius: _nullableNum(current['current_hour_model_temperature_c']),
      feelsLikeCelsius: _nullableNum(current['feels_like_c'] ?? current['feelslike_c']),
      condition: _mapWeatherApiConditionCode(_int(current['condition_code'])),
      isDay: _num(current['is_day']) >= 1,
      rainfallMm: _num(current['precip_mm'] ?? current['rain_mm']),
      humidityPercent: _num(current['humidity_percent'] ?? current['humidity']),
      windKph: _num(current['wind_kph']),
      updatedAt: lastUpdated,
      forecast: _parseForecast(forecastRaw, now),
      windDirectionDeg: _windDirectionToDegrees(current['wind_direction']?.toString()),
      windGustKph: _nullableNum(current['wind_gust_kph']),
      pressureHpa: _nullableNum(current['pressure_hpa']),
      cloudCoverPercent: _nullableNum(current['cloud_percent']),
      uvIndex: _nullableNum(current['uv_index']),
      visibilityKm: _nullableNum(current['visibility_km']),
      dewPointCelsius: _nullableNum(current['dewpoint_c']),
      source: 'WeatherAPI — Current Weather',
      observationType: WeatherObservationType.observation,
    );
  }

  List<WeatherForecastItem> _parseForecast(dynamic raw, DateTime now) {
    if (raw is! List) return const [];

    final result = <WeatherForecastItem>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final time = DateTime.tryParse(item['time']?.toString() ?? '');
      if (time == null || time.isBefore(now)) continue;

      final localTime = time.toLocal();
      final sameDay = localTime.year == now.toLocal().year &&
          localTime.month == now.toLocal().month &&
          localTime.day == now.toLocal().day;

      result.add(
        WeatherForecastItem(
          label: sameDay
              ? '${localTime.hour.toString().padLeft(2, '0')}.00'
              : '${localTime.day.toString().padLeft(2, '0')}/${localTime.month.toString().padLeft(2, '0')} ${localTime.hour.toString().padLeft(2, '0')}.00',
          condition: _mapWeatherApiConditionCode(_int(item['condition_code'])),
          temperatureCelsius: _num(item['temperature_c'] ?? item['temp_c']),
          precipitationMm: _num(item['precip_mm']),
          isDay: _num(item['is_day']) >= 1,
          chanceOfRainPercent: _nullableNum(item['chance_of_rain_percent'] ?? item['chance_of_rain']),
          humidityPercent: _nullableNum(item['humidity_percent'] ?? item['humidity']),
          windKph: _nullableNum(item['wind_kph']),
          forecastTime: localTime,
        ),
      );

      if (result.length >= 24) break;
    }
    return result;
  }

  Map<String, dynamic>? _decodeMap(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (_) {}
    return null;
  }

  String _serverError(int statusCode, Map<String, dynamic>? body, String rawBody) {
    final message = _messageFromBody(body);
    if (message != null && message.isNotEmpty) return message;
    final preview = rawBody.trim();
    if (preview.isNotEmpty) {
      final safePreview = preview.length > 180 ? preview.substring(0, 180) : preview;
      return 'Server cuaca FloodGuard HTTP $statusCode: $safePreview';
    }
    return 'Server cuaca FloodGuard mengembalikan HTTP $statusCode.';
  }

  String? _messageFromBody(Map<String, dynamic>? body) {
    if (body == null) return null;
    for (final key in const ['error', 'message', 'detail']) {
      final value = body[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  double? _nullableNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  WeatherCondition _mapWeatherApiConditionCode(int? code) {
    final c = code ?? -1;
    if (c == 1000) return WeatherCondition.cerah;
    if (c == 1087 || (c >= 1273 && c <= 1282)) return WeatherCondition.badai;
    if (c == 1189 || c == 1192 || c == 1195 || c == 1201 || c == 1243 || c == 1246) {
      return WeatherCondition.hujanLebat;
    }
    if ((c >= 1150 && c <= 1207) || (c >= 1240 && c <= 1252)) {
      return WeatherCondition.hujanRingan;
    }
    if (c == 1003 || c == 1006 || c == 1009 || c == 1030 || c == 1135 || c == 1147) {
      return WeatherCondition.berawan;
    }
    if ((c >= 1063 && c <= 1117) || (c >= 1210 && c <= 1237) || (c >= 1255 && c <= 1264)) {
      return WeatherCondition.hujanRingan;
    }
    return WeatherCondition.berawan;
  }

  double? _windDirectionToDegrees(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    const map = {
      'N': 0.0,
      'NNE': 22.5,
      'NE': 45.0,
      'ENE': 67.5,
      'E': 90.0,
      'ESE': 112.5,
      'SE': 135.0,
      'SSE': 157.5,
      'S': 180.0,
      'SSW': 202.5,
      'SW': 225.0,
      'WSW': 247.5,
      'W': 270.0,
      'WNW': 292.5,
      'NW': 315.0,
      'NNW': 337.5,
    };
    return map[value.trim().toUpperCase()];
  }
}
