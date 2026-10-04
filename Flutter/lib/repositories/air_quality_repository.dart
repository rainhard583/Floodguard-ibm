import 'package:latlong2/latlong.dart';
import '../models/air_quality_model.dart';
import '../models/layer_sample_point.dart';
import '../models/map_layer_type.dart';

/// Kontrak sumber data kualitas udara. Sama pola dengan
/// [WeatherRepository] — UI/provider tidak peduli implementasinya, tinggal
/// ganti provider di [airQualityRepositoryProvider] kalau nanti pindah
/// sumber data.
abstract class AirQualityRepository {
  Future<AirQuality?> getAirQualityForLocation({
    required double latitude,
    required double longitude,
  });

  /// Nilai satu polutan/[layer] di banyak titik — dipakai overlay Air
  /// Quality di Peta. Default: panggil per-titik satu-satu (aman untuk
  /// implementasi lama); [OpenMeteoAirQualityRepository] override dengan
  /// 1 request batch.
  Future<List<LayerSamplePoint>> getGridSamples({
    required WeatherLayerType layer,
    required List<LatLng> points,
  }) async {
    final results = <LayerSamplePoint>[];
    for (final p in points) {
      final aq = await getAirQualityForLocation(latitude: p.latitude, longitude: p.longitude);
      if (aq == null) continue;
      final value = _extract(aq, layer);
      if (value != null) results.add(LayerSamplePoint(point: p, value: value));
    }
    return results;
  }

  double? _extract(AirQuality aq, WeatherLayerType layer) {
    switch (layer) {
      case WeatherLayerType.airQuality:
        return aq.europeanAqi.toDouble();
      case WeatherLayerType.pm25:
        return aq.pm25.value;
      case WeatherLayerType.pm10:
        return aq.pm10.value;
      case WeatherLayerType.so2:
        return aq.so2.value;
      case WeatherLayerType.no2:
        return aq.no2.value;
      case WeatherLayerType.co:
        return aq.co.value;
      case WeatherLayerType.ozone:
        return aq.ozone.value;
      default:
        return null;
    }
  }
}
