import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bmkg_latest_earthquake.dart';

/// Recent BMKG earthquake feeds used for local monitoring.
///
/// `gempadirasakan` is useful for local impact; `gempaterkini` catches
/// stronger M5+ events even when a local felt report is not yet present.
class BmkgFeltEarthquakeRepository {
  static const _feltUrl =
      'https://data.bmkg.go.id/DataMKG/TEWS/gempadirasakan.json';
  static const _recentStrongUrl =
      'https://data.bmkg.go.id/DataMKG/TEWS/gempaterkini.json';

  final http.Client _client;

  BmkgFeltEarthquakeRepository({http.Client? client})
      : _client = client ?? http.Client();

  Future<List<BmkgLatestEarthquake>> getRecent() async {
    final responses = await Future.wait([
      _fetch(_feltUrl),
      _fetch(_recentStrongUrl),
    ]);

    final byId = <String, BmkgLatestEarthquake>{};
    for (final list in responses) {
      for (final event in list) {
        byId[event.eventId] = event;
      }
    }

    final result = byId.values.toList()
      ..sort((a, b) => b.eventTime.compareTo(a.eventTime));
    return List.unmodifiable(result);
  }

  Future<List<BmkgLatestEarthquake>> _fetch(String url) async {
    final response = await _client
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) {
      throw Exception('Gempa BMKG HTTP ${response.statusCode}');
    }

    final root = jsonDecode(response.body);
    final raw = root is Map ? root['Infogempa'] : null;
    final list = raw is Map ? raw['gempa'] : null;
    if (list is! List) {
      throw Exception('Daftar gempa BMKG belum tersedia');
    }

    final result = <BmkgLatestEarthquake>[];
    for (final item in list) {
      if (item is! Map) continue;
      final data = Map<String, dynamic>.from(item);
      final magnitude = _num(data['Magnitude']);
      if (magnitude == null) continue;
      result.add(
        BmkgLatestEarthquake.fromBmkgMap(data, magnitude: magnitude),
      );
    }
    return result;
  }

  double? _num(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse('$value');
}
