import '../models/earthquake_event_model.dart';

abstract class EarthquakeEventRepository {
  Future<List<EarthquakeEvent>> getRecentEvents();
}
