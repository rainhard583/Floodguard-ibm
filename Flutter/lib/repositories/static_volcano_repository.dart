import '../models/volcano_model.dart';
import 'volcano_repository.dart';

/// Implementasi dengan DATA LOKASI GEOGRAFIS ASLI (nama, koordinat,
/// ketinggian — fakta publik yang bisa diverifikasi, bukan dikarang).
///
/// PENTING soal STATUS AKTIVITAS: PVMBG/MAGMA Indonesia (magma.esdm.go.id)
/// TIDAK punya endpoint API publik yang boleh diakses otomatis (robots.txt
/// situsnya melarang automated access — sama persis masalah yang pernah
/// terjadi dengan tile.openstreetmap.org di Peta ini). Karena itu status
/// (Level I-IV / normal-erupting) di sini SENGAJA `unknown` — bukan
/// ditebak — dan `source` selalu mengarahkan user ke situs resmi untuk
/// status TERKINI. Ganti implementasi ini (jadi mis. `PvmbgVolcanoRepository`)
/// kalau nanti PVMBG membuka kerja sama data resmi.
class StaticVolcanoRepository implements VolcanoRepository {
  static const _officialSource =
      'Lokasi & ketinggian: data geografis publik. Status aktivitas TERKINI: cek MAGMA Indonesia resmi (magma.esdm.go.id) — belum ada API resmi yang bisa diakses otomatis dari app ini.';

  @override
  Future<List<VolcanoModel>> getActiveVolcanoes() async {
    final now = DateTime.now();
    return [
      VolcanoModel(
        id: 'anak-krakatau',
        name: 'Anak Krakatau',
        region: 'Selat Sunda, Lampung/Banten',
        latitude: -6.1023,
        longitude: 105.4233,
        elevationMeters: 110,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'semeru',
        name: 'Semeru',
        region: 'Jawa Timur',
        latitude: -8.1080,
        longitude: 112.9227,
        elevationMeters: 3676,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'merapi',
        name: 'Merapi',
        region: 'DI Yogyakarta/Jawa Tengah',
        latitude: -7.5407,
        longitude: 110.4457,
        elevationMeters: 2930,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'sinabung',
        name: 'Sinabung',
        region: 'Sumatera Utara',
        latitude: 3.1700,
        longitude: 98.3920,
        elevationMeters: 2460,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'agung',
        name: 'Agung',
        region: 'Bali',
        latitude: -8.3425,
        longitude: 115.5083,
        elevationMeters: 3031,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'bromo',
        name: 'Bromo',
        region: 'Jawa Timur',
        latitude: -7.9425,
        longitude: 112.9530,
        elevationMeters: 2329,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'kelud',
        name: 'Kelud',
        region: 'Jawa Timur',
        latitude: -7.9306,
        longitude: 112.3083,
        elevationMeters: 1731,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'dempo',
        name: 'Dempo',
        region: 'Sumatera Selatan',
        latitude: -4.0300,
        longitude: 103.1300,
        elevationMeters: 3159,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'ijen',
        name: 'Ijen',
        region: 'Jawa Timur',
        latitude: -8.0581,
        longitude: 114.2420,
        elevationMeters: 2769,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
      VolcanoModel(
        id: 'lewotobi-laki-laki',
        name: 'Lewotobi Laki-laki',
        region: 'Nusa Tenggara Timur',
        latitude: -8.2725,
        longitude: 122.7750,
        elevationMeters: 1584,
        activityStatus: VolcanoActivityStatus.unknown,
        lastUpdate: now,
        source: _officialSource,
      ),
    ];
  }
}
