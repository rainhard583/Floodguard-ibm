import 'dart:async';
import 'dart:math' as math;
import '../models/app_location_model.dart';
import '../models/bmkg_latest_earthquake.dart';
import '../models/history_entry.dart';
import '../repositories/bmkg_felt_earthquake_repository.dart';
import 'history_service.dart';
import 'notification_service.dart';
import 'floodguard_settings.dart';

/// Live local-earthquake monitor for the active FloodGuard location.
///
/// Important: this is DETECTION, not earthquake prediction. BMKG publishes
/// recent events and updates its real-time feed when an earthquake occurs.
/// We poll the official feed once per minute, which is within BMKG's public
/// access limit and is frequent enough for an in-app monitor.
class EarthquakeAlertService {
  EarthquakeAlertService._();
  static final EarthquakeAlertService instance = EarthquakeAlertService._();

  final BmkgFeltEarthquakeRepository _repository =
      BmkgFeltEarthquakeRepository();
  Timer? _timer;
  AppLocation? _location;
  bool _checking = false;
  final Set<String> _seenEvents = <String>{};

  static const double _historyRadiusKm = 300;

  FloodGuardSettings get _settings => FloodGuardSettings.instance;

  void start() {
    _timer ??= Timer.periodic(const Duration(minutes: 1), (_) => checkNow());
    checkNow();
  }

  void updateLocation(AppLocation? location) {
    final changed = _location?.latitude != location?.latitude ||
        _location?.longitude != location?.longitude ||
        _location?.label != location?.label;
    _location = location;
    if (changed) checkNow();
  }

  Future<void> checkNow() async {
    if (_checking) return;
    final location = _location;
    if (location?.latitude == null || location?.longitude == null) return;

    _checking = true;
    try {
      final events = await _repository.getRecent();
      final now = DateTime.now();
      final activeLabel = (location!.label ?? '').trim();
      if (activeLabel.isEmpty) return;

      for (final event in events) {
        if (event.latitude == null || event.longitude == null) continue;
        final distance = _distanceKm(
          location.latitude!,
          location.longitude!,
          event.latitude!,
          event.longitude!,
        );
        if (distance > _historyRadiusKm) continue;

        final age = now.difference(event.eventTime);
        // Ignore malformed/unknown timestamps instead of treating them as 'now'.
        if (event.eventTime.millisecondsSinceEpoch <= 0) continue;
        if (age.isNegative || age.inHours > 24) continue;

        _addHistory(event, activeLabel, distance);

        // Only notify for a genuinely recent nearby event. Starting the app
        // should not create a burst of old earthquake notifications.
        if (_settings.earthquakeAlertsEnabled &&
            age.inMinutes <= 10 &&
            distance <= _settings.monitoringRadiusKm &&
            event.magnitude >= _settings.earthquakeMagnitude) {
          await _notifyOnce(event, activeLabel, distance);
        }
      }

      HistoryService.instance.markSync('BMKG Gempa');
    } catch (_) {
      // A temporary BMKG/network failure must not break Home or WeatherAPI.
      HistoryService.instance.markSync('BMKG Gempa gagal diperbarui');
    } finally {
      _checking = false;
    }
  }

  void _addHistory(
    BmkgLatestEarthquake event,
    String location,
    double distanceKm,
  ) {
    final id = 'earthquake-${event.eventId}';
    HistoryService.instance.add(
      HistoryEntry(
        id: id,
        type: HistoryEntryType.earthquake,
        title: 'Gempa Terdeteksi di Sekitar Wilayah',
        message:
            '${event.displayMagnitude} • ${event.depth ?? '-'} • jarak sekitar ${_distanceText(distanceKm)}. '
            '${event.region ?? 'Lokasi episenter tidak tersedia'}.',
        source: 'BMKG',
        location: location,
        timestamp: event.eventTime,
        isWarning: event.magnitude >= _settings.earthquakeMagnitude,
      ),
    );
  }

  Future<void> _notifyOnce(
    BmkgLatestEarthquake event,
    String location,
    double distanceKm,
  ) async {
    final id = 'earthquake-${event.eventId}-$location';
    if (_seenEvents.contains(id)) return;
    _seenEvents.add(id);

    final body =
        '${event.displayMagnitude} terdeteksi sekitar ${_distanceText(distanceKm)} dari $location. '
        'Kedalaman ${event.depth ?? 'tidak tersedia'}. ${event.region ?? ''}'.trim();

    await NotificationService.instance.showAlert(
      key: id,
      title: 'Gempa Terdeteksi',
      body: body,
      important: true,
    );
  }

  String _distanceText(double km) {
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double degrees) => degrees * math.pi / 180.0;
}
