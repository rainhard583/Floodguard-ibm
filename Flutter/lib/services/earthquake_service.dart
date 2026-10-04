import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/earthquake.dart';

class EarthquakeOverview {
  final List<Earthquake> global;
  final Earthquake? latestRelevant;
  final Earthquake? nearest;
  final List<Map<String,dynamic>> localSources;
  const EarthquakeOverview({this.global=const [],this.latestRelevant,this.nearest,this.localSources=const []});
}

/// Direct disaster feeds. These do not depend on Laravel being reachable.
/// Indonesia: BMKG official latest earthquake feed.
/// Global: USGS real-time GeoJSON feed.
class EarthquakeService {
  static const _bmkgUrl = 'https://data.bmkg.go.id/DataMKG/TEWS/autogempa.json';
  static const _usgsUrl = 'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_day.geojson';

  final http.Client _client;
  EarthquakeService({http.Client? client}) : _client = client ?? http.Client();

  Future<EarthquakeOverview> getOverview({double? latitude,double? longitude,double radiusKm=500}) async {
    final results = await Future.wait([
      _fetchBmkg(),
      _fetchUsgs(),
    ]);

    final bmkg = results[0];
    final usgs = results[1];
    final global = <Earthquake>[];
    if (usgs is List<Earthquake>) global.addAll(usgs);
    if (bmkg is List<Earthquake>) global.addAll(bmkg);
    global.sort((a,b)=>(b.timeEpoch ?? 0).compareTo(a.timeEpoch ?? 0));

    Earthquake? nearest;
    Earthquake? latestRelevant;
    if (latitude != null && longitude != null) {
      final candidates = global.where((e) => e.latitude != null && e.longitude != null).toList();
      candidates.sort((a,b) => _distanceKm(latitude,longitude,a.latitude!,a.longitude!).compareTo(_distanceKm(latitude,longitude,b.latitude!,b.longitude!)));
      if (candidates.isNotEmpty) nearest = candidates.first;
      final relevant = candidates.where((e) => _distanceKm(latitude,longitude,e.latitude!,e.longitude!) <= radiusKm).toList();
      relevant.sort((a,b)=>(b.timeEpoch ?? 0).compareTo(a.timeEpoch ?? 0));
      if (relevant.isNotEmpty) latestRelevant = relevant.first;
    } else if (global.isNotEmpty) {
      latestRelevant = global.first;
    }

    final sources = <Map<String,dynamic>>[
      {'source':'BMKG','available': bmkg is List<Earthquake> && bmkg.isNotEmpty, 'count': bmkg is List<Earthquake> ? bmkg.length : 0},
      {'source':'USGS','available': usgs is List<Earthquake> && usgs.isNotEmpty, 'count': usgs is List<Earthquake> ? usgs.length : 0},
      {'source':'JMA / Japan','available': false, 'note':'source cadangan regional; USGS sudah mencakup kejadian global'},
      {'source':'GeoNet / New Zealand','available': false, 'note':'source cadangan regional; USGS sudah mencakup kejadian global'},
      {'source':'GDACS','available': false, 'note':'lapisan peringatan bencana global untuk fase berikutnya'},
    ];

    if (global.isEmpty) throw Exception('Data gempa belum tersedia dari BMKG maupun USGS.');
    return EarthquakeOverview(global: global, latestRelevant: latestRelevant, nearest: nearest, localSources: sources);
  }

  Future<List<Earthquake>> _fetchBmkg() async {
    try {
      final r = await _client.get(Uri.parse(_bmkgUrl)).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return const [];
      final root = jsonDecode(r.body);
      final raw = root is Map ? root['Infogempa'] : null;
      final item = raw is Map ? raw['gempa'] : null;
      if (item is! Map) return const [];
      final m = _num(item['Magnitude']);
      final depth = _depth(item['Kedalaman']);
      final coords = '${item['Coordinates'] ?? ''}'.split(',');
      final lat = coords.length > 0 ? double.tryParse(coords[0].trim()) : null;
      final lon = coords.length > 1 ? double.tryParse(coords[1].trim()) : null;
      final epoch = _parseBmkgTime(item['Tanggal']?.toString(), item['Jam']?.toString());
      return [Earthquake(
        id: 'BMKG-${item['Tanggal']}-${item['Jam']}-${item['Magnitude']}',
        source: 'BMKG',
        place: item['Wilayah']?.toString() ?? 'Indonesia',
        magnitude: m,
        latitude: lat,
        longitude: lon,
        depthKm: depth,
        timeEpoch: epoch,
        magType: 'M',
        tsunami: item['Potensi'],
      )];
    } catch (_) { return const []; }
  }

  Future<List<Earthquake>> _fetchUsgs() async {
    try {
      final r = await _client.get(Uri.parse(_usgsUrl)).timeout(const Duration(seconds: 12));
      if (r.statusCode != 200) return const [];
      final root = jsonDecode(r.body);
      final features = root is Map && root['features'] is List ? root['features'] as List : const [];
      final out = <Earthquake>[];
      for (final f in features) {
        if (f is! Map) continue;
        final p = f['properties'];
        final g = f['geometry'];
        if (p is! Map || g is! Map || g['coordinates'] is! List) continue;
        final c = g['coordinates'] as List;
        if (c.length < 3) continue;
        final id = f['id']?.toString();
        final time = _int(p['time']);
        final mag = _num(p['mag']);
        if (id == null || time == null || mag == null) continue;
        out.add(Earthquake(
          id: id,
          source: 'USGS',
          place: p['place']?.toString() ?? 'Global',
          magnitude: mag,
          longitude: _num(c[0]),
          latitude: _num(c[1]),
          depthKm: _num(c[2]),
          timeEpoch: (time / 1000).round(),
          magType: p['magType']?.toString(),
          mmi: _num(p['mmi']),
          tsunami: p['tsunami'],
        ));
      }
      return out;
    } catch (_) { return const []; }
  }

  double? _num(dynamic v) { if (v is num) return v.toDouble(); return double.tryParse('$v'); }
  int? _int(dynamic v) { if (v is num) return v.toInt(); return int.tryParse('$v'); }
  double? _depth(dynamic v) { final m=RegExp(r'(-?[0-9.]+)').firstMatch('$v'); return m==null?null:double.tryParse(m.group(1)!); }
  int? _parseBmkgTime(String? date, String? time) {
    if (date == null || time == null) return null;
    final d=RegExp(r'(\d{2})-(\d{2})-(\d{4})').firstMatch(date);
    final t=RegExp(r'(\d{2}):(\d{2}):(\d{2})').firstMatch(time);
    if(d==null||t==null) return null;
    final dt=DateTime.tryParse('${d.group(3)}-${d.group(2)}-${d.group(1)}T${t.group(1)}:${t.group(2)}:${t.group(3)}+07:00');
    return dt == null ? null : dt.millisecondsSinceEpoch ~/ 1000;
  }
  double _distanceKm(double lat1,double lon1,double lat2,double lon2) {
    const r=6371.0; final p1=lat1*math.pi/180,p2=lat2*math.pi/180; final dp=(lat2-lat1)*math.pi/180,dl=(lon2-lon1)*math.pi/180;
    final a=math.sin(dp/2)*math.sin(dp/2)+math.cos(p1)*math.cos(p2)*math.sin(dl/2)*math.sin(dl/2);
    return r*2*math.atan2(math.sqrt(a),math.sqrt(1-a));
  }
}
