import '../models/data_source.dart';
import '../models/hazard_analysis.dart';

/// Nilai indeks bahaya resmi untuk satu jenis bahaya di satu titik.
class HazardIndexReading {
  final HazardType type;

  /// Indeks 0..1 dari peta bahaya resmi. `null` = di luar cakupan data.
  final double? index;
  final DataSource source;

  /// Alasan gagal (kalau [index] null karena pengambilan data gagal,
  /// bukan karena titiknya memang di luar cakupan raster). Ditampilkan
  /// apa adanya di UI supaya kegagalan bisa ditelusuri, bukan cuma
  /// "tidak tersedia" tanpa penjelasan.
  final String? errorMessage;

  const HazardIndexReading({
    required this.type,
    required this.index,
    required this.source,
    this.errorMessage,
  });
}

/// Kontrak sumber peta bahaya resmi (saat ini: InaRISK/BNPB).
///
/// Dipisah dari [InariskService] supaya kalau nanti ada sumber bahaya
/// resmi lain, Risk Engine tidak perlu diubah sama sekali.
abstract class HazardIndexRepository {
  /// Baca indeks bahaya untuk semua [types] yang diminta di satu titik.
  ///
  /// Implementasi TIDAK BOLEH menebak nilai untuk tipe yang gagal
  /// diambil — cukup tidak menyertakannya di hasil.
  Future<List<HazardIndexReading>> getHazardIndices({
    required double latitude,
    required double longitude,
    required List<HazardType> types,
  });
}
