import '../models/data_source.dart';
import '../models/hazard_analysis.dart';
import '../services/inarisk_service.dart';
import 'hazard_index_repository.dart';

/// Implementasi [HazardIndexRepository] memakai peta bahaya resmi
/// InaRISK (BNPB) lewat [InariskService].
class InariskHazardIndexRepository implements HazardIndexRepository {
  final InariskService _service;

  InariskHazardIndexRepository({InariskService? service})
      : _service = service ?? InariskService();

  /// Pemetaan jenis bahaya FloodGuard -> layer InaRISK.
  static const _layerFor = <HazardType, InariskLayer>{
    HazardType.banjir: InariskLayer.banjir,
    HazardType.gempaBumi: InariskLayer.gempaBumi,
    HazardType.tsunami: InariskLayer.tsunami,
    HazardType.longsor: InariskLayer.longsor,
    HazardType.gunungApi: InariskLayer.gunungApi,
    HazardType.cuacaEkstrem: InariskLayer.cuacaEkstrem,
  };

  @override
  Future<List<HazardIndexReading>> getHazardIndices({
    required double latitude,
    required double longitude,
    required List<HazardType> types,
  }) async {
    final layers = <InariskLayer>[];
    final layerToType = <InariskLayer, HazardType>{};
    for (final type in types) {
      final layer = _layerFor[type];
      if (layer == null) continue;
      layers.add(layer);
      layerToType[layer] = type;
    }
    if (layers.isEmpty) return const [];

    final result = await _service.identifyMany(
      layers: layers,
      latitude: latitude,
      longitude: longitude,
    );

    final readings = <HazardIndexReading>[];

    // Layer yang berhasil diambil nilainya.
    result.successes.forEach((layer, sample) {
      final type = layerToType[layer];
      if (type == null) return;
      readings.add(
        HazardIndexReading(
          type: type,
          index: sample.index,
          source: DataSource(
            name: 'InaRISK — BNPB',
            type: DataSourceType.officialHazardMap,
            retrievedAt: sample.retrievedAt,
            // InaRISK tidak menyertakan tanggal berlaku data di balasan
            // `identify`. Dibiarkan null — TIDAK diisi retrievedAt,
            // karena "kapan kami mengambil" berbeda dengan "kapan data
            // ini dibuat".
            dataTimestamp: null,
            datasetVersion: layer.serviceName,
            note: 'Indeks bahaya kawasan (raster 0–1). Bukan peringatan dini.',
          ),
        ),
      );
    });

    // Layer yang GAGAL DIAMBIL — tetap dikirim sebagai reading dengan
    // errorMessage, supaya UI bisa menunjukkan ALASAN gagal yang sebenarnya
    // alih-alih pesan generik.
    result.failures.forEach((layer, reason) {
      final type = layerToType[layer];
      // Lewati jika layer bukan yang diminta, atau jika sudah berhasil
      // (tidak mungkin keduanya ada sekaligus, tapi defensive check).
      if (type == null || result.successes.containsKey(layer)) return;
      readings.add(
        HazardIndexReading(
          type: type,
          index: null,
          errorMessage: reason,
          source: DataSource(
            name: 'InaRISK — BNPB',
            type: DataSourceType.officialHazardMap,
            retrievedAt: DateTime.now(),
            datasetVersion: layer.serviceName,
          ),
        ),
      );
    });

    return readings;
  }
}
