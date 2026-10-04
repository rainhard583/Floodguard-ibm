import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/map_layer_type.dart';

/// Kategori domain yang sedang dibuka di panel layer peta (Cuaca &
/// Lingkungan / Bencana Alam). `null` = panel layer sedang tertutup.
final activeMapLayerCategoryProvider = StateProvider<MapLayerCategory?>((ref) => null);

/// Panel layer tampil sebagai overlay di atas map, bukan halaman/navigation.
final mapLayerPanelVisibleProvider = StateProvider<bool>((ref) => false);

/// Layer cuaca yang sedang AKTIF ditampilkan di peta. `null` = tidak ada
/// layer cuaca yang aktif (peta polos).
final activeWeatherLayerProvider = StateProvider<WeatherLayerType?>((ref) => null);

/// Layer bencana yang sedang aktif. Terpisah dari layer cuaca supaya
/// keduanya bisa independen (mis. nanti mendukung 1 cuaca + 1 bencana
/// aktif bersamaan).
final activeDisasterLayerProvider = StateProvider<DisasterLayerType?>((ref) => null);


final mapLayerCategoryProvider = StateProvider<MapLayerCategory>((ref) => MapLayerCategory.weatherEnvironment);
