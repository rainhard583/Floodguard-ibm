import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/flood_risk_model.dart';
import '../models/weather_model.dart';
import 'weather_provider.dart';

/// Risiko banjir di Home dihitung dari SATU respons WeatherAPI yang sama
/// dengan kartu Cuaca, sehingga tidak ada request kedua yang bisa gagal/timeout.
/// Ini tetap indikator cuaca, bukan prediksi genangan hidrologi.
final floodRiskProvider = FutureProvider.autoDispose<FloodRisk?>((ref) async {
  final weather = await ref.watch(weatherProvider.future);
  if (weather == null) return null;

  final currentRain = weather.rainfallMm;
  final next24h = weather.forecast.fold<double>(
    0,
    (sum, item) => sum + item.precipitationMm,
  );

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

  return FloodRisk(
    level: level,
    score: score,
    updatedAt: weather.updatedAt,
    description:
        'Hujan saat ini ${currentRain.toStringAsFixed(1)} mm, potensi presipitasi 24 jam ke depan ${next24h.toStringAsFixed(1)} mm. Ini indikator cuaca, bukan prediksi genangan di alamat persis.',
  );
});

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
