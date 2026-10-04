import 'package:flutter/foundation.dart';

/// Central API configuration for FloodGuard.
///
/// Secrets such as WeatherAPI keys are NEVER stored here. Flutter only
/// knows the URL of the FloodGuard Laravel backend.
class ApiConfig {
  ApiConfig._();

  static const _configuredBaseUrl = String.fromEnvironment(
    'FLOODGUARD_API_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    final configured = _configuredBaseUrl.trim();
    if (configured.isNotEmpty) {
      return _stripTrailingSlash(configured);
    }

    // Android emulator maps the host machine's localhost to 10.0.2.2.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api';
    }

    return 'http://127.0.0.1:8000/api';
  }

  static String get aiAnalyzeUrl => '$baseUrl/ai/analyze';
  static String get floodRiskPointUrl => '$baseUrl/flood/risk-point';
  static String get currentWeatherUrl => '$baseUrl/weather/current';
  static String get inariskUrl => '$baseUrl/hazards/inarisk';
  static String get bmkgEarthquakeUrl => '$baseUrl/earthquakes/bmkg';
  static String get usgsEarthquakeUrl => '$baseUrl/earthquakes/global';
  static String get earthquakeOverviewUrl => '$baseUrl/earthquakes/overview';
  static String get earthquakeLocationUrl => '$baseUrl/earthquakes/location';

  static String _stripTrailingSlash(String value) {
    var result = value;
    while (result.endsWith('/')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  }
}
