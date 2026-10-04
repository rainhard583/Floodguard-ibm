import 'package:flutter/foundation.dart';

/// Jenis sumber data — menentukan seberapa kuat sebuah angka boleh
/// "dipercaya" dan bagaimana UI harus menyebutnya.
enum DataSourceType {
  /// Peta bahaya resmi pemerintah (mis. indeks bahaya InaRISK/BNPB).
  officialHazardMap,

  /// Peringatan/kejadian resmi (mis. BMKG). PRIORITAS TERTINGGI —
  /// tidak boleh ditimpa hasil model apa pun.
  officialWarning,

  /// Katalog kejadian yang SUDAH terjadi (mis. USGS earthquake catalog).
  eventCatalog,

  /// Keluaran model numerik cuaca/atmosfer (mis. Open-Meteo/ECMWF/CAMS).
  forecastModel,

  /// Data terrain/geospasial (mis. elevasi).
  terrainData,

  /// Model machine learning FloodGuard sendiri.
  mlModel,
}

extension DataSourceTypeX on DataSourceType {
  String get label {
    switch (this) {
      case DataSourceType.officialHazardMap:
        return 'Peta Bahaya Resmi';
      case DataSourceType.officialWarning:
        return 'Peringatan Resmi';
      case DataSourceType.eventCatalog:
        return 'Katalog Kejadian';
      case DataSourceType.forecastModel:
        return 'Model Prakiraan';
      case DataSourceType.terrainData:
        return 'Data Terrain';
      case DataSourceType.mlModel:
        return 'Model ML FloodGuard';
    }
  }
}

/// Jejak satu sumber data yang BENAR-BENAR dipakai dalam sebuah analisis.
///
/// Aturan: jangan pernah menampilkan sumber yang sebenarnya tidak
/// dipakai. Kalau sebuah panggilan gagal, sumbernya tidak boleh ikut
/// dicantumkan seolah-olah berhasil.
@immutable
class DataSource {
  final String name;
  final DataSourceType type;

  /// Kapan FloodGuard mengambil data ini.
  final DateTime retrievedAt;

  /// Kapan data ITU SENDIRI dibuat/berlaku menurut penyedianya. Bisa
  /// `null` kalau penyedia tidak memberi timestamp — jangan diisi
  /// [retrievedAt] sebagai pengganti, karena artinya berbeda.
  final DateTime? dataTimestamp;

  /// Versi/nama dataset kalau penyedia menyebutkannya.
  final String? datasetVersion;

  /// Catatan keterbatasan yang wajib diketahui user.
  final String? note;

  const DataSource({
    required this.name,
    required this.type,
    required this.retrievedAt,
    this.dataTimestamp,
    this.datasetVersion,
    this.note,
  });
}
