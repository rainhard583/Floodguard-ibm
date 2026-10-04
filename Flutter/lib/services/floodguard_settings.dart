import 'package:flutter/foundation.dart';

/// Pengaturan aplikasi yang dibaca oleh layar dan service FloodGuard.
///
/// State sengaja dipusatkan di satu tempat supaya toggle di Pengaturan
/// benar-benar mempengaruhi service yang bersangkutan, bukan hanya UI.
class FloodGuardSettings extends ChangeNotifier {
  FloodGuardSettings._();
  static final FloodGuardSettings instance = FloodGuardSettings._();

  bool notificationsEnabled = true;
  bool earthquakeNotification = true;
  bool floodNotification = true;
  bool weatherNotification = true;
  bool landslideNotification = true;
  bool volcanoNotification = true;
  bool autoLocation = true;
  bool aiAnalysis = true;
  bool rainLayer = true;
  bool earthquakeLayer = true;
  bool volcanoLayer = false;

  double earthquakeMagnitude = 4.0;
  double monitoringRadiusKm = 250.0;
  String temperatureUnit = '°C';
  String weatherUpdate = '15 menit';
  String themeMode = 'Terang';

  bool get earthquakeAlertsEnabled => notificationsEnabled && earthquakeNotification;

  void setNotificationsEnabled(bool value) {
    notificationsEnabled = value;
    earthquakeNotification = value;
    floodNotification = value;
    weatherNotification = value;
    landslideNotification = value;
    volcanoNotification = value;
    notifyListeners();
  }

  void setEarthquakeNotification(bool value) {
    earthquakeNotification = value;
    _notify();
  }

  void setFloodNotification(bool value) {
    floodNotification = value;
    _notify();
  }

  void setWeatherNotification(bool value) {
    weatherNotification = value;
    _notify();
  }

  void setLandslideNotification(bool value) {
    landslideNotification = value;
    _notify();
  }

  void setVolcanoNotification(bool value) {
    volcanoNotification = value;
    _notify();
  }

  void setAutoLocation(bool value) {
    autoLocation = value;
    _notify();
  }

  void setMagnitude(double value) {
    earthquakeMagnitude = value;
    _notify();
  }

  void setRadius(double value) {
    monitoringRadiusKm = value;
    _notify();
  }

  void setWeatherUpdate(String value) {
    weatherUpdate = value;
    _notify();
  }

  void setTemperatureUnit(String value) {
    temperatureUnit = value;
    _notify();
  }

  void setRainLayer(bool value) {
    rainLayer = value;
    _notify();
  }

  void setEarthquakeLayer(bool value) {
    earthquakeLayer = value;
    _notify();
  }

  void setVolcanoLayer(bool value) {
    volcanoLayer = value;
    _notify();
  }

  void setAiAnalysis(bool value) {
    aiAnalysis = value;
    _notify();
  }

  void setThemeMode(String value) {
    themeMode = value;
    _notify();
  }

  void _notify() {
    notifyListeners();
  }
}
