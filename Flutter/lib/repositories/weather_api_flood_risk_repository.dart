import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../models/flood_risk_model.dart';
import 'flood_risk_repository.dart';

/// Weather-based flood indicator using the same Laravel -> WeatherAPI data
/// as Home. This is a weather indicator, not a hydrological inundation model.
class WeatherApiFloodRiskRepository implements FloodRiskRepository {
  final http.Client _client;

  WeatherApiFloodRiskRepository({http.Client? client}) : _client = client ?? http.Client();

  @override
  Future<FloodRisk?> getCurrentFloodRisk() =>
      getFloodRiskForLocation(latitude: -6.2088, longitude: 106.8456);

  @override
  Future<FloodRisk?> getFloodRiskForLocation({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(ApiConfig.currentWeatherUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );

    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Server cuaca FloodGuard HTTP ${response.statusCode}');
    }

    final root = jsonDecode(response.body);
    if (root is! Map || root['success'] != true) return null;

    final current = root['current'] ?? root['weather'];
    final forecast = root['forecast'];
    if (current is! Map) return null;

    final currentRain = _num(current['precip_mm'] ?? current['rain_mm']);
    var next24h = 0.0;

    if (forecast is List) {
      final now = DateTime.now();
      for (final item in forecast) {
        if (item is! Map) continue;
        final time = DateTime.tryParse(item['time']?.toString() ?? '');
        if (time == null || time.isBefore(now) || time.isAfter(now.add(const Duration(hours: 24)))) {
          continue;
        }
        next24h += _num(item['precip_mm']);
      }
    }

    final currentScore = _currentRainScore(currentRain);
    final forecastScore = _rainToScore(next24h);
    final score = (currentScore * 0.45 + forecastScore * 0.55).round().clamp(0, 100);

    final level = score < 30
        ? FloodRiskLevel.aman
        : score < 55
            ? FloodRiskLevel.waspada
            : score < 80
                ? FloodRiskLevel.siaga
                : FloodRiskLevel.bahaya;

    final condition = current['condition']?.toString();
    final updatedAt = DateTime.tryParse(current['last_updated']?.toString() ?? '') ?? DateTime.now();

    return FloodRisk(
      level: level,
      score: score,
      description:
          'Kondisi saat ini ${condition ?? 'tidak diketahui'}, hujan ${currentRain.toStringAsFixed(1)} mm. '
          'Potensi presipitasi 24 jam ke depan ${next24h.toStringAsFixed(1)} mm. '
          'Ini indikator cuaca, bukan prediksi genangan di alamat persis.',
      updatedAt: updatedAt,
    );
  }

  double _currentRainScore(double mm) {
    if (mm <= 0) return 0;
    if (mm <= 2) return 20;
    if (mm <= 10) return 45;
    if (mm <= 25) return 70;
    return 100;
  }

  double _rainToScore(double mm) {
    if (mm <= 0) return 0;
    if (mm <= 20) return (mm / 20) * 35;
    if (mm <= 50) return 35 + ((mm - 20) / 30) * 30;
    if (mm <= 100) return 65 + ((mm - 50) / 50) * 25;
    return (90 + ((mm - 100) / 50) * 10).clamp(0, 100);
  }

  double _num(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
