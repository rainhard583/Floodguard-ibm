import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/tsunami_warning_event.dart';

abstract class TsunamiWarningRepository {
  Future<List<TsunamiWarningEvent>> getRecentPotentialEvents();
}

class BmkgTsunamiWarningRepository implements TsunamiWarningRepository {
  static const _url = 'https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json';

  @override
  Future<List<TsunamiWarningEvent>> getRecentPotentialEvents() async {
    final response = await http.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Gagal memuat data tsunami BMKG (${response.statusCode})');
    }
    final root = jsonDecode(response.body) as Map<String, dynamic>;
    final items = ((root['Infogempa'] as Map<String, dynamic>?)?['gempa'] as List<dynamic>?) ?? const [];
    final result = <TsunamiWarningEvent>[];
    for (final raw in items) {
      final item = raw as Map<String, dynamic>;
      final potential = item['Potensi'] as String? ?? '';
      if (!potential.toLowerCase().contains('berpotensi tsunami')) continue;
      final coords = (item['Coordinates'] as String? ?? '').split(',');
      if (coords.length != 2) continue;
      final lat = double.tryParse(coords[0].trim());
      final lon = double.tryParse(coords[1].trim());
      final mag = double.tryParse(item['Magnitude'] as String? ?? '');
      final depth = double.tryParse((item['Kedalaman'] as String? ?? '').replaceAll(RegExp(r'[^0-9.]'), ''));
      final time = DateTime.tryParse(item['DateTime'] as String? ?? '');
      if (lat == null || lon == null || mag == null || depth == null || time == null) continue;
      result.add(TsunamiWarningEvent(
        id: '${item['DateTime']}-${item['Coordinates']}',
        latitude: lat,
        longitude: lon,
        magnitude: mag,
        depthKm: depth,
        region: item['Wilayah'] as String? ?? 'Indonesia',
        potential: potential,
        time: time,
      ));
    }
    return result;
  }
}
