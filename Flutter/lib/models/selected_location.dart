import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Lokasi yang sedang dianalisis — SATU model yang dipakai bersama oleh
/// Peta, Risk Engine, AI Analyst, dan Lapor.
///
/// Sengaja TIDAK membuat state lokasi baru yang terpisah: nilainya
/// diturunkan dari [selectedMapLocationProvider] +
/// [selectedMapLocationLabelProvider] yang sudah ada di Peta (lihat
/// `providers/selected_location_provider.dart`), supaya tidak ada dua
/// sumber kebenaran yang bisa berbeda satu sama lain.
@immutable
class SelectedLocation {
  final double latitude;
  final double longitude;

  /// Nama/alamat hasil geocoding Nominatim. `null` kalau reverse-geocode
  /// gagal — UI harus jatuh ke tampilan koordinat, BUKAN mengarang nama.
  final String? displayName;

  /// Kapan lokasi ini dipilih user. Dipakai untuk jejak audit di hasil
  /// analisis (aturan: semua data harus punya timestamp).
  final DateTime selectedAt;

  const SelectedLocation({
    required this.latitude,
    required this.longitude,
    this.displayName,
    required this.selectedAt,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  /// Label yang aman ditampilkan: nama asli kalau ada, kalau tidak
  /// koordinat apa adanya. Tidak pernah mengarang nama wilayah.
  String get safeLabel =>
      displayName ?? '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  String get formattedLatitude => latitude.toStringAsFixed(5);
  String get formattedLongitude => longitude.toStringAsFixed(5);
}
