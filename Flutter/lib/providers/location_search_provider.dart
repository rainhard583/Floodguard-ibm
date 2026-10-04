import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../repositories/location_search_repository.dart';
import '../repositories/nominatim_location_search_repository.dart';

/// Instance [LocationSearchRepository] untuk seluruh app. Sudah pakai
/// implementasi NYATA (Nominatim/OpenStreetMap) sejak awal — bukan mock —
/// karena search lokasi tidak butuh mesin/algoritma internal apa pun,
/// cukup panggil layanan geocoding publik yang gratis.
final locationSearchRepositoryProvider = Provider<LocationSearchRepository>((ref) {
  return NominatimLocationSearchRepository();
});

/// Titik yang sedang dipilih user di Peta (lewat search ATAU tap
/// langsung). `null` berarti belum ada yang dipilih.
final selectedMapLocationProvider = StateProvider<LatLng?>((ref) => null);

/// Nama/alamat dari titik yang sedang dipilih (dari hasil search, atau
/// hasil reverse-geocode saat tap langsung di peta). Terpisah dari
/// [selectedMapLocationProvider] supaya keduanya bisa di-update secara
/// independen (mis. reverse-geocode gagal, tapi titik & risiko tetap bisa
/// tampil dengan label fallback "lat, lng").
final selectedMapLocationLabelProvider = StateProvider<String?>((ref) => null);
