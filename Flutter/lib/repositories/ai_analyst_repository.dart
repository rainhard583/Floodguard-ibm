import '../models/ai_analysis.dart';
import '../models/hazard_analysis.dart';
import '../models/selected_location.dart';
import '../services/ai_analyst_service.dart';

abstract class AiAnalystRepository {
  Future<AiAnalysisResult> analyze({
    SelectedLocation? location,
    HazardAnalysis? analysis,
    String question,
  });
}

class HttpAiAnalystRepository implements AiAnalystRepository {
  final AiAnalystService _service;

  HttpAiAnalystRepository({AiAnalystService? service})
      : _service = service ?? AiAnalystService();

  @override
  Future<AiAnalysisResult> analyze({
    SelectedLocation? location,
    HazardAnalysis? analysis,
    String question = '',
  }) {
    return _service.analyze(
      location: location,
      analysis: analysis,
      question: question,
    );
  }
}
