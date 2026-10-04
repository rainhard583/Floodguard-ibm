import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../core/utils/geo.dart';
import '../models/disaster_risk_level.dart';
import '../models/earthquake_risk_model.dart';
import 'earthquake_risk_repository.dart';

/// Data gempa Indonesia terbaru dari BMKG. Feed BMKG diperbarui setiap ada
/// peristiwa; level InaRISK tetap menjadi level bahaya resmi di Risk Engine.
class BmkgEarthquakeRiskRepository implements EarthquakeRiskRepository {
  static const _url = 'https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json';

  @override
  Future<EarthquakeRisk?> getRiskForLocation({required double latitude, required double longitude}) async {
    final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('BMKG HTTP ${response.statusCode}');
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = ((root['Infogempa'] as Map<String, dynamic>?)?['gempa'] as List<dynamic>?) ?? const [];
    if (raw.isEmpty) return null;

    double nearest = double.infinity;
    double nearestMag = 0;
    String nearestPlace = 'lokasi tidak diketahui';
    DateTime? nearestTime;
    var nearbyCount = 0;

    for (final item in raw) {
      final data = item as Map<String, dynamic>;
      final coords = (data['Coordinates'] as String? ?? '').split(',');
      if (coords.length != 2) continue;
      final lat = double.tryParse(coords[0].trim());
      final lon = double.tryParse(coords[1].trim());
      final mag = double.tryParse(data['Magnitude'] as String? ?? '');
      final time = DateTime.tryParse(data['DateTime'] as String? ?? '');
      if (lat == null || lon == null || mag == null || time == null) continue;
      final distance = haversineDistanceKm(latitude, longitude, lat, lon);
      if (distance < nearest) {
        nearest = distance;
        nearestMag = mag;
        nearestPlace = data['Wilayah'] as String? ?? nearestPlace;
        nearestTime = time;
      }
      if (distance <= 300) nearbyCount++;
    }

    if (!nearest.isFinite) return null;

    final level = _level(nearestMag, nearest);
    final age = nearestTime == null ? '' : ' • ${_age(nearestTime)}';
    return EarthquakeRisk(
      level: level,
      distanceKm: nearest,
      description: 'BMKG terbaru: M${nearestMag.toStringAsFixed(1)} ±${nearest.toStringAsFixed(0)} km, $nearestPlace$age. $nearbyCount kejadian M5+ dalam daftar BMKG terbaru berada dalam radius 300 km. Ini ringkasan kejadian, bukan prediksi.',
      updatedAt: DateTime.now(),
    );
  }

  DisasterRiskLevel _level(double magnitude, double distanceKm) {
    if (magnitude >= 6.5 && distanceKm <= 50) return DisasterRiskLevel.sangatTinggi;
    if (magnitude >= 6.0 && distanceKm <= 75) return DisasterRiskLevel.tinggi;
    if (magnitude >= 5.5 && distanceKm <= 100) return DisasterRiskLevel.sedang;
    if (magnitude >= 5.0 && distanceKm <= 150) return DisasterRiskLevel.rendah;
    return DisasterRiskLevel.sangatRendah;
  }

  String _age(DateTime time) {
    final diff = DateTime.now().toUtc().difference(time.toUtc());
    if (diff.inHours < 1) return '${math.max(1, diff.inMinutes)} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    return '${diff.inDays} hari lalu';
  }
}
