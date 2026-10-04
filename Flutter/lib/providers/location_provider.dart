import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_location_model.dart';
import '../repositories/location_repository.dart';
import '../repositories/real_location_repository.dart';

/// Instance [LocationRepository] untuk seluruh app.
///
/// GPS perangkat asli melalui Geolocator. Tidak ada lokasi hard-code.
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return RealLocationRepository();
});

/// Lokasi yang dipilih MANUAL oleh user lewat pencarian (mis. ketuk kartu
/// Lokasi di Home lalu cari wilayah apa saja). `null` berarti belum ada
/// pilihan manual — [locationProvider] di bawah masih memakai
/// [locationRepositoryProvider] (GPS perangkat) apa adanya. Dipisah dari
/// [locationRepositoryProvider] supaya nanti saat GPS asli (Phase 4) sudah
/// ada, override manual ini tetap bisa dipakai untuk "cek wilayah lain"
/// tanpa mengubah lokasi GPS sungguhan.
final manualLocationOverrideProvider = StateProvider<AppLocation?>((ref) => null);

/// Lokasi pengguna saat ini. Tidak pernah bernilai null di dalam
/// AsyncValue — status "unavailable"/"permission diperlukan" dibawa oleh
/// field [AppLocation.status] sendiri, karena itu state data yang legit,
/// bukan kegagalan pengambilan data.
///
/// Jika user sudah memilih lokasi manual (lewat [manualLocationOverrideProvider]),
/// itu yang dipakai — kalau belum, baru jatuh ke [locationRepositoryProvider].
final locationProvider = FutureProvider.autoDispose<AppLocation>((ref) async {
  final manualOverride = ref.watch(manualLocationOverrideProvider);
  if (manualOverride != null) return manualOverride;
  return ref.watch(locationRepositoryProvider).getCurrentLocation();
});
