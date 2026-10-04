import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import '../models/ai_analysis.dart';
import '../models/hazard_analysis.dart';
import '../models/selected_location.dart';
import '../core/config/api_config.dart';

class AiAnalystService {
  static String get endpoint => ApiConfig.aiAnalyzeUrl;

  final http.Client _client;
  AiAnalystService({http.Client? client}) : _client = client ?? http.Client();

  bool get isConfigured => endpoint.trim().isNotEmpty;

  Future<AiAnalysisResult> analyze({
    SelectedLocation? location,
    HazardAnalysis? analysis,
    String question = '',
  }) async {
    if (!isConfigured) {
      throw const AiAnalystException('Server FloodGuard belum dikonfigurasi. Pastikan Laravel berjalan dan FLOODGUARD_API_URL sudah benar.');
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw const AiAnalystException('Sesi login tidak ditemukan. Silakan login kembali.');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw const AiAnalystException('Token login tidak tersedia. Silakan login kembali.');

    final hazardLines = analysis == null
        ? 'Tidak ada analisis risiko lokasi. Pertanyaan nasional/global boleh dijawab tanpa lokasi.'
        : analysis.hazards.map((h) {
            final factors = h.factors.map((f) => '${f.label}: ${f.value}').join(', ');
            return '- ${h.type.label}: level ${h.level.label}, indeks ${h.hazardIndex}. Faktor: $factors';
          }).join('\n');

    final locationLine = location == null
        ? 'Lokasi analisis: TIDAK DIPILIH. Jangan meminta lokasi untuk pertanyaan nasional/global.'
        : '''Lokasi: ${location.displayName ?? 'Lokasi terpilih'}
Koordinat: ${location.latitude}, ${location.longitude}''';

    final prompt = '''Analisis FloodGuard.

$locationLine
Waktu analisis: ${analysis?.analyzedAt.toIso8601String() ?? DateTime.now().toIso8601String()}
ML digunakan: ${analysis?.mlUsed ?? false}

Hasil analisis risiko lokasi:
$hazardLines

Pertanyaan pengguna: ${question.trim().isEmpty ? 'Berikan ringkasan kondisi.' : question.trim()}

Aturan:
- Pertanyaan gempa nasional/global tidak membutuhkan lokasi.
- Jangan mengarang data.
- Pertanyaan suhu sekarang harus memakai observasi current, bukan feels-like atau forecast.
- Fakta kejadian harus berasal dari data realtime backend.''';

    final userQuestion = question.trim();
    final payload = <String, dynamic>{
      'question': userQuestion,
      'message': userQuestion,
      'context': prompt,
      'latitude': location?.latitude,
      'longitude': location?.longitude,
      'location_name': location?.displayName,
      'realtime_required': true,
      'realtime_max_age_seconds': 60,
      'global_location_resolution': true,
      'client_requested_at': DateTime.now().toIso8601String(),
    };

    late final http.Response response;
    try {
      response = await _client.post(
        Uri.parse(endpoint),
        headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 75));
    } on http.ClientException catch (e) {
      throw AiAnalystException('Tidak dapat terhubung ke server AI FloodGuard ($endpoint): ${e.message}');
    } on FormatException {
      throw const AiAnalystException('Alamat server AI FloodGuard tidak valid.');
    } catch (e) {
      if (e.toString().toLowerCase().contains('timeout')) {
        throw AiAnalystException('Server AI FloodGuard tidak merespons dalam batas waktu. Periksa Laravel di $endpoint dan pastikan port 8000 dapat diakses HP.');
      }
      rethrow;
    }

    final body = _decodeObject(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiAnalystException(_errorMessage(response.statusCode, body));
    }
    if (body == null) throw const AiAnalystException('Respons server AI tidak valid.');

    final answer = body['analysis']?.toString().trim() ?? body['answer']?.toString().trim() ?? '';
    if (answer.isEmpty) throw const AiAnalystException('AI mengembalikan jawaban kosong.');

    return AiAnalysisResult(
      answer: answer,
      generatedAt: DateTime.tryParse(body['generatedAt']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      model: body['model']?.toString().trim().isNotEmpty == true ? body['model'].toString() : 'IBM Granite',
      realtime: body['realtime'] is Map ? Map<String, dynamic>.from(body['realtime'] as Map) : null,
    );
  }

  Map<String, dynamic>? _decodeObject(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  String _errorMessage(int statusCode, Map<String, dynamic>? body) {
    final serverMessage = body?['error']?.toString().trim();
    final message = serverMessage?.isNotEmpty == true ? serverMessage! : (body?['message']?.toString().trim() ?? '');
    if (message.isNotEmpty) return message;
    switch (statusCode) {
      case 401:
      case 403:
        return 'Akses ke layanan AI ditolak. Periksa sesi login FloodGuard.';
      case 404:
        return 'Endpoint FloodGuard tidak ditemukan. Periksa FLOODGUARD_API_URL.';
      case 429:
        return 'Permintaan AI sedang terlalu banyak. Coba lagi sebentar lagi.';
      default:
        return 'AI gagal memproses analisis (HTTP $statusCode).';
    }
  }

  void dispose() => _client.close();
}

class AiAnalystException implements Exception {
  final String message;
  const AiAnalystException(this.message);
  @override
  String toString() => message;
}
