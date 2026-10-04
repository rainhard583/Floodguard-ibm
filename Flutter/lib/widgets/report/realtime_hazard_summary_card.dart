import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/bmkg_latest_earthquake_provider.dart';
import '../../models/bmkg_latest_earthquake.dart';
import '../../models/earthquake_event_model.dart';
import '../../providers/usgs_latest_earthquake_provider.dart';

/// Ringkasan sumber live/near-live FloodGuard.
/// Gempa selalu menggunakan feed nasional BMKG, bukan radius dari lokasi HP.
class RealtimeHazardSummaryCard extends ConsumerWidget {
  final Map<String, dynamic> data;

  const RealtimeHazardSummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = (data['weather'] as Map?)?.cast<String, dynamic>() ?? {};
    final fallbackCurrent = data['forecast'] is Map
        ? ((data['forecast'] as Map)['current'] as Map?)?.cast<String, dynamic>() ?? {}
        : <String, dynamic>{};
    final warning = (data['bmkg'] as Map?)?.cast<String, dynamic>() ?? {};
    final volcano = (data['magma'] as Map?)?.cast<String, dynamic>() ?? {};
    final earthquakeAsync = ref.watch(bmkgLatestEarthquakeProvider);
    final globalEarthquakeAsync = ref.watch(usgsLatestEarthquakeProvider);
    final backendEarthquake = _extractBackendEarthquake(data, warning);

    final rows = <Widget>[
      _row(
        Icons.thermostat_rounded,
        'Suhu',
        _text(_first(weather, fallbackCurrent, ['temperature_c', 'temp_c', 'temperature', 'temp']), '°C'),
        weather['source']?.toString() ?? data['provider']?.toString() ?? 'WeatherAPI',
      ),
      _row(
        Icons.water_drop_rounded,
        'Hujan',
        _text(_first(weather, fallbackCurrent, ['precip_mm', 'precipitation', 'rain_mm']), ' mm'),
        weather['source']?.toString() ?? data['provider']?.toString() ?? 'WeatherAPI',
      ),
      _row(
        Icons.warning_amber_rounded,
        'Peringatan BMKG',
        _countText(warning['nowcast_count']),
        'BMKG Nowcast',
      ),
      _earthquakeRow(earthquakeAsync, backendEarthquake),
      _globalEarthquakeRow(globalEarthquakeAsync),
      _row(
        Icons.local_fire_department_rounded,
        'Gunung api',
        _countText(volcano['elevated_count']),
        'MAGMA Indonesia',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF17212B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bolt_rounded, color: Colors.amber, size: 18),
              SizedBox(width: 8),
              Text('Data Terkini & Peringatan',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          ...rows,
          if (volcano['landslide_available'] == false)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Gerakan tanah/longsor: endpoint publik resmi MAGMA belum tersedia di konfigurasi ini, jadi FloodGuard tidak mengarang status.',
                style: TextStyle(color: Colors.white60, fontSize: 10.5, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }

  Widget _globalEarthquakeRow(AsyncValue<EarthquakeEvent?> live) {
    final quake = live.valueOrNull;
    if (quake == null) {
      return _row(Icons.public_rounded, 'Gempa global', 'Memuat…', 'USGS');
    }
    final mmi = quake.mmi == null ? '' : 'MMI ${quake.mmi!.toStringAsFixed(1)}';
    final detail = mmi.isNotEmpty ? mmi : quake.place;
    return _row(
      Icons.public_rounded,
      'Gempa global',
      'M${quake.magnitude.toStringAsFixed(1)}',
      detail,
    );
  }

  Widget _earthquakeRow(
    AsyncValue<BmkgLatestEarthquake> live,
    Map<String, dynamic>? backend,
  ) {
    final quake = live.valueOrNull;
    if (quake != null) {
      final mmi = (quake.felt ?? '').trim();
      final detail = mmi.isNotEmpty ? 'MMI $mmi' : 'BMKG';
      return _row(Icons.public_rounded, 'Gempa terbaru', quake.displayMagnitude, detail);
    }

    if (backend != null) {
      final magnitude = _number(backend['Magnitude'] ?? backend['magnitude']);
      final felt = (backend['Dirasakan'] ?? backend['felt'] ?? '').toString().trim();
      final value = magnitude == null ? 'Tersedia' : 'M${magnitude.toStringAsFixed(1)} SR';
      return _row(Icons.public_rounded, 'Gempa terbaru', value, felt.isEmpty ? 'BMKG' : 'MMI $felt');
    }

    return _row(Icons.public_rounded, 'Gempa terbaru', 'Memuat…', 'BMKG');
  }

  Map<String, dynamic>? _extractBackendEarthquake(
    Map<String, dynamic> root,
    Map<String, dynamic> warning,
  ) {
    final candidates = [
      root['earthquake'],
      warning['earthquake'],
    ];
    for (final item in candidates) {
      if (item is Map) return item.cast<String, dynamic>();
    }
    return null;
  }

  Widget _row(IconData icon, String label, String value, String source) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 17),
          const SizedBox(width: 9),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(source,
              style: const TextStyle(color: Colors.white38, fontSize: 9.5)),
        ],
      ),
    );
  }

  dynamic _first(Map<String, dynamic> primary, Map<String, dynamic> fallback, List<String> keys) {
    for (final key in keys) {
      final value = primary[key];
      if (value != null) return value;
    }
    for (final key in keys) {
      final value = fallback[key];
      if (value != null) return value;
    }
    return null;
  }

  String _text(dynamic v, String suffix) => v == null ? '—' : '${v.toString()}$suffix';

  String _countText(dynamic v) => v == null ? '—' : '$v aktif';

  double? _number(dynamic value) => double.tryParse(value?.toString() ?? '');
}
