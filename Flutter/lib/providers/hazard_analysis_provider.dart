import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/earthquake_risk_model.dart';
import '../models/hazard_analysis.dart';
import '../models/selected_location.dart';
import '../models/tsunami_risk_model.dart';
import '../models/weather_model.dart';
import '../models/tsunami_warning_event.dart';
import '../repositories/hazard_index_repository.dart';
import '../repositories/inarisk_hazard_index_repository.dart';
import '../services/risk_engine.dart';
import 'earthquake_risk_provider.dart';
import 'tsunami_risk_provider.dart';
import 'weather_provider.dart';
import 'tsunami_warning_provider.dart';

final hazardIndexRepositoryProvider = Provider<HazardIndexRepository>((ref) {
  return InariskHazardIndexRepository();
});

final riskEngineProvider = Provider<RiskEngine>((ref) => const RiskEngine());

/// Menjalankan analisis lengkap untuk [location].
///
/// Setiap sumber dibungkus try/catch SENDIRI-SENDIRI: kalau USGS atau
/// cuaca gagal, analisis tetap jalan dengan data yang berhasil diambil,
/// dan Risk Engine yang menandai bagian mana yang "tidak tersedia".
/// Hanya kegagalan mengambil indeks bahaya resmi yang membuat seluruh
/// analisis kosong — karena itulah penentu levelnya.
final hazardAnalysisProvider =
    FutureProvider.autoDispose.family<HazardAnalysis, SelectedLocation>((ref, location) async {
  final point = LatLng(location.latitude, location.longitude);

  final indices = await ref.watch(hazardIndexRepositoryProvider).getHazardIndices(
        latitude: location.latitude,
        longitude: location.longitude,
        types: HazardType.values,
      );

  EarthquakeRisk? earthquakeRisk;
  try {
    earthquakeRisk = await ref.watch(earthquakeRiskProvider(point).future);
  } catch (_) {
    earthquakeRisk = null;
  }

  TsunamiRisk? tsunamiRisk;
  try {
    tsunamiRisk = await ref.watch(tsunamiRiskProvider(point).future);
  } catch (_) {
    tsunamiRisk = null;
  }

  Weather? weather;
  List<TsunamiWarningEvent> tsunamiWarningEvents = const [];
  try {
    weather = await ref.watch(weatherRepositoryProvider).getWeatherForLocation(
          latitude: location.latitude,
          longitude: location.longitude,
        );
  } catch (_) {
    weather = null;
  }

  try {
    tsunamiWarningEvents = await ref.watch(tsunamiWarningEventsProvider.future);
  } catch (_) {
    tsunamiWarningEvents = const [];
  }

  return ref.watch(riskEngineProvider).analyze(
        RiskEngineInput(
          location: location,
          hazardIndices: indices,
          earthquakeRisk: earthquakeRisk,
          tsunamiRisk: tsunamiRisk,
          weather: weather,
          tsunamiWarningEvents: tsunamiWarningEvents,
        ),
      );
});
