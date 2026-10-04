import '../models/volcano_model.dart';
import 'volcano_repository.dart';

/// ⚠️ MOCK UNTUK DEVELOPMENT SAJA — BUKAN DATA PRODUKSI.
///
/// Dipakai HANYA supaya UI daftar/marker gunung api bisa dikembangkan &
/// diuji sebelum endpoint resmi PVMBG/MAGMA Indonesia tersedia. UI yang
/// memakai repository ini WAJIB menampilkan indikator "data pengembangan"
/// (lihat [LayerConfig.origin] = [DataOrigin.mockDevOnly] di
/// `disasterLayerConfigs`), TIDAK BOLEH ditampilkan seolah data resmi.
///
/// Jangan dipakai untuk build production sampai diganti implementasi
/// nyata (mis. `PvmbgVolcanoRepository`) di provider.
class DevMockVolcanoRepository implements VolcanoRepository {
  @override
  Future<List<VolcanoModel>> getActiveVolcanoes() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return [
      VolcanoModel(
        id: 'dev-merapi',
        name: 'Merapi (DATA DEV)',
        region: 'Jawa Tengah/DIY',
        latitude: -7.5407,
        longitude: 110.4457,
        elevationMeters: 2930,
        statusLevel: VolcanoAlertLevel.levelIII,
        activityStatus: VolcanoActivityStatus.increasedActivity,
        lastUpdate: DateTime.now(),
        source: 'MOCK DEV — bukan data PVMBG resmi',
        dangerRadiusKm: 5,
        description: 'Contoh data pengembangan, belum terhubung ke sumber resmi.',
      ),
    ];
  }
}
