import '../models/app_location_model.dart';
import '../models/weather_model.dart';
import '../models/history_entry.dart';
import 'history_service.dart';
import 'notification_service.dart';

/// Mesin peringatan hujan lokal.
///
/// Sumbernya tetap WeatherAPI melalui Weather model yang sudah dipakai Home.
/// Tidak membuat request baru, sehingga tidak mengubah alur WeatherAPI yang
/// sudah berjalan. Engine hanya mengevaluasi observasi + prakiraan yang sudah
/// diterima aplikasi.
class RainAlertService {
  RainAlertService._();
  static final RainAlertService instance = RainAlertService._();

  bool hasPendingWarning(Weather weather) {
    final now = DateTime.now();
    final currentWarning = weather.condition == WeatherCondition.hujanLebat ||
        weather.condition == WeatherCondition.badai ||
        weather.rainfallMm >= 5;
    if (currentWarning) return true;

    for (final item in weather.forecast) {
      final t = item.forecastTime?.toLocal();
      if (t == null || t.isBefore(now)) continue;
      if (t.difference(now).inMinutes > 60) break;
      final chance = item.chanceOfRainPercent ?? 0;
      if (item.condition == WeatherCondition.hujanLebat ||
          item.condition == WeatherCondition.badai ||
          chance >= 60 ||
          item.precipitationMm >= 1) {
        return true;
      }
    }
    return false;
  }

  Future<void> evaluate({
    required Weather weather,
    required AppLocation location,
  }) async {
    final label = (location.label ?? '').trim();
    if (label.isEmpty) return;

    final now = DateTime.now();
    final currentHigh = weather.condition == WeatherCondition.hujanLebat ||
        weather.condition == WeatherCondition.badai ||
        weather.rainfallMm >= 5;
    final currentRain = weather.condition == WeatherCondition.hujanRingan ||
        currentHigh ||
        weather.rainfallMm >= 0.5;

    if (currentRain) {
      final severity = currentHigh ? 'high' : 'normal';
      final hourKey = _hourKey(now);
      final id = 'rain-current-$severity-$hourKey-${_slug(label)}';
      final title = currentHigh ? 'Peringatan Hujan Lebat' : 'Hujan di Wilayah Anda';
      final body = currentHigh
          ? '$label sedang mengalami hujan dengan intensitas tinggi. Waspadai genangan dan kenaikan risiko banjir.'
          : '$label sedang mengalami hujan. Tetap waspada terhadap genangan di area rendah.';
      await _publish(
        id: id,
        title: title,
        body: body,
        location: label,
        isWarning: currentHigh,
      );
    }

    WeatherForecastItem? candidate;
    for (final item in weather.forecast) {
      final t = item.forecastTime?.toLocal();
      if (t == null || t.isBefore(now)) continue;
      if (t.difference(now).inMinutes <= 60) {
        candidate = item;
        break;
      }
    }
    if (candidate == null) return;

    final chance = candidate.chanceOfRainPercent ?? 0;
    final mm = candidate.precipitationMm;
    final heavy = candidate.condition == WeatherCondition.hujanLebat ||
        candidate.condition == WeatherCondition.badai ||
        mm >= 5 ||
        chance >= 80;

    // Hujan kecil dengan peluang rendah tidak menghasilkan notifikasi.
    // Threshold ini dibuat cukup konservatif agar tidak spam.
    if (!(heavy || chance >= 60 || mm >= 1)) return;

    final t = candidate.forecastTime!.toLocal();
    final id = 'rain-forecast-${heavy ? 'high' : 'normal'}-${t.toIso8601String()}-${_slug(label)}';
    final chanceText = 'Peluang hujan ${chance.round()}%';
    final rainText = mm > 0 ? 'Perkiraan presipitasi ${mm.toStringAsFixed(1)} mm.' : '';
    final body = heavy
        ? '$label berpotensi mengalami hujan lebat sekitar ${_clock(t)}. $chanceText. $rainText Waspadai genangan dan banjir.'
        : '$label berpotensi hujan sekitar ${_clock(t)}. $chanceText. $rainText Siapkan perlindungan jika akan bepergian.';

    await _publish(
      id: id,
      title: heavy ? 'Peringatan Hujan Lebat' : 'Peringatan Hujan',
      body: body.trim(),
      location: label,
      isWarning: heavy,
    );
  }

  Future<void> _publish({
    required String id,
    required String title,
    required String body,
    required String location,
    required bool isWarning,
  }) async {
    HistoryService.instance.add(
      HistoryEntry(
        id: id,
        type: HistoryEntryType.rain,
        title: title,
        message: body,
        source: 'WeatherAPI',
        location: location,
        timestamp: DateTime.now(),
        isWarning: isWarning,
      ),
    );
    await NotificationService.instance.showAlert(
      key: id,
      title: title,
      body: body,
      important: isWarning,
    );
  }

  String _hourKey(DateTime value) =>
      '${value.year}${value.month.toString().padLeft(2, '0')}${value.day.toString().padLeft(2, '0')}${value.hour.toString().padLeft(2, '0')}';

  String _slug(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  String _clock(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
