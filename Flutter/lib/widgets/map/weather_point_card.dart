import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../models/map_layer_type.dart';
import '../../providers/air_quality_provider.dart';
import '../../providers/weather_provider.dart';

/// Compact point readout shown when the user taps/searches a location while
/// a global weather/environment layer is active. It deliberately uses the
/// existing real location weather/air-quality repositories, so tapping the
/// map does not trigger the heavy Mercator tile-inspection machinery.
class WeatherPointCard extends ConsumerWidget {
  final LatLng point;
  final WeatherLayerType layer;

  const WeatherPointCard({
    super.key,
    required this.point,
    required this.layer,
  });

  String _datasetLabel() {
    final config = weatherLayerConfigs[layer];
    return config?.title ?? 'Cuaca';
  }

  bool get _needsAir => const {
        WeatherLayerType.airQuality,
        WeatherLayerType.pm25,
        WeatherLayerType.pm10,
        WeatherLayerType.so2,
        WeatherLayerType.no2,
        WeatherLayerType.co,
        WeatherLayerType.ozone,
      }.contains(layer);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jangan memanggil dua API sekaligus. Untuk layer cuaca hanya ambil
    // Open-Meteo Weather; untuk layer lingkungan hanya ambil CAMS/Air Quality.
    // Ini memangkas satu request jaringan setiap kali user search/tap titik.
    final AsyncValue weather = _needsAir
        ? const AsyncValue.data(null)
        : ref.watch(openMeteoWeatherForLocationProvider(point));
    final AsyncValue air = _needsAir
        ? ref.watch(airQualityForLocationProvider(point))
        : const AsyncValue.data(null);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
        decoration: BoxDecoration(
          color: const Color(0xF21A2631),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.10)),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 16, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.my_location_rounded, color: Colors.white, size: 16),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _datasetLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _ValueArea(layer: layer, weather: weather, air: air),
          ],
        ),
      ),
    );
  }
}

class _ValueArea extends StatelessWidget {
  final WeatherLayerType layer;
  final AsyncValue weather;
  final AsyncValue air;

  const _ValueArea({required this.layer, required this.weather, required this.air});

  String _fmt(double value, [int digits = 1]) => value.toStringAsFixed(digits);

  @override
  Widget build(BuildContext context) {
    if (weather.isLoading || air.isLoading) {
      return const SizedBox(
        height: 24,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white70)),
        ),
      );
    }

    final w = weather.valueOrNull;
    final a = air.valueOrNull;
    final items = <String, String>{};

    if (w != null) {
      switch (layer) {
        case WeatherLayerType.temperature:
          items['Suhu'] = '${_fmt(w.temperatureCelsius)} °C';
          break;
        case WeatherLayerType.rain:
          items['Hujan'] = '${_fmt(w.rainfallMm)} mm';
          break;
        case WeatherLayerType.wind:
          items['Angin'] = '${_fmt(w.windKph)} km/j';
          if (w.windDirectionDeg != null) items['Arah'] = '${_fmt(w.windDirectionDeg!, 0)}°';
          break;
        case WeatherLayerType.windGust:
          if (w.windGustKph != null) items['Gust'] = '${_fmt(w.windGustKph!)} km/j';
          break;
        case WeatherLayerType.humidity:
          items['Kelembapan'] = '${_fmt(w.humidityPercent, 0)}%';
          break;
        case WeatherLayerType.pressure:
          if (w.pressureHpa != null) items['Tekanan'] = '${_fmt(w.pressureHpa!)} hPa';
          break;
        case WeatherLayerType.cloudCover:
          if (w.cloudCoverPercent != null) items['Awan'] = '${_fmt(w.cloudCoverPercent!, 0)}%';
          break;
        case WeatherLayerType.visibility:
          if (w.visibilityKm != null) items['Jarak pandang'] = '${_fmt(w.visibilityKm!)} km';
          break;
        case WeatherLayerType.dewPoint:
          if (w.dewPointCelsius != null) items['Dew point'] = '${_fmt(w.dewPointCelsius!)} °C';
          break;
        case WeatherLayerType.uvIndex:
          if (w.uvIndex != null) items['UV'] = _fmt(w.uvIndex!);
          break;
        default:
          break;
      }
    }

    if (a != null) {
      switch (layer) {
        case WeatherLayerType.pm25:
          items['PM2.5'] = '${_fmt(a.pm25.value)} µg/m³';
          break;
        case WeatherLayerType.pm10:
          items['PM10'] = '${_fmt(a.pm10.value)} µg/m³';
          break;
        case WeatherLayerType.so2:
          items['SO₂'] = '${_fmt(a.so2.value)} µg/m³';
          break;
        case WeatherLayerType.no2:
          items['NO₂'] = '${_fmt(a.no2.value)} µg/m³';
          break;
        case WeatherLayerType.co:
          items['CO'] = '${_fmt(a.co.value, 0)} µg/m³';
          break;
        case WeatherLayerType.ozone:
          items['O₃'] = '${_fmt(a.ozone.value)} µg/m³';
          break;
        case WeatherLayerType.airQuality:
          items['AQI'] = '${a.europeanAqi}';
          break;
        default:
          break;
      }
    }

    if (items.isEmpty) {
      return const Text('Nilai titik belum tersedia.', style: TextStyle(color: Colors.white70, fontSize: 10.5));
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: items.entries.map((e) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${e.key} ${e.value}',
            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        );
      }).toList(),
    );
  }
}
