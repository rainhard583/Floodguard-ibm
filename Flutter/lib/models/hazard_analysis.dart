import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'data_source.dart';
import 'selected_location.dart';

/// Jenis bahaya yang dianalisis FloodGuard.
enum HazardType { banjir, gempaBumi, tsunami, longsor, gunungApi, cuacaEkstrem }

extension HazardTypeX on HazardType {
  String get label {
    switch (this) {
      case HazardType.banjir:
        return 'Banjir';
      case HazardType.gempaBumi:
        return 'Gempa Bumi';
      case HazardType.tsunami:
        return 'Tsunami';
      case HazardType.longsor:
        return 'Tanah Longsor';
      case HazardType.gunungApi:
        return 'Gunung Api';
      case HazardType.cuacaEkstrem:
        return 'Cuaca Ekstrem';
    }
  }

  IconData get icon {
    switch (this) {
      case HazardType.banjir:
        return Icons.flood_rounded;
      case HazardType.gempaBumi:
        return Icons.vibration_rounded;
      case HazardType.tsunami:
        return Icons.tsunami_rounded;
      case HazardType.longsor:
        return Icons.landscape_rounded;
      case HazardType.gunungApi:
        return Icons.terrain_rounded;
      case HazardType.cuacaEkstrem:
        return Icons.thunderstorm_rounded;
    }
  }
}

/// Kelas tingkat bahaya.
///
/// SENGAJA hanya 3 kelas + "tidak tersedia", MENGIKUTI klasifikasi asli
/// InaRISK/BNPB (Rendah / Sedang / Tinggi). Tidak dipecah jadi 5 tingkat
/// seperti [DisasterRiskLevel] di Peta, karena memecah 3 kelas resmi
/// menjadi 5 berarti mengarang tingkat granularitas yang tidak ada di
/// data aslinya.
enum HazardLevel { rendah, sedang, tinggi, tidakTersedia }

extension HazardLevelX on HazardLevel {
  String get label {
    switch (this) {
      case HazardLevel.rendah:
        return 'RENDAH';
      case HazardLevel.sedang:
        return 'SEDANG';
      case HazardLevel.tinggi:
        return 'TINGGI';
      case HazardLevel.tidakTersedia:
        return 'DATA TIDAK TERSEDIA';
    }
  }

  Color get color {
    switch (this) {
      case HazardLevel.rendah:
        return AppColors.riskAman;
      case HazardLevel.sedang:
        return AppColors.riskWaspada;
      case HazardLevel.tinggi:
        return AppColors.riskBahaya;
      case HazardLevel.tidakTersedia:
        return AppColors.textSecondary;
    }
  }

  /// Posisi 1-3 untuk mengisi bar. 0 = tidak tersedia (bar kosong).
  int get step {
    switch (this) {
      case HazardLevel.rendah:
        return 1;
      case HazardLevel.sedang:
        return 2;
      case HazardLevel.tinggi:
        return 3;
      case HazardLevel.tidakTersedia:
        return 0;
    }
  }
}

/// Satu faktor yang MENJELASKAN kenapa sebuah level keluar seperti itu.
///
/// Ini yang nanti dikirim ke AI Analyst sebagai konteks — supaya LLM
/// menjelaskan faktor yang benar-benar dipakai engine, bukan mengarang
/// alasannya sendiri.
@immutable
class RiskFactor {
  final String label;

  /// Nilai apa adanya sebagai teks siap tampil (mis. "0.71", "±12.4 km",
  /// "84 mm/24 jam"). Disimpan sebagai String supaya satuan & presisi
  /// tidak hilang saat dioper antar layer.
  final String value;

  /// Dari mana nilai ini berasal.
  final String source;

  const RiskFactor({required this.label, required this.value, required this.source});
}

/// Hasil analisis untuk SATU jenis bahaya.
@immutable
class HazardResult {
  final HazardType type;
  final HazardLevel level;

  /// Nilai indeks mentah 0..1 dari peta bahaya resmi, kalau tersedia.
  /// Disimpan supaya UI/AI bisa menyebut angka aslinya, bukan cuma label.
  final double? hazardIndex;

  /// Faktor-faktor pendukung yang dipakai engine.
  final List<RiskFactor> factors;

  /// Keterbatasan spesifik hasil ini (mis. "belum memperhitungkan
  /// drainase lokal"). Wajib ditampilkan, tidak boleh disembunyikan.
  final String? limitation;

  /// Sumber data yang benar-benar berhasil dipakai untuk hasil ini.
  final List<DataSource> sources;

  const HazardResult({
    required this.type,
    required this.level,
    this.hazardIndex,
    this.factors = const [],
    this.limitation,
    this.sources = const [],
  });

  /// Hasil "data tidak tersedia" — dipakai saat sumber gagal/kosong.
  /// Lebih jujur daripada menebak level.
  factory HazardResult.unavailable(HazardType type, {String? reason}) {
    return HazardResult(
      type: type,
      level: HazardLevel.tidakTersedia,
      limitation: reason ?? 'Ketersediaan data untuk parameter ini belum mencukupi.',
    );
  }
}

/// Hasil analisis lengkap satu lokasi — keluaran Risk Engine.
@immutable
class HazardAnalysis {
  final SelectedLocation location;
  final List<HazardResult> hazards;
  final DateTime analyzedAt;

  /// `true` kalau model ML FloodGuard ikut dipakai. Saat ini SELALU
  /// false — model banjir belum dilatih dengan dataset valid, jadi UI
  /// wajib menyatakan analisis ini murni berbasis peta bahaya resmi +
  /// katalog kejadian, bukan prediksi ML.
  final bool mlUsed;

  const HazardAnalysis({
    required this.location,
    required this.hazards,
    required this.analyzedAt,
    this.mlUsed = false,
  });

  HazardResult? byType(HazardType type) {
    for (final h in hazards) {
      if (h.type == type) return h;
    }
    return null;
  }

  /// Semua sumber unik yang dipakai di seluruh analisis (berdasarkan
  /// nama) — untuk ditampilkan di bagian "Sumber Data".
  List<DataSource> get allSources {
    final seen = <String>{};
    final result = <DataSource>[];
    for (final h in hazards) {
      for (final s in h.sources) {
        if (seen.add(s.name)) result.add(s);
      }
    }
    return result;
  }
}
