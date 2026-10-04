import 'package:flutter/foundation.dart';

/// Satu hasil pencarian lokasi (dari Nominatim/OpenStreetMap — data
/// sungguhan, bukan mock).
@immutable
class SearchedPlace {
  final String displayName;
  final double latitude;
  final double longitude;

  const SearchedPlace({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}
