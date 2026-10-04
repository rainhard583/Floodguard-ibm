import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../models/app_location_model.dart';
import '../../models/map_layer_type.dart';
import '../../models/searched_place_model.dart';
import '../../providers/earthquake_event_provider.dart';
import '../../models/earthquake_event_model.dart';
import '../../providers/location_provider.dart';
import '../../providers/location_search_provider.dart';
import '../../providers/map_layer_provider.dart';
import '../../providers/volcano_provider.dart';
import '../../providers/tsunami_warning_provider.dart';
import '../../models/volcano_model.dart';
import '../../models/tsunami_warning_event.dart';
import '../../widgets/map/location_search_bar.dart';
import '../../widgets/map/map_layer_selector.dart';
import '../../widgets/map/selected_location_panel.dart';
import '../../widgets/map/weather_legend.dart';
import '../../widgets/map/weather_point_card.dart';
import '../../widgets/map/mercator_weather_map.dart';
import '../../widgets/map/disaster_guide_handle.dart';

/// Peta Global — user bisa mencari lokasi APAPUN (search global, bukan
/// cuma di sekitar Indonesia) atau mengetuk langsung di peta, lalu melihat
/// estimasi risiko gempa bumi & tsunami (skala Likert 1-5 + jarak dalam
/// km) serta cuaca untuk titik tersebut.
///
/// Peta memakai flutter_map + tile OpenStreetMap (gratis, tanpa API key).
/// Search & reverse-geocode memakai Nominatim (juga OpenStreetMap, real,
/// bukan mock) — lihat [NominatimLocationSearchRepository].
///
/// CATATAN CAKUPAN: laporan banjir warga & area rawan banjir di peta
/// (deskripsi PlaceholderScreen sebelumnya) BELUM diimplementasikan di
/// sini — itu tetap "Flood Map" (Phase 11) yang butuh backend laporan
/// warga sungguhan. Yang dibangun di sini murni eksplorasi lokasi +
/// estimasi risiko gempa/tsunami/cuaca sesuai permintaan terbaru.
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> with SingleTickerProviderStateMixin {
  final _mapController = MapController();
  final ValueNotifier<({double latitude, double longitude, double zoom})?> _weatherViewCommand = ValueNotifier(null);
  String _weatherStatus = 'Menyiapkan weather engine…';

  // Pusat awal: Indonesia (relevan untuk FloodGuard), tapi user tetap
  // bebas mencari/menggeser peta ke lokasi manapun di dunia.
  static const _initialCenter = LatLng(-2.5, 118.0);
  static const _initialZoom = 4.6;

  // Menampilkan status ringan bila tile tertentu gagal dimuat.
  bool _tileLoadError = false;

  // Animasi marker lokasi yang baru dipilih. Marker muncul dengan efek
  // pop/bounce kecil agar titik hasil search terasa jelas tertuju.
  late final AnimationController _markerAnimationController;
  late final Animation<double> _markerScale;

  // Fitur "kembali ke titik merah" (recenter button) — tombol ini cuma
  // muncul otomatis begitu titik yang sedang dipilih (`selectedPoint`)
  // sudah keluar dari area peta yang sedang terlihat (mis. user geser
  // petanya sendiri), sama seperti tombol "recenter" di Google
  // Maps/aplikasi peta pada umumnya. `mapEventStream` dipakai supaya
  // pengecekan ini jalan tiap kali peta digeser/di-zoom, bukan cuma
  // sekali saat lokasi dipilih.
  StreamSubscription<MapEvent>? _mapEventSubscription;
  bool _showRecenterButton = false;
  bool _locationDetailsOpen = false;
  bool _mapReady = false;
  LatLng? _pendingMovePoint;
  double? _pendingMoveZoom;

  @override
  void initState() {
    super.initState();
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _markerScale = CurvedAnimation(
      parent: _markerAnimationController,
      curve: Curves.elasticOut,
    );
    _mapEventSubscription = _mapController.mapEventStream.listen(_onMapEvent);
    ref.listenManual<WeatherLayerType?>(activeWeatherLayerProvider, (previous, next) {
      if (!mounted) return;
      if (next != null && previous == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_showRecenterButton) return;
          setState(() => _showRecenterButton = false);
        });
      }
    });
  }

  void _showEarthquakeDetail(BuildContext context, EarthquakeEvent e) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Gempa M${e.magnitude.toStringAsFixed(1)}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 19, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(e.place, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Text('Kedalaman: ${e.depthKm.toStringAsFixed(1)} km', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            Text('Waktu UTC: ${e.time.toIso8601String()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 10),
            Text(e.source, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showTsunamiWarningDetail(BuildContext context, TsunamiWarningEvent e) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.tsunami_rounded, color: Color(0xFF29B6F6)),
              SizedBox(width: 8),
              Text('Potensi Tsunami BMKG', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 10),
            Text('M${e.magnitude.toStringAsFixed(1)} · ${e.region}', style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
            const SizedBox(height: 6),
            Text('Kedalaman ${e.depthKm.toStringAsFixed(0)} km · ${e.potential}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 6),
            Text('Waktu ${e.time.toLocal()}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            const Text('Sumber: BMKG Data Gempabumi Terbuka', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  void _showVolcanoDetail(BuildContext context, VolcanoModel v) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(v.name, style: const TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
            Text(v.region, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            Text('Ketinggian: ${v.elevationMeters.toStringAsFixed(0)} mdpl',
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(12)),
              child: Text(v.source, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.4)),
            ),
          ],
        ),
      ),
    );
  }

  void _onMapEvent(MapEvent event) {
    final point = ref.read(selectedMapLocationProvider);
    if (!mounted || point == null || !_mapReady) return;

    final visible = _mapController.camera.visibleBounds;
    final shouldShow = !visible.contains(point);
    if (shouldShow != _showRecenterButton) {
      setState(() => _showRecenterButton = shouldShow);
    }
  }

  void _recenter() {
    final point = ref.read(selectedMapLocationProvider);
    if (point == null || !_mapReady) return;
    // Pertahankan level zoom yang sedang dipakai user, cuma geser
    // kameranya kembali — bukan reset ke zoom 13, supaya tidak terasa
    // "melompat" tiba-tiba kalau user memang sengaja zoom out/in duluan.
    _mapController.move(point, _mapController.camera.zoom);
    setState(() => _showRecenterButton = false);
  }

  @override
  void dispose() {
    _weatherViewCommand.dispose();
    _mapEventSubscription?.cancel();
    _markerAnimationController.dispose();
    super.dispose();
  }

  void _reloadTiles() {
    // Jangan mengganti key TileLayer. Mengganti key saat lokasi berpindah
    // membuang seluruh TileLayer dan pada koneksi mobile yang lambat dapat
    // membuat peta terlihat hitam/kosong. Reload hanya dilakukan secara
    // eksplisit oleh user melalui tombol ini.
    setState(() {
      _tileLoadError = false;
    });
  }

  Future<void> _selectPoint(LatLng point, {String? knownLabel}) async {
    ref.read(selectedMapLocationProvider.notifier).state = point;
    ref.read(selectedMapLocationLabelProvider.notifier).state = knownLabel;
    setState(() {
      _tileLoadError = false;
      _showRecenterButton = false;
      if (ref.read(activeWeatherLayerProvider) == null) _locationDetailsOpen = true;
    });

    // Pertahankan TileLayer yang sedang hidup. Kalau search terjadi sebelum
    // FlutterMap selesai dirender, simpan perpindahannya dan jalankan setelah
    // onMapReady. MapController tidak boleh dipakai sebelum itu.
    if (_mapReady) {
      _mapController.move(point, 13);
    } else {
      _pendingMovePoint = point;
      _pendingMoveZoom = 13;
    }

    // Jalankan animasi marker setiap kali lokasi baru dipilih.
    _markerAnimationController
      ..stop()
      ..reset()
      ..forward();

    if (knownLabel == null) {
      // Tap langsung di peta (bukan lewat search) -> reverse geocode
      // supaya tetap dapat nama lokasi, bukan cuma koordinat mentah.
      try {
        final repository = ref.read(locationSearchRepositoryProvider);
        final name = await repository.reverseGeocode(
          latitude: point.latitude,
          longitude: point.longitude,
        );
        if (!mounted) return;
        // Pengecekan titik masih sama mencegah race condition kalau user
        // sempat tap titik lain sebelum reverse-geocode ini selesai.
        if (name != null && ref.read(selectedMapLocationProvider) == point) {
          ref.read(selectedMapLocationLabelProvider.notifier).state = name;
        }
      } catch (_) {
        // Reverse-geocode gagal bukan hal fatal — SelectedLocationPanel
        // tetap punya fallback tampilkan "lat, lng" mentah.
      }
    }
  }

  void _onPlaceSelected(SearchedPlace place) {
    final point = LatLng(place.latitude, place.longitude);

    // Search memindahkan peta utama. Jika weather mode aktif, WebView Mercator
    // juga diarahkan ke lokasi yang sama.
    ref.read(selectedMapLocationProvider.notifier).state = point;
    ref.read(selectedMapLocationLabelProvider.notifier).state = place.displayName;
    setState(() {
      _tileLoadError = false;
      _showRecenterButton = false;
      _locationDetailsOpen = ref.read(activeWeatherLayerProvider) == null;
    });

    if (_mapReady) {
      _mapController.move(point, ref.read(activeWeatherLayerProvider) != null ? 8.0 : 13.0);
    } else {
      _pendingMovePoint = point;
      _pendingMoveZoom = ref.read(activeWeatherLayerProvider) != null ? 8.0 : 13.0;
    }

    _markerAnimationController
      ..stop()
      ..reset()
      ..forward();

    if (ref.read(activeWeatherLayerProvider) != null) {
      _weatherViewCommand.value = (
        latitude: place.latitude,
        longitude: place.longitude,
        zoom: 8.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedPoint = ref.watch(selectedMapLocationProvider);
    final myLocation = ref.watch(locationProvider).valueOrNull;
    final myLatLng = (myLocation != null &&
            myLocation.status == LocationStatus.available &&
            myLocation.latitude != null &&
            myLocation.longitude != null)
        ? LatLng(myLocation.latitude!, myLocation.longitude!)
        : null;

    final activeWeatherLayer = ref.watch(activeWeatherLayerProvider);
    final activeDisasterLayer = ref.watch(activeDisasterLayerProvider);
    final volcanoes = ref.watch(volcanoListProvider).valueOrNull ?? const [];
    final earthquakeEvents = ref.watch(earthquakeEventsProvider).valueOrNull ?? const [];
    final tsunamiWarnings = ref.watch(tsunamiWarningEventsProvider).valueOrNull ?? const <TsunamiWarningEvent>[];

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _initialCenter,
              initialZoom: _initialZoom,
              onMapReady: () {
                _mapReady = true;
                final pendingPoint = _pendingMovePoint;
                final pendingZoom = _pendingMoveZoom;
                _pendingMovePoint = null;
                _pendingMoveZoom = null;
                if (pendingPoint != null && mounted) {
                  _mapController.move(pendingPoint, pendingZoom ?? 13);
                }
              },
              // Dibatasi supaya peta TIDAK BISA di-zoom-out/in sampai
              // melewati batas tile OSM yang tersedia (yang bikin peta
              // kelihatan "hilang"/kosong kalau di-zoom-out terus).
              minZoom: 2.5,
              maxZoom: 18,
              onTap: (tapPosition, point) { _selectPoint(point); },
            ),
            children: [
              TileLayer(
                // KUNCI PENTING: key TETAP dan SELALU ada di posisi yang
                // sama dalam list `children` ini (lihat juga catatan di
                // MarkerLayer di bawah). Sebelumnya, MarkerLayer marker
                // merah cuma MUNCUL di list ini ketika lokasi dipilih
                // (`if (selectedPoint != null) MarkerLayer(...)`), yang
                // artinya panjang/urutan list `children` FlutterMap
                // BERUBAH persis di saat itu. Tanpa key yang stabil,
                // Flutter bisa salah mencocokkan widget lama vs baru saat
                // list-nya berubah bentuk, dan TileLayer ini pun ikut
                // dianggap "berbeda" lalu dibongkar-pasang ulang —
                // itulah sebabnya peta sempat hilang/hitam TEPAT saat
                // panel lokasi muncul. Solusinya: key tetap + list
                // `children` yang panjang & urutannya TIDAK PERNAH
                // berubah (lihat 2 MarkerLayer di bawah, keduanya SELALU
                // ada, cuma isi markernya yang kosong/terisi).
                key: const ValueKey('tile_layer'),
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.coba2',
                maxZoom: 18,
                keepBuffer: 2,
                errorTileCallback: (tile, error, stackTrace) {
                  if (!mounted || _tileLoadError) return;
                  setState(() => _tileLoadError = true);
                },
              ),

              // Marker "lokasi kamu" — widget-nya SELALU ada di list ini
              // (key tetap), cuma daftar markernya yang kosong ([]) kalau
              // lokasi belum diketahui. TIDAK PERNAH ditambah/dihapus
              // dari `children`, supaya panjang list ini stabil.
              MarkerLayer(
                key: const ValueKey('my_location_layer'),
                markers: myLatLng == null
                    ? const []
                    : [
                        Marker(
                          point: myLatLng,
                          width: 26,
                          height: 26,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blue,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 6),
                              ],
                            ),
                          ),
                        ),
                      ],
              ),
              // Marker merah hasil pencarian/tap — sama seperti di atas:
              // widget-nya SELALU ada (key tetap), cuma daftar markernya
              // yang kosong/terisi. Ini yang memperbaiki bug peta hilang.
              MarkerLayer(
                key: const ValueKey('search_result_layer'),
                markers: selectedPoint == null
                    ? const []
                    : [
                        Marker(
                          point: selectedPoint,
                          width: 76,
                          // Tinggi = 2x titik tengah (46) supaya ujung pin bisa
                          // ditempatkan presisi di baris tengah box lewat
                          // `bottom: 46` di bawah — lihat penjelasan di komentar
                          // dalam builder.
                          height: 92,
                          // SENGAJA TIDAK di-set `alignment` di sini (pakai
                          // default Alignment.center) — PERSIS seperti marker
                          // biru "lokasi saya" di atas, yang terbukti tidak
                          // melenceng sedikit pun walau di-zoom-out. Titik
                          // geografis sebenarnya = tepat di TENGAH box 76x92
                          // ini secara vertikal (y=46).
                          child: AnimatedBuilder(
                            animation: _markerScale,
                            builder: (context, child) {
                              final raw = _markerScale.value;
                              final scale = raw.clamp(0.0, 1.0);
                              // Animasi "jatuh dari atas": mulai 28px di atas
                              // posisi akhir, turun mengikuti kurva elastis
                              // yang sama dengan animasi skala pin (sedikit
                              // memantul saat mendarat, bukan cuma muncul
                              // diam) — ini animasi tambahan yang diminta,
                              // dipasang di atas animasi pop/scale yang sudah
                              // ada sebelumnya, tanpa controller baru.
                              final dropOffset = (1 - raw) * -28;
                              return Transform.translate(
                                offset: Offset(0, dropOffset),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    // AKAR PERBAIKAN BUG: sebelumnya kedua
                                    // elemen (halo & pin) ditempel di DASAR
                                    // box lewat `Stack(alignment:
                                    // bottomCenter)`, padahal box itu sendiri
                                    // di-anchor lewat `alignment:
                                    // Alignment.bottomCenter` di level Marker
                                    // — kombinasi keduanya menghasilkan
                                    // pergeseran piksel tetap antara ujung pin
                                    // dan titik geografis asli. Sekarang:
                                    // `bottom: 46` menempatkan ujung pin PAS
                                    // di baris tengah box (y=46 dari 92) —
                                    // yaitu titik geografis sebenarnya, sesuai
                                    // anchor default Marker di atas.
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 46,
                                      child: Center(
                                        child: Transform.scale(
                                          scale: 0.55 + (0.45 * scale),
                                          child: Container(
                                            width: 54,
                                            height: 54,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primary.withOpacity(0.18 * scale),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 46,
                                      child: Center(
                                        child: Transform.scale(
                                          scale: 0.35 + (0.65 * scale),
                                          alignment: Alignment.bottomCenter,
                                          child: Container(
                                            width: 48,
                                            // Tinggi disamakan persis dengan
                                            // ukuran ikon (48, sebelumnya 58)
                                            // supaya tidak ada spasi kosong
                                            // tersembunyi yang ikut menggeser
                                            // posisi ujung ikon dari dasar
                                            // container-nya.
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.28),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(
                                              Icons.location_on_rounded,
                                              color: Colors.red,
                                              size: 48,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
              ),
              MarkerLayer(
                key: const ValueKey('earthquake_event_layer'),
                markers: activeDisasterLayer == DisasterLayerType.earthquakeEvents
                    ? earthquakeEvents.map((e) {
                        final size = (10 + e.magnitude.clamp(0.0, 8.0) * 3).clamp(12.0, 34.0);
                        return Marker(
                          point: LatLng(e.latitude, e.longitude),
                          width: size + 16,
                          height: size + 16,
                          child: GestureDetector(
                            onTap: () => _showEarthquakeDetail(context, e),
                            child: Container(
                              width: size,
                              height: size,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFFF7043).withOpacity(.72),
                                border: Border.all(color: Colors.white, width: 1.5),
                                boxShadow: const [BoxShadow(color: Color(0x88FF7043), blurRadius: 8)],
                              ),
                              alignment: Alignment.center,
                              child: Text(e.magnitude.toStringAsFixed(1), style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                            ),
                          ),
                        );
                      }).toList()
                    : const [],
              ),
              MarkerLayer(
                key: const ValueKey('tsunami_warning_layer'),
                markers: activeDisasterLayer == DisasterLayerType.tsunamiWarning
                    ? tsunamiWarnings.map((e) => Marker(
                          point: LatLng(e.latitude, e.longitude),
                          width: 52,
                          height: 52,
                          child: GestureDetector(
                            onTap: () => _showTsunamiWarningDetail(context, e),
                            child: const _TsunamiWarningMarker(),
                          ),
                        )).toList()
                    : const [],
              ),
              // Marker gunung api — SELALU ada di list ini (key tetap),
              // cuma daftar markernya kosong kalau layer Gunung Api tidak
              // aktif. Data lokasi REAL (lihat StaticVolcanoRepository);
              // status aktivitas ditandai jujur (lihat detail saat tap).
              MarkerLayer(
                key: const ValueKey('volcano_layer'),
                markers: activeDisasterLayer == DisasterLayerType.volcano
                    ? volcanoes
                        .map((v) => Marker(
                              point: LatLng(v.latitude, v.longitude),
                              width: 40,
                              height: 40,
                              child: GestureDetector(
                                onTap: () => _showVolcanoDetail(context, v),
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    border: Border.all(color: const Color(0xFFF44336), width: 2),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6),
                                    ],
                                  ),
                                  child: const Icon(Icons.terrain_rounded, color: Color(0xFFF44336), size: 22),
                                ),
                              ),
                            ))
                        .toList()
                    : const [],
              ),
              RichAttributionWidget(
                key: const ValueKey('attribution'),
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),



          // Global weather/environment engine: Mercator raster + streamlines.
          // Keep this WebView mounted while MapScreen is alive so switching
          // layers does not recreate the platform view. Open-Meteo remains
          // responsible for point/detail data shown elsewhere in the app.
          Positioned.fill(
            child: Visibility(
              visible: activeWeatherLayer != null,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: MercatorWeatherMap(
                viewCommand: _weatherViewCommand,
                layer: activeWeatherLayer ?? WeatherLayerType.wind,
                initialLatitude: _initialCenter.latitude,
                initialLongitude: _initialCenter.longitude,
                initialZoom: _initialZoom,
                onStatus: (value) {
                  if (!mounted || _weatherStatus == value) return;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted || _weatherStatus == value) return;
                    setState(() => _weatherStatus = value);
                  });
                },
                selectedPoint: selectedPoint,
                selectedLabel: ref.watch(selectedMapLocationLabelProvider),
                onPointReading: (_) {},
                onMapPointSelected: (point) {
                  ref.read(selectedMapLocationProvider.notifier).state = point;
                  ref.read(selectedMapLocationLabelProvider.notifier).state =
                      '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
                },
                onCameraChanged: (camera) {
                  if (_mapReady && mounted) {
                    try {
                      _mapController.move(
                        LatLng(camera.latitude, camera.longitude),
                        camera.zoom,
                      );
                    } catch (_) {}
                  }
                },
              ),
            ),
          ),

          if (activeWeatherLayer != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: SafeArea(
                top: false,
                child: WeatherLegend(layer: activeWeatherLayer),
              ),
            ),

          if (activeWeatherLayer != null && selectedPoint != null && !_locationDetailsOpen)
            Positioned(
              left: 14,
              right: 14,
              bottom: 76,
              child: SafeArea(
                top: false,
                child: WeatherPointCard(
                  point: selectedPoint,
                  layer: activeWeatherLayer,
                ),
              ),
            ),

          // Tombol detail lokasi tetap terlihat setelah search/cuaca aktif.
          // Menekannya membuka panel gempa + tsunami + cuaca secara halus,
          // tanpa menghilangkan search bar, tombol +, atau tombol layer.
          if (selectedPoint != null)
            Positioned(
              right: 16,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 140),
                  child: Material(
                    color: _locationDetailsOpen ? AppColors.primary : const Color(0xFFF7F9FB),
                    shape: const CircleBorder(),
                    elevation: 4,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _locationDetailsOpen = !_locationDetailsOpen),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Icon(
                          _locationDetailsOpen ? Icons.close_rounded : Icons.analytics_rounded,
                          color: _locationDetailsOpen ? Colors.white : const Color(0xFF1A2733),
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          if (activeDisasterLayer != null)
            Positioned(
              left: 14,
              right: 14,
              bottom: 18,
              child: SafeArea(
                top: false,
                child: AnimatedOpacity(
                  opacity: 1,
                  duration: const Duration(milliseconds: 250),
                  child: _DisasterStatsCard(
                    layer: activeDisasterLayer,
                    earthquakeCount: earthquakeEvents.length,
                    tsunamiCount: tsunamiWarnings.length,
                  ),
                ),
              ),
            ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LocationSearchBar(onPlaceSelected: _onPlaceSelected),
                  if (activeWeatherLayer != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: _WeatherStatusPill(layer: activeWeatherLayer, status: _weatherStatus),
                    ),
                  if (_tileLoadError)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: AppColors.riskWaspada, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Peta gagal dimuat. Periksa koneksi internet Anda.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: _reloadTiles,
                            child: const Text('Muat Ulang', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Tombol "kembali ke titik merah" — cuma muncul begitu titik
          // yang sedang dipilih keluar dari area peta yang terlihat
          // (lihat `_onMapEvent`). Diposisikan agak di atas tinggi
          // MINIMUM panel bawah (`minChildSize: 0.2`) supaya selalu bisa
          // dijangkau tanpa harus menutup panel itu dulu.
          if (selectedPoint != null && activeWeatherLayer == null)
            Positioned(
              right: 16,
              bottom: MediaQuery.sizeOf(context).height * 0.2 + 16,
              child: AnimatedScale(
                scale: _showRecenterButton ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: _showRecenterButton ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: !_showRecenterButton,
                    child: Material(
                      color: AppColors.surfaceElevated,
                      shape: const CircleBorder(),
                      elevation: 4,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _recenter,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.my_location_rounded, color: Colors.red, size: 22),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Tombol Layer Peta — DITAMBAHKAN, tidak mengubah widget peta/
          // search/marker/recenter yang sudah ada. Sengaja diposisikan di
          // KANAN ATAS (di bawah search bar), supaya tidak tumpang tindih
          // dengan kotak instruksi maupun tombol recenter yang sama-sama
          // memakai posisi bawah.
          Positioned(
            right: 16,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 78),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    MapDisasterButton(),
                    const SizedBox(width: 10),
                    MapLayerButton(),
                  ],
                ),
              ),
            ),
          ),

          // Layer selector is an in-map floating panel. No route, no
          // bottom-sheet navigation: tap Wind/SO2 and the field appears
          // directly behind the panel.
          if (ref.watch(mapLayerPanelVisibleProvider))
            Positioned(
              top: 132,
              right: 16,
              left: 16,
              child: SafeArea(
                top: false,
                child: const MapLayerSelectorPanel(),
              ),
            ),

          // Panduan bencana: hanya muncul setelah user memilih lokasi dan
          // mengaktifkan layer cuaca. Handle dapat dipindah bebas dan panel
          // dibuka dengan animasi halus.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: activeWeatherLayer == null || selectedPoint == null,
              child: DisasterGuideHandle(
                visible: activeWeatherLayer != null && selectedPoint != null,
              ),
            ),
          ),

          if (selectedPoint == null && activeWeatherLayer == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.touch_app_rounded, color: AppColors.primary, size: 18),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ketuk di mana saja pada peta, atau cari lokasi di atas, untuk melihat estimasi risiko gempa, tsunami, dan cuaca.',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (selectedPoint != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.sizeOf(context).height * 0.62,
              child: IgnorePointer(
                ignoring: !_locationDetailsOpen,
                child: AnimatedSlide(
                  offset: _locationDetailsOpen ? Offset.zero : const Offset(0, 1.08),
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _locationDetailsOpen ? 1 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                        boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 20, offset: Offset(0, -6))],
                      ),
                      child: SelectedLocationPanel(
                        point: selectedPoint,
                        onSearchAnother: _onPlaceSelected,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Legend + status pemuatan untuk layer cuaca/udara yang sedang aktif.
/// Widget baru murni tambahan — tidak menggantikan apa pun yang sudah
/// ada.
class _TsunamiWarningMarker extends StatefulWidget {
  const _TsunamiWarningMarker();
  @override
  State<_TsunamiWarningMarker> createState() => _TsunamiWarningMarkerState();
}

class _TsunamiWarningMarkerState extends State<_TsunamiWarningMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final scale = 0.86 + _controller.value * 0.14;
        return Transform.scale(
          scale: scale,
          child: Container(
            decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF29B6F6).withOpacity(.90), border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: const Color(0xFF29B6F6).withOpacity(.45), blurRadius: 12)]),
            child: const Icon(Icons.tsunami_rounded, color: Colors.white, size: 27),
          ),
        );
      },
    );
  }
}

class _DisasterStatsCard extends StatelessWidget {
  final DisasterLayerType layer;
  final int earthquakeCount;
  final int tsunamiCount;
  const _DisasterStatsCard({required this.layer, required this.earthquakeCount, required this.tsunamiCount});
  @override
  Widget build(BuildContext context) {
    final isTsunami = layer == DisasterLayerType.tsunamiWarning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface.withOpacity(.96), borderRadius: BorderRadius.circular(18), boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 14)]),
      child: Row(children: [
        Icon(isTsunami ? Icons.tsunami_rounded : Icons.vibration_rounded, color: isTsunami ? const Color(0xFF29B6F6) : const Color(0xFFFF9800)),
        const SizedBox(width: 10),
        Expanded(child: Text(isTsunami ? 'Peringatan tsunami aktif: $tsunamiCount' : 'Gempa global 24 jam: $earthquakeCount', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12.5, fontWeight: FontWeight.w700))),
        Text(isTsunami ? 'BMKG' : 'USGS', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _WeatherStatusPill extends StatefulWidget {
  final WeatherLayerType layer;
  final String status;
  const _WeatherStatusPill({required this.layer, required this.status});

  @override
  State<_WeatherStatusPill> createState() => _WeatherStatusPillState();
}

class _WeatherStatusPillState extends State<_WeatherStatusPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = weatherLayerConfigs[widget.layer];
    final busy = widget.status.toLowerCase().contains('memuat');
    final isError = widget.status.toLowerCase().contains('gagal');
    final color = isError
        ? const Color(0xFFFF5252)
        : (cfg?.legendColor ?? Colors.white);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xE91A2631),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(.10)),
        boxShadow: const [
          BoxShadow(color: Color(0x55000000), blurRadius: 14, offset: Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) {
              final scale = busy ? 0.88 + (_pulse.value * .22) : 1.0;
              return Transform.scale(
                scale: scale,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withOpacity(.16),
                  ),
                  child: Icon(
                    cfg?.icon ?? Icons.cloud_rounded,
                    color: color,
                    size: 19,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cfg?.title ?? 'Cuaca',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.10),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        cfg?.origin == DataOrigin.forecastModel ? 'MODEL' : 'LIVE',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${cfg?.source ?? 'Weather engine'} · ${busy ? widget.status : 'Global field aktif'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 9.5),
                ),
              ],
            ),
          ),
          if (busy)
            const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 1.8, color: Colors.white70),
            ),
        ],
      ),
    );
  }
}
