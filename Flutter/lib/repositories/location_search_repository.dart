import '../models/searched_place_model.dart';

/// Kontrak pencarian & reverse-geocoding lokasi. Berbeda dari
/// [LocationRepository] (yang mengurus "lokasi perangkat saat ini" di
/// Home) — ini untuk mencari lokasi APAPUN secara global di Peta.
abstract class LocationSearchRepository {
  /// Cari lokasi berdasarkan teks bebas (nama kota, alamat, dll).
  Future<List<SearchedPlace>> search(String query);

  /// Ambil nama lokasi dari koordinat (dipakai saat user ketuk langsung
  /// di peta, bukan lewat pencarian teks).
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}
