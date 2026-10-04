import 'dart:math';

/// Hitung jarak antara dua koordinat bumi (rumus Haversine), dalam
/// kilometer. Dipakai repository yang menghitung jarak NYATA ke gempa
/// terdekat dsb — bukan taksiran/acak.
double haversineDistanceKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degToRad(lat1)) * cos(_degToRad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

/// Titik koordinat berjarak [distanceKm] dari (lat, lon) pada arah
/// [bearingDeg] (0=Utara, 90=Timur, dst). Aproksimasi equirectangular —
/// cukup akurat untuk jarak puluhan km seperti dipakai saat mengambil
/// sampel elevasi di sekeliling satu titik (lihat
/// repositories/real_tsunami_risk_repository.dart).
({double latitude, double longitude}) destinationPoint({
  required double latitude,
  required double longitude,
  required double bearingDeg,
  required double distanceKm,
}) {
  const kmPerDegreeLat = 111.32;
  final bearingRad = _degToRad(bearingDeg);
  final dLat = (distanceKm / kmPerDegreeLat) * cos(bearingRad);
  final kmPerDegreeLon = kmPerDegreeLat * cos(_degToRad(latitude)).abs().clamp(0.01, 1.0);
  final dLon = (distanceKm / kmPerDegreeLon) * sin(bearingRad);
  return (latitude: latitude + dLat, longitude: longitude + dLon);
}

double _degToRad(double deg) => deg * pi / 180;
