import 'package:latlong2/latlong.dart';
import '../models/layer_sample_point.dart';
import '../models/map_layer_type.dart';
import '../models/weather_model.dart';

/// Kontrak sumber data cuaca.
///
/// Target arsitektur akhir:
/// HomeScreen -> WeatherProvider -> WeatherRepository -> WeatherService -> Weather API
///
/// Untuk Phase 3, satu-satunya implementasi adalah [MockWeatherRepository].
/// Nanti `RealWeatherRepository` akan memanggil `WeatherService` yang bicara
/// ke Weather API sungguhan (Phase 5), tanpa HomeScreen perlu ditulis ulang.
abstract class WeatherRepository {
  Future<Weather?> getCurrentWeather();

  /// Cuaca untuk titik koordinat APAPUN (dipakai Peta — user bisa memilih
  /// lokasi manapun, bukan cuma lokasi perangkat saat ini seperti di Home).
  Future<Weather?> getWeatherForLocation({
    required double latitude,
    required double longitude,
  });

  /// Nilai satu [layer] di banyak titik sekaligus — dipakai overlay layer
  /// cuaca di Peta supaya user melihat SEBARAN nilai (mis. suhu berbeda
  /// di beberapa titik), bukan cuma 1 angka di 1 lokasi.
  ///
  /// Default: panggil [getWeatherForLocation] satu-satu per titik (aman
  /// untuk implementasi lama yang belum override, tapi lebih lambat).
  /// [OpenMeteoWeatherRepository] override ini dengan 1 request batch.
  Future<List<LayerSamplePoint>> getGridSamples({
    required WeatherLayerType layer,
    required List<LatLng> points,
  }) async {
    final results = <LayerSamplePoint>[];
    for (final p in points) {
      final w = await getWeatherForLocation(latitude: p.latitude, longitude: p.longitude);
      if (w == null) continue;
      final value = _extract(w, layer);
      if (value != null) results.add(LayerSamplePoint(point: p, value: value));
    }
    return results;
  }

  double? _extract(Weather w, WeatherLayerType layer) {
    switch (layer) {
      case WeatherLayerType.wind:
        return w.windKph;
      case WeatherLayerType.windGust:
        return w.windGustKph;
      case WeatherLayerType.rain:
        return w.rainfallMm;
      case WeatherLayerType.temperature:
        return w.temperatureCelsius;
      case WeatherLayerType.dewPoint:
        return w.dewPointCelsius;
      case WeatherLayerType.humidity:
        return w.humidityPercent;
      case WeatherLayerType.pressure:
        return w.pressureHpa;
      case WeatherLayerType.cloudCover:
        return w.cloudCoverPercent;
      case WeatherLayerType.visibility:
        return w.visibilityKm;
      case WeatherLayerType.uvIndex:
        return w.uvIndex;
      default:
        return null;
    }
  }
}


class WeatherApiConfigurationException implements Exception {
  final String message;
  const WeatherApiConfigurationException(this.message);
  @override
  String toString() => message;
}

class WeatherApiUnavailableException implements Exception {
  final String message;
  const WeatherApiUnavailableException(this.message);
  @override
  String toString() => message;
}
