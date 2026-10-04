import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../models/flood_point_risk.dart';

class FloodPointRiskService {
  final http.Client _client;
  FloodPointRiskService({http.Client? client}) : _client = client ?? http.Client();

  Future<FloodPointRisk> check({required double latitude, required double longitude}) async {
    final uri = Uri.parse(ApiConfig.floodRiskPointUrl).replace(queryParameters: {
      'latitude': latitude.toStringAsFixed(6),
      'longitude': longitude.toStringAsFixed(6),
    });

    try {
      final response = await _client.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 20));
      final decoded = jsonDecode(response.body);
      final body = decoded is Map<String, dynamic> ? decoded : Map<String, dynamic>.from(decoded as Map);
      if (response.statusCode < 200 || response.statusCode >= 300 || body['success'] != true) {
        throw FloodPointRiskException(body['error']?.toString() ?? 'Pemeriksaan risiko banjir gagal.');
      }
      final result = body['result'];
      if (result is! Map) throw const FloodPointRiskException('Respons risiko banjir tidak valid.');
      return FloodPointRisk.fromJson(Map<String, dynamic>.from(result));
    } on FloodPointRiskException {
      rethrow;
    } catch (e) {
      throw FloodPointRiskException('Tidak dapat menghubungi server FloodGuard: $e');
    }
  }

  void dispose() => _client.close();
}

class FloodPointRiskException implements Exception {
  final String message;
  const FloodPointRiskException(this.message);
  @override
  String toString() => message;
}
