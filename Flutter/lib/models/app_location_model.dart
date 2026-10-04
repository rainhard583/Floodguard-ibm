import 'package:flutter/foundation.dart';

/// Status ketersediaan lokasi. Loading dikelola lewat AsyncValue di
/// provider (lihat providers/location_provider.dart) — enum ini hanya
/// membedakan kondisi "sudah selesai dicek, hasilnya begini".
enum LocationStatus { available, unavailable, permissionRequired }

/// Nama sengaja `AppLocation` (bukan `Location`) supaya tidak bentrok
/// dengan tipe `Location` dari package geolocation yang akan dipakai saat
/// GPS asli diimplementasikan (Phase 4).
@immutable
class AppLocation {
  final LocationStatus status;
  final String? label; // contoh: "Kelurahan Sukamaju, Bandung"
  final double? latitude;
  final double? longitude;
  final DateTime updatedAt;

  const AppLocation({
    required this.status,
    required this.updatedAt,
    this.label,
    this.latitude,
    this.longitude,
  });
}
