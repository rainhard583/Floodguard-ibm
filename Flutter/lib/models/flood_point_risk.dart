import 'package:flutter/foundation.dart';

@immutable
class FloodPointRisk {
  final bool available;
  final String answer;
  final double? hazardIndex;
  final String? hazardClass;
  final double? riskIndex;
  final String? riskClass;
  final String source;
  final String explanation;
  final int? layerResolutionM;
  final DateTime? checkedAt;

  const FloodPointRisk({
    required this.available,
    required this.answer,
    this.hazardIndex,
    this.hazardClass,
    this.riskIndex,
    this.riskClass,
    required this.source,
    required this.explanation,
    this.layerResolutionM,
    this.checkedAt,
  });

  factory FloodPointRisk.fromJson(Map<String, dynamic> json) {
    final checked = json['checked_at']?.toString();
    return FloodPointRisk(
      available: json['available'] == true,
      answer: json['answer']?.toString() ?? 'BELUM DAPAT DITENTUKAN',
      hazardIndex: _number(json['hazard_index']),
      hazardClass: json['hazard_class']?.toString(),
      riskIndex: _number(json['risk_index']),
      riskClass: json['risk_class']?.toString(),
      source: json['source']?.toString() ?? 'BNPB InaRISK',
      explanation: json['explanation']?.toString() ?? 'Data belum tersedia.',
      layerResolutionM: json['layer_resolution_m'] is num
          ? (json['layer_resolution_m'] as num).round()
          : null,
      checkedAt: checked == null ? null : DateTime.tryParse(checked),
    );
  }

  static double? _number(dynamic value) => value is num ? value.toDouble() : double.tryParse('$value');
}
