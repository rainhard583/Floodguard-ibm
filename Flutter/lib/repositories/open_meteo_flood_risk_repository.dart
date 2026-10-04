import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/flood_risk_model.dart';
import 'flood_risk_repository.dart';

/// Implementasi berbasis DATA NYATA — bukan mesin/model hidrologi resmi,
/// tapi estimasi yang digerakkan curah hujan sungguhan (hari ini +
/// prakiraan 24 jam ke depan) dari Open-Meteo Forecast API, alih-alih
/// angka acak per-koordinat seperti [MockFloodRiskRepository] sebelumnya.
///
/// PENTING (jujur soal batasannya): ini BUKAN pengganti sistem resmi
/// BMKG/BNPB — topografi, drainase, dan riwayat banjir lokal TIDAK
/// diperhitungkan. Skornya murni dari intensitas hujan, jadi paling
/// akurat untuk pertanyaan "apakah sedang/akan hujan deras di sini",
/// bukan "apakah daerah ini akan tergenang" (itu butuh data elevasi &
/// drainase yang jauh lebih detail — pekerjaan Phase 6 yang sebenarnya).
class OpenMeteoFloodRiskRepository implements FloodRiskRepository {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  @override
  Future<FloodRisk?> getCurrentFloodRisk() {
    return getFloodRiskForLocation(latitude: -6.2088, longitude: 106.8456);
  }

  @override
  Future<FloodRisk?> getFloodRiskForLocation({
    required double latitude,
    required double longitude,
  }) async {
    final rain = await _fetchRainfall(latitude, longitude);

    // Skor 0-100 dari kombinasi curah hujan hari ini (bobot lebih besar,
    // karena sudah terjadi) & potensi hujan 24 jam ke depan. Ambang batas
    // kasar mengikuti kategori intensitas hujan BMKG (ringan/sedang/
    // lebat/sangat lebat, dalam mm/hari).
    final todayScore = _rainToScore(rain.todayMm);
    final forecastScore = _rainToScore(rain.next24hMm);
    final score = (todayScore * 0.6 + forecastScore * 0.4).round().clamp(0, 100);

    final FloodRiskLevel level;
    final String description;
    if (score < 30) {
      level = FloodRiskLevel.aman;
      description = 'Curah hujan hari ini ${rain.todayMm.toStringAsFixed(1)} mm, '
          'potensi 24 jam ke depan ${rain.next24hMm.toStringAsFixed(1)} mm. Kondisi relatif aman.';
    } else if (score < 55) {
      level = FloodRiskLevel.waspada;
      description = 'Curah hujan hari ini ${rain.todayMm.toStringAsFixed(1)} mm, dengan potensi '
          'tambahan ${rain.next24hMm.toStringAsFixed(1)} mm dalam 24 jam ke depan. Tetap waspada, '
          'terutama di area rendah/dekat aliran air.';
    } else if (score < 80) {
      level = FloodRiskLevel.siaga;
      description = 'Curah hujan cukup tinggi (${rain.todayMm.toStringAsFixed(1)} mm hari ini, '
          'potensi +${rain.next24hMm.toStringAsFixed(1)} mm ke depan). Siaga terhadap genangan, '
          'siapkan rencana evakuasi.';
    } else {
      level = FloodRiskLevel.bahaya;
      description = 'Curah hujan sangat tinggi (${rain.todayMm.toStringAsFixed(1)} mm hari ini, '
          'potensi +${rain.next24hMm.toStringAsFixed(1)} mm ke depan). Risiko genangan/banjir tinggi — '
          'segera pindah ke tempat lebih tinggi bila perlu.';
    }

    return FloodRisk(level: level, score: score, description: description, updatedAt: DateTime.now());
  }

  /// Kategori curah hujan (mm/hari) ala BMKG, diskalakan ke 0-100:
  /// 0 mm → 0, ringan (~5-20) → naik landai, sedang (20-50) → naik lebih
  /// tajam, lebat (50-100) → tinggi, sangat lebat (100+) → mendekati 100.
  double _rainToScore(double mm) {
    if (mm <= 0) return 0;
    if (mm <= 20) return (mm / 20) * 35; // 0-35
    if (mm <= 50) return 35 + ((mm - 20) / 30) * 30; // 35-65
    if (mm <= 100) return 65 + ((mm - 50) / 50) * 25; // 65-90
    return (90 + ((mm - 100) / 50) * 10).clamp(0, 100); // 90-100
  }

  Future<_RainSummary> _fetchRainfall(double lat, double lon) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'daily': 'precipitation_sum',
      'hourly': 'precipitation',
      'forecast_days': '2',
      'past_days': '1',
      'timezone': 'auto',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data curah hujan (${response.statusCode})');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    final daily = json['daily'] as Map<String, dynamic>?;
    final dailyTimes = (daily?['time'] as List<dynamic>?)?.cast<String>() ?? const [];
    final dailySums = (daily?['precipitation_sum'] as List<dynamic>?)?.cast<num>() ?? const [];
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    final todayIndex = dailyTimes.indexOf(todayStr);
    final todayMm = (todayIndex != -1 && todayIndex < dailySums.length)
        ? dailySums[todayIndex].toDouble()
        : (dailySums.isNotEmpty ? dailySums.last.toDouble() : 0.0);

    final hourly = json['hourly'] as Map<String, dynamic>?;
    final hourlyTimes = (hourly?['time'] as List<dynamic>?)?.cast<String>() ?? const [];
    final hourlyPrecip = (hourly?['precipitation'] as List<dynamic>?)?.cast<num>() ?? const [];
    final now = DateTime.now();
    var next24hMm = 0.0;
    for (var i = 0; i < hourlyTimes.length && i < hourlyPrecip.length; i++) {
      final t = DateTime.tryParse(hourlyTimes[i]);
      if (t == null) continue;
      if (!t.isBefore(now) && t.isBefore(now.add(const Duration(hours: 24)))) {
        next24hMm += hourlyPrecip[i].toDouble();
      }
    }

    return _RainSummary(todayMm: todayMm, next24hMm: next24hMm);
  }
}

class _RainSummary {
  final double todayMm;
  final double next24hMm;
  const _RainSummary({required this.todayMm, required this.next24hMm});
}
