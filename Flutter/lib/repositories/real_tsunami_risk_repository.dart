import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/utils/geo.dart';
import '../models/disaster_risk_level.dart';
import '../models/tsunami_risk_model.dart';
import 'tsunami_risk_repository.dart';

/// Implementasi berbasis DATA NYATA: memperkirakan JARAK KE GARIS PANTAI
/// terdekat dari elevasi tanah sungguhan (Open-Meteo Elevation API,
/// Copernicus DEM 90m) di banyak titik di sekeliling lokasi, lalu
/// menggabungkannya dengan gempa besar (M≥7) yang tercatat dekat pantai
/// tsb (USGS Earthquake Catalog) sebagai modifier sekunder.
///
/// PERBAIKAN BUG "tsunami ketinggian/tidak akurat untuk lokasi pedalaman":
/// versi sebelumnya menentukan level HANYA dari elevasi titik itu sendiri
/// + "ada gempa M≥6.5 dalam radius 300 km dalam 5 tahun terakhir" — tanpa
/// pernah mengecek apakah lokasinya dekat laut sama sekali. Karena
/// Indonesia sangat aktif secara seismik, syarat "ada gempa M≥6.5 dalam
/// 300 km/5 tahun" HAMPIR SELALU terpenuhi di mana pun di Indonesia,
/// sehingga level ter-"bump up" ke Sedang/Tinggi bahkan untuk lokasi yang
/// jauh di pedalaman (mis. Jatimakmur, Bekasi — dataran rendah tapi
/// puluhan km dari pantai). Elevasi rendah SENDIRI tidak berarti dekat
/// laut — banyak dataran rendah ada jauh di pedalaman.
///
/// SEKARANG: elevasi diambil di banyak titik memancar ke 8 arah mata
/// angin (radius 10/20/35/50 km) DALAM SATU PANGGILAN API (Open-Meteo
/// mendukung hingga 100 titik per request), untuk mencari titik terdekat
/// yang elevasinya ~0 (indikasi laut/pantai). Jarak ke titik itulah yang
/// jadi sinyal utama, bukan cuma elevasi lokasi itu sendiri. Kalau tidak
/// ditemukan titik seperti itu dalam radius 50 km ke arah manapun, lokasi
/// dianggap jauh dari pantai dan levelnya Sangat Rendah — TIDAK PEDULI
/// elevasi lokasinya sendiri serendah apa atau ada gempa besar di
/// dekatnya, karena tsunami tidak bisa menjangkau daratan yang jauh dari
/// laut.
class RealTsunamiRiskRepository implements TsunamiRiskRepository {
  static const _elevationUrl = 'https://api.open-meteo.com/v1/elevation';
  static const _quakeUrl = 'https://earthquake.usgs.gov/fdsnws/event/1/query';
  static const _sampleRadiiKm = [10.0, 20.0, 35.0, 50.0];
  static const _sampleBearings = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0];
  static const _seaLevelThresholdM = 2.0;
  static const _lookbackYears = 5;

  @override
  Future<TsunamiRisk?> getRiskForLocation({
    required double latitude,
    required double longitude,
  }) async {
    final elevations = await _fetchElevationGrid(latitude, longitude);
    final targetElevation = elevations.first;
    final coastDistanceKm = _nearestCoastDistanceKm(elevations.skip(1).toList());

    final level = await _computeLevel(
      latitude: latitude,
      longitude: longitude,
      targetElevation: targetElevation,
      coastDistanceKm: coastDistanceKm,
    );

    final description = coastDistanceKm == null
        ? 'Tidak ditemukan indikasi garis pantai dalam radius ${_sampleRadiiKm.last.round()} km dari lokasi ini — '
            'diperkirakan cukup jauh di pedalaman. Elevasi lokasi ini sekitar ${targetElevation.toStringAsFixed(0)} mdpl.'
        : '±${coastDistanceKm.toStringAsFixed(0)} km dari garis pantai terdekat (perkiraan). '
            'Elevasi lokasi ini sekitar ${targetElevation.toStringAsFixed(0)} mdpl.';

    return TsunamiRisk(
      level: level,
      distanceKm: coastDistanceKm ?? _sampleRadiiKm.last,
      description: description,
      updatedAt: DateTime.now(),
    );
  }

  Future<DisasterRiskLevel> _computeLevel({
    required double latitude,
    required double longitude,
    required double targetElevation,
    required double? coastDistanceKm,
  }) async {
    // Jauh dari pantai (atau tidak ada indikasi laut sama sekali dalam
    // radius sampel) -> tsunami praktis tidak relevan, berapa pun
    // elevasi lokal atau riwayat gempa di sekitarnya.
    if (coastDistanceKm == null) return DisasterRiskLevel.sangatRendah;

    DisasterRiskLevel level;
    if (coastDistanceKm < 5) {
      level = DisasterRiskLevel.tinggi;
    } else if (coastDistanceKm < 15) {
      level = DisasterRiskLevel.sedang;
    } else if (coastDistanceKm < 35) {
      level = DisasterRiskLevel.rendah;
    } else {
      level = DisasterRiskLevel.sangatRendah;
    }

    // Dataran sangat rendah DAN dekat pantai -> genangan air pasang/rob
    // saja sudah relevan, jadi pastikan levelnya minimal "Tinggi".
    if (targetElevation <= 3 && coastDistanceKm < 15 && level.index < DisasterRiskLevel.tinggi.index) {
      level = DisasterRiskLevel.tinggi;
    }

    // Modifier gempa: HANYA dipertimbangkan kalau lokasi memang plausibel
    // dekat pantai (<35 km) — supaya tidak lagi menaikkan level untuk
    // lokasi pedalaman seperti bug sebelumnya. Ambang dinaikkan ke M≥7
    // (bukan M≥6.5) dan radius diperketat ke 150 km (bukan 300 km) supaya
    // modifier ini benar-benar menandakan gempa besar yang relevan, bukan
    // gempa mana pun yang kebetulan pernah tercatat di Indonesia.
    if (coastDistanceKm < 35) {
      final bigQuakeNearby = await _hasBigQuakeNearby(latitude, longitude);
      if (bigQuakeNearby && level.index < DisasterRiskLevel.values.length - 1) {
        level = DisasterRiskLevel.values[level.index + 1];
      }
    }

    return level;
  }

  /// Cari titik tersampel terdekat yang elevasinya ~laut (≤
  /// [_seaLevelThresholdM]). `null` berarti tidak ada titik seperti itu
  /// dalam radius sampel manapun (lokasi diperkirakan jauh dari pantai).
  ///
  /// [sampleElevations] harus dalam urutan yang SAMA dengan urutan titik
  /// yang diminta di [_fetchElevationGrid] (per arah mata angin, radius
  /// menaik) — supaya index di sini match dengan radius yang benar.
  double? _nearestCoastDistanceKm(List<double> sampleElevations) {
    double? nearest;
    var index = 0;
    for (var b = 0; b < _sampleBearings.length; b++) {
      for (var r = 0; r < _sampleRadiiKm.length; r++) {
        if (index >= sampleElevations.length) return nearest;
        final elevation = sampleElevations[index];
        final radius = _sampleRadiiKm[r];
        if (elevation <= _seaLevelThresholdM && (nearest == null || radius < nearest)) {
          nearest = radius;
        }
        index++;
      }
    }
    return nearest;
  }

  Future<List<double>> _fetchElevationGrid(double latitude, double longitude) async {
    final latitudes = <double>[latitude];
    final longitudes = <double>[longitude];
    for (final bearing in _sampleBearings) {
      for (final radius in _sampleRadiiKm) {
        final point = destinationPoint(
          latitude: latitude,
          longitude: longitude,
          bearingDeg: bearing,
          distanceKm: radius,
        );
        latitudes.add(point.latitude);
        longitudes.add(point.longitude);
      }
    }

    final uri = Uri.parse(_elevationUrl).replace(queryParameters: {
      'latitude': latitudes.map((v) => v.toStringAsFixed(5)).join(','),
      'longitude': longitudes.map((v) => v.toStringAsFixed(5)).join(','),
    });
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data elevasi (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final elevations = (json['elevation'] as List<dynamic>?) ?? const [];
    if (elevations.isEmpty) {
      throw Exception('Data elevasi kosong dari server.');
    }
    return elevations.map((e) => (e as num).toDouble()).toList();
  }

  /// `true` kalau ada gempa M≥7 tercatat dalam radius 150 km selama
  /// [_lookbackYears] tahun terakhir. Gagal memanggil API dianggap
  /// `false` (modifier ini bersifat tambahan, bukan syarat utama).
  Future<bool> _hasBigQuakeNearby(double lat, double lon) async {
    final now = DateTime.now().toUtc();
    final start = now.subtract(Duration(days: 365 * _lookbackYears));

    final uri = Uri.parse(_quakeUrl).replace(queryParameters: {
      'format': 'geojson',
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'maxradiuskm': '150',
      'minmagnitude': '7',
      'starttime': start.toIso8601String().substring(0, 10),
      'endtime': now.toIso8601String().substring(0, 10),
      'limit': '1',
    });

    try {
      final response = await http.get(uri);
      if (response.statusCode != 200) return false;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final features = (json['features'] as List<dynamic>?) ?? const [];
      return features.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
