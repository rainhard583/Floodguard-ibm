class WeatherMapConfig {
  static const apiKey = String.fromEnvironment('MERCATOR_API_KEY');
  static const catalogUrl = 'https://api.mercator.blue/catalog.json';
  static const mapStyle = 'https://tiles.openfreemap.org/styles/liberty';
  static bool get isConfigured => apiKey.trim().isNotEmpty;
}
