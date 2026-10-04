import 'package:flutter/foundation.dart';

@immutable
class AiAnalysisResult {
  final String answer;
  final DateTime generatedAt;
  final String model;
  final Map<String, dynamic>? realtime;

  const AiAnalysisResult({
    required this.answer,
    required this.generatedAt,
    required this.model,
    this.realtime,
  });
}
