import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bmkg_latest_earthquake.dart';
import '../repositories/bmkg_latest_earthquake_repository.dart';

final bmkgLatestEarthquakeRepositoryProvider = Provider<BmkgLatestEarthquakeRepository>((ref) {
  return BmkgLatestEarthquakeRepository();
});

/// Feed nasional BMKG. BMKG menyatakan data gempa diperbarui setiap ada
/// peristiwa. Aplikasi mengecek ulang setiap 1 menit agar UI tetap segar.
final bmkgLatestEarthquakeProvider = StreamProvider.autoDispose<BmkgLatestEarthquake>((ref) async* {
  final repository = ref.watch(bmkgLatestEarthquakeRepositoryProvider);

  while (true) {
    try {
      yield await repository.getLatest();
    } catch (e, st) {
      yield* Stream<BmkgLatestEarthquake>.error(e, st);
      return;
    }
    await Future<void>.delayed(const Duration(minutes: 1));
  }
});
