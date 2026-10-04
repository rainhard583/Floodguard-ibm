import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bmkg_latest_earthquake.dart';

/// Direct BMKG latest-earthquake feed. No Laravel dependency.
class BmkgLatestEarthquakeRepository {
  static const _url = 'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json';
  final http.Client _client;
  BmkgLatestEarthquakeRepository({http.Client? client}) : _client = client ?? http.Client();

  Future<BmkgLatestEarthquake> getLatest() async {
    final response = await _client.get(Uri.parse(_url)).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) throw Exception('Gempa BMKG HTTP ${response.statusCode}');

    final root = jsonDecode(response.body);
    final raw = root is Map ? root['Infogempa'] : null;
    final latest = raw is Map ? raw['gempa'] : null;
    if (latest is! Map) throw Exception('Data gempa BMKG belum tersedia');
    final data = Map<String, dynamic>.from(latest);

    final magnitude = _num(data['Magnitude']);
    if (magnitude == null) throw Exception('Magnitudo BMKG tidak valid');

    return BmkgLatestEarthquake.fromBmkgMap(data, magnitude: magnitude);
  }

  double? _num(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');

}
