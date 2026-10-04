import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/searched_place_model.dart';
import 'location_search_repository.dart';

/// Implementasi NYATA (bukan mock) — memanggil Nominatim, layanan geocoding
/// gratis milik OpenStreetMap, tanpa API key.
///
/// PENTING (kebijakan pemakaian Nominatim — nominatim.org/release-docs/latest/api/Search/):
/// - Wajib menyertakan header `User-Agent` yang mengidentifikasi aplikasi.
///   Sebelum rilis ke publik, ganti `_userAgent` di bawah dengan nama app +
///   kontak Anda sendiri.
/// - Jangan memanggil endpoint ini secara berlebihan/berulang cepat (rate
///   limit kebijakan mereka ~1 request/detik). Search di sini sengaja
///   dipanggil saat user menekan tombol cari (bukan tiap ketikan huruf)
///   supaya tidak membanjiri permintaan.
/// - Untuk volume tinggi/produksi skala besar, pertimbangkan self-hosting
///   Nominatim atau memakai penyedia geocoding berbayar.
class NominatimLocationSearchRepository implements LocationSearchRepository {
  static const _baseUrl = 'https://nominatim.openstreetmap.org';
  static const _userAgent = 'FloodGuardApp/1.0 (dev-build; contact belum diisi)';

  @override
  Future<List<SearchedPlace>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': trimmed,
      'format': 'jsonv2',
      'limit': '8',
      'addressdetails': '0',
    });

    final response = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) {
      throw Exception('Pencarian lokasi gagal (${response.statusCode})');
    }

    final List<dynamic> results = jsonDecode(response.body) as List<dynamic>;
    return results.map((item) {
      final map = item as Map<String, dynamic>;
      return SearchedPlace(
        displayName: map['display_name'] as String? ?? 'Lokasi tidak diketahui',
        latitude: double.parse(map['lat'] as String),
        longitude: double.parse(map['lon'] as String),
      );
    }).toList();
  }

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'jsonv2',
    });

    final response = await http.get(uri, headers: {'User-Agent': _userAgent});
    if (response.statusCode != 200) return null;

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return map['display_name'] as String?;
  }
}
