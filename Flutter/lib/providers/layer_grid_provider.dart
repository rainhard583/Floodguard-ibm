import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/layer_sample_point.dart';
import '../models/map_layer_type.dart';
import 'air_quality_provider.dart';
import 'map_layer_provider.dart';
import 'weather_provider.dart';

const _airQualityLayers = {
  WeatherLayerType.airQuality,
  WeatherLayerType.pm25,
  WeatherLayerType.pm10,
  WeatherLayerType.so2,
  WeatherLayerType.no2,
  WeatherLayerType.co,
  WeatherLayerType.ozone,
};

/// Titik-titik sampel (REAL, dari API) untuk layer cuaca/udara yang
/// sedang aktif, dalam area peta yang sedang terlihat. `null` kalau
/// tidak ada layer aktif atau layer belum `supported`.
class LayerGridController extends StateNotifier<AsyncValue<List<LayerSamplePoint>>> {
  final Ref ref;
  int _requestGeneration = 0;
  WeatherLayerType? _loadedLayer;
  WeatherLayerType? get loadedLayer => _loadedLayer;
  final Map<String, List<LayerSamplePoint>> _cache = {};
  LayerGridController(this.ref) : super(const AsyncValue.data([]));

  /// Bikin grid NxN titik di dalam [bounds], lalu ambil nilai layer yang
  /// sedang aktif untuk semua titik itu dalam 1 request batch.
  ///
  /// Dipanggil MapScreen secara eksplisit (saat layer dipilih / tombol
  /// "Muat area ini" ditekan) — BUKAN otomatis tiap pan/zoom pixel-by-
  /// pixel, sesuai requirement performance (debounce manual).
  Future<void> loadForBounds(LatLngBounds bounds, {double zoom = 7}) async {
    final requestGeneration = ++_requestGeneration;
    final layer = ref.read(activeWeatherLayerProvider);
    // Never let samples from the previous layer be painted using the new
    // layer's palette while the new request is in flight.
    if (_loadedLayer != layer) {
      _loadedLayer = null;
      state = const AsyncValue.data([]);
    }
    if (layer == null || !(weatherLayerConfigs[layer]?.supported ?? false)) {
      state = const AsyncValue.data([]);
      return;
    }

    // Keep the field smooth enough for a map, but deliberately limit
    // requests on mobile. The samples are only the hidden data grid; the
    // user sees one continuous interpolated field, never these points.
    // Request a padded field, not only the exact viewport. This keeps the
    // previous field visually covering the map while the user pans and
    // prevents the weather layer from suddenly disappearing at the edge.
    final latSpan = bounds.north - bounds.south;
    final lngSpan = bounds.east - bounds.west;
    final padded = LatLngBounds(
      LatLng(
        (bounds.south - latSpan * .35).clamp(-85.0, 85.0),
        (bounds.west - lngSpan * .35).clamp(-180.0, 180.0),
      ),
      LatLng(
        (bounds.north + latSpan * .35).clamp(-85.0, 85.0),
        (bounds.east + lngSpan * .35).clamp(-180.0, 180.0),
      ),
    );
    final isAir = _airQualityLayers.contains(layer);
    final gridSize = isAir
        ? (zoom >= 10 ? 17 : zoom >= 7 ? 15 : 13)
        : (zoom >= 11 ? 21 : zoom >= 8 ? 17 : 15);
    // Snap cache cells so small pans reuse an already fetched field.
    final cacheLat = (bounds.center.latitude * 2).round() / 2;
    final cacheLng = (bounds.center.longitude * 2).round() / 2;
    final cacheKey = '${layer.name}:$cacheLat:$cacheLng:${zoom.floor()}';
    final cached = _cache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      _loadedLayer = layer;
      state = AsyncValue.data(cached);
      return;
    }
    final points = <LatLng>[];
    final paddedLatStep = (padded.north - padded.south) / (gridSize - 1);
    final paddedLngStep = (padded.east - padded.west) / (gridSize - 1);
    for (var i = 0; i < gridSize; i++) {
      for (var j = 0; j < gridSize; j++) {
        points.add(LatLng(
          padded.south + paddedLatStep * i,
          padded.west + paddedLngStep * j,
        ));
      }
    }

    // IMPORTANT: do not clear the last successful field while a new area
    // is downloading. This is what keeps Wind/PM/SO2 visible while panning.
    final previous = state.valueOrNull;
    if (previous == null || previous.isEmpty) {
      state = const AsyncValue.loading();
    }
    try {
      final samples = _airQualityLayers.contains(layer)
          ? await ref.read(airQualityRepositoryProvider).getGridSamples(layer: layer, points: points)
          : await ref.read(openMeteoWeatherRepositoryProvider).getGridSamples(layer: layer, points: points);
      if (!mounted || requestGeneration != _requestGeneration) return;
      _cache[cacheKey] = samples;
      _loadedLayer = layer;
      // Keep cache bounded so a long map session cannot grow memory forever.
      if (_cache.length > 18) _cache.remove(_cache.keys.first);
      state = AsyncValue.data(samples);
    } catch (e, st) {
      if (!mounted || requestGeneration != _requestGeneration) return;
      state = AsyncValue.error(e, st);
    }
  }

  void clear() {
    _requestGeneration++;
    _loadedLayer = null;
    state = const AsyncValue.data([]);
  }
}

final layerGridProvider =
    StateNotifierProvider<LayerGridController, AsyncValue<List<LayerSamplePoint>>>((ref) {
  return LayerGridController(ref);
});
