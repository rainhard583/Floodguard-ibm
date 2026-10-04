import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/selected_location.dart';
import 'location_search_provider.dart';

/// Lokasi terpilih dalam bentuk [SelectedLocation] — dipakai Lapor,
/// Risk Engine, dan (nanti) AI Analyst.
///
/// SENGAJA hanya menurunkan nilai dari [selectedMapLocationProvider] dan
/// [selectedMapLocationLabelProvider] yang sudah dipakai Peta. Tidak ada
/// state lokasi baru yang dibuat di sini, supaya tidak pernah ada dua
/// "lokasi terpilih" yang isinya berbeda.
///
/// `null` = user belum memilih lokasi apa pun di Peta.
final selectedLocationProvider = Provider<SelectedLocation?>((ref) {
  final point = ref.watch(selectedMapLocationProvider);
  if (point == null) return null;

  final label = ref.watch(selectedMapLocationLabelProvider);
  return SelectedLocation(
    latitude: point.latitude,
    longitude: point.longitude,
    displayName: label,
    selectedAt: DateTime.now(),
  );
});
