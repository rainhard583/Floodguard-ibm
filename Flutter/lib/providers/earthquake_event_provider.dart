import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/earthquake_event_model.dart';
import '../repositories/earthquake_event_repository.dart';
import '../repositories/usgs_earthquake_event_repository.dart';

final earthquakeEventRepositoryProvider = Provider<EarthquakeEventRepository>((ref) {
  return UsgsEarthquakeEventRepository();
});

/// Global USGS event layer. Refreshes every minute so new earthquakes can
/// appear without restarting the app.
final earthquakeEventsProvider = StreamProvider.autoDispose<List<EarthquakeEvent>>((ref) async* {
  final repository = ref.watch(earthquakeEventRepositoryProvider);
  while (true) {
    try {
      yield await repository.getRecentEvents();
    } catch (e, st) {
      yield* Stream<List<EarthquakeEvent>>.error(e, st);
      return;
    }
    await Future<void>.delayed(const Duration(minutes: 1));
  }
});
