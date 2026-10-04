import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../core/utils/geo.dart';
import '../models/disaster_risk_level.dart';
import '../models/earthquake_risk_model.dart';
import 'earthquake_risk_repository.dart';

/// Implementasi NYATA — memakai USGS Earthquake Catalog
/// (earthquake.usgs.gov), gratis, tanpa API key, mencakup seluruh dunia
/// termasuk Indonesia. Menggantikan [MockEarthquakeRiskRepository] yang
/// sebelumnya cuma hash dari koordinat.
///
/// PENTING (jujur soal batasannya): ini estimasi dari gempa yang SUDAH
/// TERJADI baru-baru ini di sekitar lokasi — bukan prediksi resmi BMKG.
/// Wilayah tanpa gempa besar tercatat baru-baru ini bisa saja tetap
/// berada di zona sesar aktif yang sedang "diam".
class UsgsEarthquakeRiskRepository implements EarthquakeRiskRepository {
  static const _baseUrl = 'https://earthquake.usgs.gov/fdsnws/event/1/query';
  static const _searchRadiusKm = 300.0;
  static const _lookbackDays = 90;

  @override
  Future<EarthquakeRisk?> getRiskForLocation({
    required double latitude,
    required double longitude,
  }) async {
    final now = DateTime.now().toUtc();
    final start = now.subtract(const Duration(days: 365));

    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'format': 'geojson',
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'maxradiuskm': _searchRadiusKm.toString(),
      'minmagnitude': '4.0',
      'starttime': start.toIso8601String(),
      'endtime': now.toIso8601String(),
      'orderby': 'time',
      'limit': '200',
    });

    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data gempa (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final features = (json['features'] as List<dynamic>?) ?? const [];

    if (features.isEmpty) {
      return EarthquakeRisk(
        level: DisasterRiskLevel.sangatRendah,
        distanceKm: _searchRadiusKm,
        description: 'Tidak ada gempa M≥4.0 tercatat dalam radius '
            '${_searchRadiusKm.round()} km selama 1 tahun terakhir. '
            'Ini adalah indikator aktivitas historis, bukan prediksi gempa.',
        updatedAt: DateTime.now(),
      );
    }

    // Jangan menentukan level dari satu gempa terbesar yang jauh.
    // Nilai dibuat dari kontribusi beberapa gempa, dengan peluruhan jarak
    // dan waktu. Ini mencegah kasus seperti Jatimakmur menjadi 5/5 hanya
    // karena satu M6.x yang berjarak ratusan kilometer.
    double activityScore = 0;
    double nearestDistanceKm = _searchRadiusKm;
    double nearestMagnitude = 0;
    String nearestPlace = 'lokasi tidak diketahui';
    double strongestRelevantMagnitude = 0;
    double strongestRelevantDistance = _searchRadiusKm;
    String strongestRelevantPlace = 'lokasi tidak diketahui';

    for (final feature in features) {
      final props = feature['properties'] as Map<String, dynamic>;
      final geometry = feature['geometry'] as Map<String, dynamic>;
      final coords = geometry['coordinates'] as List<dynamic>;
      final quakeLat = (coords[1] as num).toDouble();
      final quakeLon = (coords[0] as num).toDouble();
      final magnitude = (props['mag'] as num?)?.toDouble() ?? 0;
      final distanceKm = haversineDistanceKm(latitude, longitude, quakeLat, quakeLon);
      final rawTime = props['time'];
      final eventTime = rawTime is num
          ? DateTime.fromMillisecondsSinceEpoch(rawTime.toInt(), isUtc: true)
          : now;
      final ageDays = now.difference(eventTime).inHours.clamp(0, 365 * 24) / 24.0;

      if (distanceKm < nearestDistanceKm) {
        nearestDistanceKm = distanceKm;
        nearestMagnitude = magnitude;
        nearestPlace = (props['place'] as String?) ?? nearestPlace;
      }

      // Magnitude scale is logarithmic; distance and age damp the effect.
      final magnitudeWeight = pow10(magnitude - 4.0);
      final distanceWeight = exp(-distanceKm / 70.0);
      final timeWeight = exp(-ageDays / 180.0);
      activityScore += magnitudeWeight * distanceWeight * timeWeight;

      if (magnitude >= strongestRelevantMagnitude && distanceKm < 200) {
        strongestRelevantMagnitude = magnitude;
        strongestRelevantDistance = distanceKm;
        strongestRelevantPlace = (props['place'] as String?) ?? strongestRelevantPlace;
      }
    }

    final level = _levelFor(
      activityScore: activityScore,
      nearestDistanceKm: nearestDistanceKm,
      nearestMagnitude: nearestMagnitude,
    );

    final relevantMagnitude = strongestRelevantMagnitude > 0
        ? strongestRelevantMagnitude
        : nearestMagnitude;
    final relevantDistance = strongestRelevantMagnitude > 0
        ? strongestRelevantDistance
        : nearestDistanceKm;
    final relevantPlace = strongestRelevantMagnitude > 0
        ? strongestRelevantPlace
        : nearestPlace;

    return EarthquakeRisk(
      level: level,
      distanceKm: nearestDistanceKm,
      description: 'Aktivitas gempa historis 1 tahun: ${level.label}. '
          'Gempa terdekat M${nearestMagnitude.toStringAsFixed(1)} berjarak '
          '±${nearestDistanceKm.toStringAsFixed(0)} km ($nearestPlace). '
          'Gempa signifikan terdekat yang diperhitungkan: M${relevantMagnitude.toStringAsFixed(1)} '
          '±${relevantDistance.toStringAsFixed(0)} km ($relevantPlace). '
          'Bukan prediksi kejadian gempa.',
      updatedAt: DateTime.now(),
    );
  }

  DisasterRiskLevel _levelFor({
    required double activityScore,
    required double nearestDistanceKm,
    required double nearestMagnitude,
  }) {
    // Hard gates untuk event yang sangat dekat. Satu event jauh tidak dapat
    // langsung menghasilkan 4/5 atau 5/5.
    if (nearestMagnitude >= 6.5 && nearestDistanceKm <= 40) {
      return DisasterRiskLevel.sangatTinggi;
    }
    if (nearestMagnitude >= 6.0 && nearestDistanceKm <= 60) {
      return DisasterRiskLevel.tinggi;
    }
    if (nearestMagnitude >= 5.5 && nearestDistanceKm <= 80) {
      return DisasterRiskLevel.sedang;
    }
    if (nearestMagnitude >= 5.0 && nearestDistanceKm <= 100) {
      return DisasterRiskLevel.rendah;
    }

    if (activityScore >= 20) return DisasterRiskLevel.tinggi;
    if (activityScore >= 8) return DisasterRiskLevel.sedang;
    if (activityScore >= 2.5) return DisasterRiskLevel.rendah;
    return DisasterRiskLevel.sangatRendah;
  }
}

// 10^x tanpa import math besar; x pada rentang kecil di sini.
double pow10(double x) => pow(10, x).toDouble();
