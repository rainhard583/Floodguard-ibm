import 'dart:math';
import 'package:latlong2/latlong.dart';
import '../models/layer_sample_point.dart';
import '../models/map_layer_type.dart';
import '../models/weather_model.dart';
import 'weather_repository.dart';

/// Implementasi MOCK — Weather API sungguhan belum diimplementasikan
/// (baru Phase 5). Nilai di sini murni untuk pengembangan UI Phase 3.
///
/// Ganti nanti dengan `RealWeatherRepository` (yang memanggil
/// `RealWeatherService` ke Weather API) tanpa mengubah HomeScreen atau
/// WeatherSummaryCard.
class MockWeatherRepository implements WeatherRepository {
  @override
  Future<Weather?> getCurrentWeather() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return Weather(
      temperatureCelsius: 28,
      condition: WeatherCondition.hujanRingan,
      rainfallMm: 4.2,
      humidityPercent: 82,
      windKph: 14,
      updatedAt: DateTime.now(),
      forecast: const [
        WeatherForecastItem(label: '15.00', condition: WeatherCondition.hujanRingan, temperatureCelsius: 27),
        WeatherForecastItem(label: '18.00', condition: WeatherCondition.berawan, temperatureCelsius: 26),
        WeatherForecastItem(label: '21.00', condition: WeatherCondition.berawan, temperatureCelsius: 25),
        WeatherForecastItem(label: 'Besok', condition: WeatherCondition.cerah, temperatureCelsius: 29),
      ],
    );
  }

  /// Sama-sama MOCK — dibuat sedikit bervariasi per koordinat (deterministik,
  /// pakai koordinat sebagai seed) supaya lokasi berbeda di peta tidak
  /// selalu menampilkan angka yang identik persis. Weather API sungguhan
  /// tetap pekerjaan Phase 5.
  @override
  Future<List<LayerSamplePoint>> getGridSamples({
    required WeatherLayerType layer,
    required List<LatLng> points,
  }) async {
    if (points.isEmpty) return const [];

    final results = <LayerSamplePoint>[];
    for (final point in points) {
      final weather = await getWeatherForLocation(
        latitude: point.latitude,
        longitude: point.longitude,
      );
      if (weather == null) continue;

      final value = switch (layer) {
        WeatherLayerType.wind => weather.windKph,
        WeatherLayerType.windGust => weather.windGustKph,
        WeatherLayerType.rain => weather.rainfallMm,
        WeatherLayerType.temperature => weather.temperatureCelsius,
        WeatherLayerType.dewPoint => weather.dewPointCelsius,
        WeatherLayerType.humidity => weather.humidityPercent,
        WeatherLayerType.pressure => weather.pressureHpa,
        WeatherLayerType.cloudCover => weather.cloudCoverPercent,
        WeatherLayerType.visibility => weather.visibilityKm,
        WeatherLayerType.uvIndex => weather.uvIndex,
        _ => null,
      };

      if (value != null) {
        results.add(
          LayerSamplePoint(
            point: point,
            value: value,
            directionDegrees: weather.windDirectionDeg,
            source: 'Mock',
            updatedAt: weather.updatedAt,
            isForecast: true,
          ),
        );
      }
    }
    return results;
  }

  @override
  Future<Weather?> getWeatherForLocation({
    required double latitude,
    required double longitude,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final seed = ((latitude * 10000).round() * 13 + (longitude * 10000).round()).abs();
    final random = Random(seed);
    final conditions = WeatherCondition.values;
    final condition = conditions[random.nextInt(conditions.length)];
    final baseTemp = 22 + random.nextDouble() * 10;

    // Prakiraan beberapa jam ke depan + besok, sama seperti
    // [getCurrentWeather] — supaya "Cuaca" tetap punya ramalan hari
    // ini/besok walau lokasinya diganti-ganti, bukan cuma kosong.
    const labels = ['15.00', '18.00', '21.00', 'Besok'];
    final forecast = List.generate(labels.length, (i) {
      final drift = (random.nextDouble() * 4) - 2; // ±2°C variasi per jam
      return WeatherForecastItem(
        label: labels[i],
        condition: conditions[random.nextInt(conditions.length)],
        temperatureCelsius: baseTemp + drift,
      );
    });

    return Weather(
      temperatureCelsius: baseTemp,
      condition: condition,
      rainfallMm: random.nextDouble() * 15,
      humidityPercent: 55 + random.nextDouble() * 40,
      windKph: 4 + random.nextDouble() * 20,
      updatedAt: DateTime.now(),
      forecast: forecast,
    );
  }
}
