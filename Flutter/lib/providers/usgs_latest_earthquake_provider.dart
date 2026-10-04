import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/earthquake_event_model.dart';
import '../repositories/usgs_earthquake_event_repository.dart';

final usgsEarthquakeEventRepositoryProvider = Provider<UsgsEarthquakeEventRepository>((ref) {
  return UsgsEarthquakeEventRepository();
});

/// Gempa global near-real-time. USGS menyegarkan feed GeoJSON <= 1 menit.
/// Ini feed kejadian, bukan prediksi.
final usgsLatestEarthquakeProvider = StreamProvider.autoDispose<EarthquakeEvent?>((ref) async* {
  final repository = ref.watch(usgsEarthquakeEventRepositoryProvider);
  while (true) {
    try {
      final events = await repository.getRecentEvents();
      yield events.isEmpty ? null : events.first;
    } catch (e, st) {
      yield* Stream<EarthquakeEvent?>.error(e, st);
      return;
    }
    await Future<void>.delayed(const Duration(minutes: 1));
  }
});
