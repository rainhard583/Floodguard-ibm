import '../models/data_source.dart';
import '../models/earthquake_risk_model.dart';
import '../models/hazard_analysis.dart';
import '../models/selected_location.dart';
import '../models/tsunami_risk_model.dart';
import '../models/weather_model.dart';
import '../models/tsunami_warning_event.dart';
import '../repositories/hazard_index_repository.dart';
import '../core/utils/geo.dart';

/// Masukan mentah untuk [RiskEngine] — semuanya boleh `null` kalau
/// sumbernya gagal/belum tersedia. Engine yang memutuskan bagaimana
/// menurunkan derajat kepercayaan hasilnya.
class RiskEngineInput {
  final SelectedLocation location;
  final List<HazardIndexReading> hazardIndices;
  final EarthquakeRisk? earthquakeRisk;
  final TsunamiRisk? tsunamiRisk;
  final Weather? weather;
  final List<TsunamiWarningEvent> tsunamiWarningEvents;

  const RiskEngineInput({
    required this.location,
    this.hazardIndices = const [],
    this.earthquakeRisk,
    this.tsunamiRisk,
    this.weather,
    this.tsunamiWarningEvents = const [],
  });
}

/// FloodGuard Risk Engine — lapisan RULE-BASED yang mengubah data mentah
/// dari berbagai sumber menjadi [HazardAnalysis] terstruktur.
///
/// PRINSIP YANG DIPEGANG:
///
/// 1. Level SELALU diturunkan dari angka yang ada, tidak pernah
///    di-hardcode per nama wilayah.
/// 2. Peta bahaya resmi (InaRISK) adalah penentu utama level. Data lain
///    (gempa USGS, cuaca) hanya menjadi FAKTOR PENJELAS, tidak menaikkan
///    atau menurunkan level resmi — supaya angka resmi tidak "dikoreksi"
///    diam-diam oleh heuristik kami sendiri.
/// 3. Kalau indeks resmi tidak ada, hasilnya "DATA TIDAK TERSEDIA" —
///    bukan tebakan dari faktor pendukung.
/// 4. Tidak ada prediksi waktu kejadian, khususnya gempa.
class RiskEngine {
  const RiskEngine();

  /// Ambang batas kelas indeks bahaya InaRISK.
  ///
  /// InaRISK mengklasifikasikan indeks 0..1 ke dalam TIGA kelas dengan
  /// batas 0.33 dan 0.66. Angka ini mengikuti klasifikasi sumbernya, dan
  /// sengaja tidak dipecah lebih halus supaya tidak mengarang tingkat
  /// granularitas yang tidak ada di data aslinya.
  static const _batasSedang = 0.33;
  static const _batasTinggi = 0.66;

  static HazardLevel _levelFromIndex(double? index) {
    if (index == null) return HazardLevel.tidakTersedia;
    if (index < _batasSedang) return HazardLevel.rendah;
    if (index < _batasTinggi) return HazardLevel.sedang;
    return HazardLevel.tinggi;
  }

  /// Pesan "tidak tersedia" yang ditampilkan ke user. Kalau ada alasan
  /// GAGAL yang sesungguhnya (mis. status HTTP, pesan error server),
  /// pakai itu — jangan tunjukkan pesan generik kalau kita sebenarnya
  /// tahu persis kenapa gagal.
  static String _unavailableReason(HazardIndexReading? reading, String fallback) {
    if (reading?.errorMessage != null) {
      return '$fallback\n\nDetail teknis: ${reading!.errorMessage}';
    }
    return fallback;
  }

  HazardAnalysis analyze(RiskEngineInput input) {
    final byType = {for (final r in input.hazardIndices) r.type: r};

    final hazards = <HazardResult>[
      _buildBanjir(byType[HazardType.banjir], input.weather),
      _buildGempa(byType[HazardType.gempaBumi], input.earthquakeRisk),
      _buildTsunami(byType[HazardType.tsunami], input.tsunamiRisk, input.tsunamiWarningEvents, input.location),
      _buildSederhana(
        HazardType.longsor,
        byType[HazardType.longsor],
        limitation: 'Indeks bahaya kawasan. Belum memperhitungkan kondisi lereng '
            'dan drainase di titik persisnya.',
      ),
      _buildSederhana(
        HazardType.gunungApi,
        byType[HazardType.gunungApi],
        limitation: 'Indeks bahaya kawasan. BUKAN status aktivitas gunung api '
            'terkini — status resmi ada di MAGMA Indonesia (PVMBG).',
      ),
      _buildCuacaEkstrem(byType[HazardType.cuacaEkstrem], input.weather),
    ];

    return HazardAnalysis(
      location: input.location,
      hazards: hazards,
      analyzedAt: DateTime.now(),
      // Model ML banjir belum dilatih dengan dataset valid, jadi tidak
      // ada kontribusi ML sama sekali di hasil ini.
      mlUsed: false,
    );
  }

  HazardResult _buildBanjir(HazardIndexReading? reading, Weather? weather) {
    if (reading == null || reading.index == null) {
      return HazardResult.unavailable(
        HazardType.banjir,
        reason: _unavailableReason(
          reading,
          'Indeks bahaya banjir InaRISK tidak tersedia untuk titik ini.',
        ),
      );
    }

    final factors = <RiskFactor>[
      RiskFactor(
        label: 'Indeks bahaya banjir',
        value: reading.index!.toStringAsFixed(3),
        source: 'InaRISK — BNPB',
      ),
    ];
    final sources = <DataSource>[reading.source];

    // Curah hujan adalah faktor PEMICU jangka pendek — ditampilkan
    // sebagai konteks, tapi TIDAK mengubah level indeks bahaya kawasan.
    if (weather != null) {
      factors.add(
        RiskFactor(
          label: 'Curah hujan saat ini',
          value: '${weather.rainfallMm.toStringAsFixed(1)} mm',
          source: weather.source,
        ),
      );
      sources.add(
        DataSource(
          name: weather.source,
          type: DataSourceType.forecastModel,
          retrievedAt: DateTime.now(),
          dataTimestamp: weather.updatedAt,
          note: 'Kondisi cuaca sebagai faktor pemicu jangka pendek.',
        ),
      );
    }

    return HazardResult(
      type: HazardType.banjir,
      level: _levelFromIndex(reading.index),
      hazardIndex: reading.index,
      factors: factors,
      limitation: 'Indeks bahaya kawasan, bukan prediksi genangan di alamat '
          'persisnya. Belum memperhitungkan drainase lokal, kondisi sungai, '
          'maupun riwayat banjir titik ini.',
      sources: sources,
    );
  }

  HazardResult _buildGempa(HazardIndexReading? reading, EarthquakeRisk? eq) {
    if (reading == null || reading.index == null) {
      return HazardResult.unavailable(
        HazardType.gempaBumi,
        reason: _unavailableReason(
          reading,
          'Indeks bahaya gempa bumi InaRISK tidak tersedia untuk titik ini.',
        ),
      );
    }

    final factors = <RiskFactor>[
      RiskFactor(
        label: 'Indeks bahaya gempa',
        value: reading.index!.toStringAsFixed(3),
        source: 'InaRISK — BNPB',
      ),
    ];
    final sources = <DataSource>[reading.source];

    if (eq != null) {
      factors.add(
        RiskFactor(
          label: 'Gempa tercatat terdekat',
          value: '±${eq.distanceKm.toStringAsFixed(1)} km',
          source: 'BMKG — Data Gempabumi Terbuka',
        ),
      );
      sources.add(
        DataSource(
          name: 'BMKG — Data Gempabumi Terbuka',
          type: DataSourceType.eventCatalog,
          retrievedAt: eq.updatedAt,
          note: 'Riwayat gempa yang SUDAH terjadi. Bukan prediksi gempa.',
        ),
      );
    }

    return HazardResult(
      type: HazardType.gempaBumi,
      level: _levelFromIndex(reading.index),
      hazardIndex: reading.index,
      factors: factors,
      limitation: 'Ini tingkat BAHAYA SEISMIK kawasan (seberapa terpapar lokasi '
          'ini terhadap guncangan), BUKAN prediksi kapan gempa akan terjadi. '
          'Waktu terjadinya gempa tidak dapat diprediksi oleh siapa pun.',
      sources: sources,
    );
  }

  HazardResult _buildTsunami(
    HazardIndexReading? reading,
    TsunamiRisk? tsunami,
    List<TsunamiWarningEvent> warningEvents,
    SelectedLocation inputLocation,
  ) {
    if (reading == null || reading.index == null) {
      return HazardResult.unavailable(
        HazardType.tsunami,
        reason: _unavailableReason(
          reading,
          'Indeks bahaya tsunami InaRISK tidak tersedia untuk titik ini. '
              'Wilayah pedalaman umumnya memang di luar cakupan peta ini.',
        ),
      );
    }

    final factors = <RiskFactor>[
      RiskFactor(
        label: 'Indeks bahaya tsunami',
        value: reading.index!.toStringAsFixed(3),
        source: 'InaRISK — BNPB',
      ),
    ];
    final sources = <DataSource>[reading.source];

    if (tsunami != null) {
      factors.add(
        RiskFactor(
          label: 'Perkiraan jarak ke pantai',
          value: '±${tsunami.distanceKm.toStringAsFixed(1)} km',
          source: 'Elevasi Open-Meteo',
        ),
      );
      sources.add(
        DataSource(
          name: 'Open-Meteo Elevation',
          type: DataSourceType.terrainData,
          retrievedAt: tsunami.updatedAt,
          note: 'Perkiraan jarak ke garis pantai dari data elevasi.',
        ),
      );
    }

    if (warningEvents.isNotEmpty) {
      final nearest = _nearestWarningEvent(inputLocation: inputLocation, events: warningEvents);
      factors.add(
        RiskFactor(
          label: 'Feed BMKG terbaru',
          value: nearest == null
              ? '${warningEvents.length} event berpotensi tsunami'
              : 'M${nearest.event.magnitude.toStringAsFixed(1)} • ±${nearest.distanceKm.toStringAsFixed(0)} km',
          source: 'BMKG — Data Gempabumi Terbuka',
        ),
      );
      sources.add(
        DataSource(
          name: 'BMKG — Data Gempabumi Terbuka',
          type: DataSourceType.officialWarning,
          retrievedAt: DateTime.now(),
          dataTimestamp: nearest?.event.time,
          note: 'Kejadian terbaru yang pada feed BMKG ditandai berpotensi tsunami; bukan pengganti buletin peringatan resmi.',
        ),
      );
    }

    return HazardResult(
      type: HazardType.tsunami,
      level: _levelFromIndex(reading.index),
      hazardIndex: reading.index,
      factors: factors,
      limitation: 'Ini peta bahaya kawasan. BUKAN peringatan dini tsunami. '
          'Peringatan resmi hanya berasal dari BMKG (InaTEWS) dan selalu '
          'harus diikuti lebih dulu.',
      sources: sources,
    );
  }

  _WarningDistance? _nearestWarningEvent({
    required SelectedLocation inputLocation,
    required List<TsunamiWarningEvent> events,
  }) {
    if (events.isEmpty) return null;
    _WarningDistance? nearest;
    for (final event in events) {
      final distance = haversineDistanceKm(
        inputLocation.latitude,
        inputLocation.longitude,
        event.latitude,
        event.longitude,
      );
      if (nearest == null || distance < nearest.distanceKm) {
        nearest = _WarningDistance(event: event, distanceKm: distance);
      }
    }
    return nearest;
  }

  HazardResult _buildCuacaEkstrem(HazardIndexReading? reading, Weather? weather) {
    if (reading == null || reading.index == null) {
      return HazardResult.unavailable(
        HazardType.cuacaEkstrem,
        reason: _unavailableReason(
          reading,
          'Indeks bahaya cuaca ekstrem InaRISK tidak tersedia untuk titik ini.',
        ),
      );
    }

    final factors = <RiskFactor>[
      RiskFactor(
        label: 'Indeks bahaya cuaca ekstrem',
        value: reading.index!.toStringAsFixed(3),
        source: 'InaRISK — BNPB',
      ),
    ];
    final sources = <DataSource>[reading.source];

    if (weather != null) {
      factors.add(
        RiskFactor(
          label: 'Angin saat ini',
          value: '${weather.windKph.toStringAsFixed(1)} km/j',
          source: weather.source,
        ),
      );
      sources.add(
        DataSource(
          name: weather.source,
          type: DataSourceType.forecastModel,
          retrievedAt: DateTime.now(),
          dataTimestamp: weather.updatedAt,
        ),
      );
    }

    return HazardResult(
      type: HazardType.cuacaEkstrem,
      level: _levelFromIndex(reading.index),
      hazardIndex: reading.index,
      factors: factors,
      limitation: 'Indeks bahaya kawasan. Peringatan cuaca ekstrem harian '
          'tetap mengacu pada BMKG.',
      sources: sources,
    );
  }

  HazardResult _buildSederhana(
    HazardType type,
    HazardIndexReading? reading, {
    required String limitation,
  }) {
    if (reading == null || reading.index == null) {
      return HazardResult.unavailable(
        type,
        reason: _unavailableReason(
          reading,
          'Indeks bahaya ${type.label.toLowerCase()} InaRISK tidak tersedia '
              'untuk titik ini.',
        ),
      );
    }

    return HazardResult(
      type: type,
      level: _levelFromIndex(reading.index),
      hazardIndex: reading.index,
      factors: [
        RiskFactor(
          label: 'Indeks bahaya ${type.label.toLowerCase()}',
          value: reading.index!.toStringAsFixed(3),
          source: 'InaRISK — BNPB',
        ),
      ],
      limitation: limitation,
      sources: [reading.source],
    );
  }
}


class _WarningDistance {
  final TsunamiWarningEvent event;
  final double distanceKm;
  const _WarningDistance({required this.event, required this.distanceKm});
}
