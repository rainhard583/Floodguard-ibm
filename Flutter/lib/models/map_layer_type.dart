import 'package:flutter/material.dart';

/// Domain besar layer peta — dipisah tegas sesuai permintaan: Cuaca &
/// Lingkungan vs Bencana Alam.
enum MapLayerCategory { weatherEnvironment, disaster }

/// Dari mana nilai suatu layer berasal — dipakai UI untuk TIDAK PERNAH
/// mengklaim data model/forecast sebagai observasi langsung.
enum DataOrigin { observation, forecastModel, officialWarning, mockDevOnly }

extension DataOriginLabel on DataOrigin {
  String get label {
    switch (this) {
      case DataOrigin.observation:
        return 'Observasi';
      case DataOrigin.forecastModel:
        return 'Model/Forecast';
      case DataOrigin.officialWarning:
        return 'Peringatan Resmi';
      case DataOrigin.mockDevOnly:
        return 'Data Development (Mock)';
    }
  }
}

/// Semua layer CUACA & LINGKUNGAN yang mungkin ada di peta. Enum ini
/// SATU-SATUNYA sumber kebenaran untuk daftar layer — jangan tambah
/// boolean baru di MapScreen, tambah nilai di sini + entri di
/// [weatherLayerConfigs].
enum WeatherLayerType {
  wind,
  windGust,
  rain,
  temperature,
  dewPoint,
  humidity,
  pressure,
  cloudCover,
  visibility,
  uvIndex,
  airQuality,
  pm25,
  pm10,
  so2,
  no2,
  co,
  ozone,
  // Layer di bawah ini butuh provider yang BELUM ada di project (radar
  // tile, satelit, grid wind vector, data laut) — statusnya
  // `supported: false` di config, UI wajib tampilkan "Belum tersedia",
  // BUKAN data acak.
  radar,
  satellite,
  waves,
  seaTemperature,
}

/// Semua layer BENCANA ALAM. Gempa & tsunami DI SINI adalah representasi
/// "live event/official warning" di peta — beda dari
/// EarthquakeRisk/TsunamiRisk (risiko utk 1 lokasi terpilih) yang sudah
/// ada di [SelectedLocationPanel]. Lihat catatan di README arsitektur.
enum DisasterLayerType { earthquakeEvents, tsunamiWarning, volcano, flood }

@immutable
class LayerConfig {
  final String id;
  final String title;
  final IconData icon;
  final String? unit;
  final String source;
  final DataOrigin origin;
  final bool supported;
  final bool isAnimated;
  final bool hasForecastTimeline;
  final Color legendColor;

  const LayerConfig({
    required this.id,
    required this.title,
    required this.icon,
    this.unit,
    required this.source,
    required this.origin,
    required this.supported,
    this.isAnimated = false,
    this.hasForecastTimeline = false,
    required this.legendColor,
  });
}

/// Konfigurasi SEMUA layer cuaca — 1 tempat, tidak tersebar di widget.
const Map<WeatherLayerType, LayerConfig> weatherLayerConfigs = {
  WeatherLayerType.wind: LayerConfig(
    id: 'wind',
    title: 'Angin',
    icon: Icons.air_rounded,
    unit: 'km/j',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    hasForecastTimeline: true,
    legendColor: Color(0xFF4FC3F7),
  ),
  WeatherLayerType.windGust: LayerConfig(
    id: 'wind_gust',
    title: 'Angin Kencang (Gust)',
    icon: Icons.air_rounded,
    unit: 'km/j',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    hasForecastTimeline: true,
    legendColor: Color(0xFF29B6F6),
  ),
  WeatherLayerType.rain: LayerConfig(
    id: 'rain',
    title: 'Prakiraan Hujan 3 Jam',
    icon: Icons.water_drop_rounded,
    unit: 'mm',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    hasForecastTimeline: true,
    legendColor: Color(0xFF2196F3),
  ),
  WeatherLayerType.temperature: LayerConfig(
    id: 'temperature',
    title: 'Suhu',
    icon: Icons.thermostat_rounded,
    unit: '°C',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    hasForecastTimeline: true,
    legendColor: Color(0xFFFF7043),
  ),
  WeatherLayerType.dewPoint: LayerConfig(
    id: 'dew_point',
    title: 'Titik Embun',
    icon: Icons.opacity_rounded,
    unit: '°C',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFF80CBC4),
  ),
  WeatherLayerType.humidity: LayerConfig(
    id: 'humidity',
    title: 'Kelembapan',
    icon: Icons.water_rounded,
    unit: '%',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    hasForecastTimeline: true,
    legendColor: Color(0xFF4DD0E1),
  ),
  WeatherLayerType.pressure: LayerConfig(
    id: 'pressure',
    title: 'Tekanan Udara',
    icon: Icons.speed_rounded,
    unit: 'hPa',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFFAB47BC),
  ),
  WeatherLayerType.cloudCover: LayerConfig(
    id: 'cloud_cover',
    title: 'Tutupan Awan',
    icon: Icons.cloud_rounded,
    unit: '%',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    hasForecastTimeline: true,
    legendColor: Color(0xFF7F8994),
  ),
  WeatherLayerType.visibility: LayerConfig(
    id: 'visibility',
    title: 'Jarak Pandang',
    icon: Icons.visibility_rounded,
    unit: 'km',
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFFB0BEC5),
  ),
  WeatherLayerType.uvIndex: LayerConfig(
    id: 'uv_index',
    title: 'Indeks UV',
    icon: Icons.wb_sunny_rounded,
    source: 'Mercator · NOAA GFS',
    origin: DataOrigin.forecastModel,
    supported: true,
    hasForecastTimeline: true,
    legendColor: Color(0xFFFFB300),
  ),
  WeatherLayerType.airQuality: LayerConfig(
    id: 'air_quality',
    title: 'Kualitas Udara (AQI)',
    icon: Icons.masks_rounded,
    source: 'CAMS Global · Mercator',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFF8D6E63),
  ),
  WeatherLayerType.pm25: LayerConfig(
    id: 'pm25',
    title: 'PM2.5',
    icon: Icons.grain_rounded,
    unit: 'µg/m³',
    source: 'CAMS Global · Mercator',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFF8D6E63),
  ),
  WeatherLayerType.pm10: LayerConfig(
    id: 'pm10',
    title: 'PM10',
    icon: Icons.grain_rounded,
    unit: 'µg/m³',
    source: 'CAMS Global · Mercator',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFFA1887F),
  ),
  WeatherLayerType.so2: LayerConfig(
    id: 'so2',
    title: 'SO₂',
    icon: Icons.science_rounded,
    unit: 'µg/m³',
    source: 'CAMS Global · Mercator',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFFFFCA28),
  ),
  WeatherLayerType.no2: LayerConfig(
    id: 'no2',
    title: 'NO₂',
    icon: Icons.science_rounded,
    unit: 'µg/m³',
    source: 'CAMS Global · Mercator',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFFEF5350),
  ),
  WeatherLayerType.co: LayerConfig(
    id: 'co',
    title: 'CO',
    icon: Icons.science_rounded,
    unit: 'µg/m³',
    source: 'CAMS Global · Mercator',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFF757575),
  ),
  WeatherLayerType.ozone: LayerConfig(
    id: 'ozone',
    title: 'O₃ (Ozon)',
    icon: Icons.science_rounded,
    unit: 'µg/m³',
    source: 'CAMS Global · Mercator',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFF42A5F5),
  ),
  WeatherLayerType.radar: LayerConfig(
    id: 'radar',
    title: 'Radar Curah Hujan',
    icon: Icons.radar_rounded,
    source: 'Belum tersedia',
    origin: DataOrigin.forecastModel,
    supported: false,
    legendColor: Color(0xFF616161),
  ),
  WeatherLayerType.satellite: LayerConfig(
    id: 'satellite',
    title: 'Satelit Awan',
    icon: Icons.satellite_alt_rounded,
    source: 'Belum tersedia',
    origin: DataOrigin.forecastModel,
    supported: false,
    legendColor: Color(0xFF616161),
  ),
  WeatherLayerType.waves: LayerConfig(
    id: 'waves',
    title: 'Tinggi Gelombang',
    icon: Icons.waves_rounded,
    unit: 'm',
    source: 'Belum tersedia',
    origin: DataOrigin.forecastModel,
    supported: false,
    legendColor: Color(0xFF616161),
  ),
  WeatherLayerType.seaTemperature: LayerConfig(
    id: 'sea_temperature',
    title: 'Suhu Laut',
    icon: Icons.thermostat_rounded,
    unit: '°C',
    source: 'Belum tersedia',
    origin: DataOrigin.forecastModel,
    supported: false,
    legendColor: Color(0xFF616161),
  ),
};

const Map<DisasterLayerType, LayerConfig> disasterLayerConfigs = {
  DisasterLayerType.earthquakeEvents: LayerConfig(
    id: 'earthquake_events',
    title: 'Gempa Bumi',
    icon: Icons.vibration_rounded,
    source: 'USGS',
    origin: DataOrigin.observation,
    supported: true,
    isAnimated: true,
    legendColor: Color(0xFFFF9800),
  ),
  DisasterLayerType.tsunamiWarning: LayerConfig(
    id: 'tsunami_warning',
    title: 'Peringatan Tsunami',
    icon: Icons.tsunami_rounded,
    source: 'BMKG Data Gempabumi Terbuka',
    origin: DataOrigin.officialWarning,
    supported: true,
    isAnimated: true,
    legendColor: Color(0xFF29B6F6),
  ),
  DisasterLayerType.volcano: LayerConfig(
    id: 'volcano',
    title: 'Gunung Api',
    icon: Icons.terrain_rounded,
    source: 'Lokasi: data publik. Status resmi: MAGMA Indonesia',
    origin: DataOrigin.observation,
    supported: true,
    isAnimated: true,
    legendColor: Color(0xFFF44336),
  ),
  DisasterLayerType.flood: LayerConfig(
    id: 'flood',
    title: 'Banjir',
    icon: Icons.flood_rounded,
    source: 'GloFAS / Open-Meteo Flood API',
    origin: DataOrigin.forecastModel,
    supported: true,
    legendColor: Color(0xFF26A69A),
  ),
};
