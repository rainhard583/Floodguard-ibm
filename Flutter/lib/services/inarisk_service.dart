import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';

enum InariskLayer {
  banjir('INDEKS_BAHAYA_BANJIR', 'Indeks Bahaya Banjir'),
  gempaBumi('INDEKS_BAHAYA_GEMPABUMI', 'Indeks Bahaya Gempa Bumi'),
  tsunami('INDEKS_BAHAYA_TSUNAMI', 'Indeks Bahaya Tsunami'),
  longsor('INDEKS_BAHAYA_TANAHLONGSOR', 'Indeks Bahaya Tanah Longsor'),
  gunungApi('INDEKS_BAHAYA_GUNUNGAPI', 'Indeks Bahaya Gunung Api'),
  cuacaEkstrem('INDEKS_BAHAYA_CUACAEKSTRIM', 'Indeks Bahaya Cuaca Ekstrem');

  final String serviceName;
  final String displayName;
  const InariskLayer(this.serviceName, this.displayName);
}

class InariskSample {
  final double? index;
  final DateTime retrievedAt;
  final String method;

  const InariskSample({required this.index, required this.retrievedAt, required this.method});

  bool get hasValue => index != null;
}

/// Hasil [InariskService.identifyMany].
///
/// Memisahkan data yang berhasil ([successes]) dari kegagalan per-layer
/// ([failures]) agar tidak perlu mutable field di service — request yang
/// berjalan bersamaan tidak saling mencampur hasil.
class InariskResult {
  /// Layer yang berhasil diambil nilainya.
  final Map<InariskLayer, InariskSample> successes;

  /// Layer yang gagal: key = layer, value = pesan alasan kegagalan.
  final Map<InariskLayer, String> failures;

  const InariskResult({
    required this.successes,
    required this.failures,
  });
}

/// InaRISK client.
///
/// IMPORTANT: Flutter tidak lagi memanggil gis.bnpb.go.id secara langsung.
/// Mobile -> Laravel -> InaRISK. Ini menghindari HTTP 521 yang muncul pada
/// request langsung dari HP dan membuat endpoint BNPB terpusat di backend.
class InariskService {
  final http.Client _client;
  final Duration timeout;

  InariskService({http.Client? client, this.timeout = const Duration(seconds: 25)})
      : _client = client ?? http.Client();

  /// Mengambil indeks bahaya untuk semua [layers] pada koordinat yang
  /// diberikan. Mengembalikan [InariskResult] yang berisi data berhasil
  /// ([successes]) dan kegagalan per-layer ([failures]) — tidak ada mutable
  /// state di service sehingga aman untuk request bersamaan.
  Future<InariskResult> identifyMany({
    required List<InariskLayer> layers,
    required double latitude,
    required double longitude,
  }) async {
    final uri = Uri.parse(ApiConfig.inariskUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      },
    );

    http.Response response;
    try {
      response = await _client.get(
        uri,
        headers: const {
          'Accept': 'application/json',
          'Cache-Control': 'no-cache',
          'Pragma': 'no-cache',
        },
      ).timeout(timeout);
    } catch (e) {
      final failures = {
        for (final layer in layers)
          layer: 'Server FloodGuard InaRISK tidak dapat dihubungi: $e',
      };
      return InariskResult(successes: const {}, failures: failures);
    }

    final body = _decode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300 || body == null) {
      final message = body?['error']?.toString() ??
          'Endpoint InaRISK FloodGuard mengembalikan HTTP ${response.statusCode}.';
      final failures = {for (final layer in layers) layer: message};
      return InariskResult(successes: const {}, failures: failures);
    }

    final rawLayers = body['layers'];
    if (rawLayers is! Map) {
      const reason = 'Respons InaRISK FloodGuard tidak memiliki data layers.';
      final failures = {for (final layer in layers) layer: reason};
      return InariskResult(successes: const {}, failures: failures);
    }

    final successes = <InariskLayer, InariskSample>{};
    final failures = <InariskLayer, String>{};

    for (final layer in layers) {
      final raw = rawLayers[layer.serviceName];
      if (raw is! Map) {
        failures[layer] = 'Layer ${layer.serviceName} tidak ada dalam respons InaRISK.';
        continue;
      }

      final index = _double(raw['index']);
      final error = raw['error']?.toString().trim();
      if (index == null) {
        failures[layer] = error?.isNotEmpty == true
            ? error!
            : 'InaRISK tidak mengembalikan nilai pada titik ini.';
        continue;
      }

      successes[layer] = InariskSample(
        index: index,
        retrievedAt: DateTime.tryParse(raw['retrieved_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
        method: raw['method']?.toString() ?? 'Get Samples via Laravel',
      );
    }

    return InariskResult(successes: successes, failures: failures);
  }

  Map<String, dynamic>? _decode(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
    } catch (e) {
      debugPrint('[InariskService] JSON decode gagal: $e');
    }
    return null;
  }

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  void dispose() => _client.close();
}

class InariskException implements Exception {
  final String message;
  const InariskException(this.message);

  @override
  String toString() => message;
}
