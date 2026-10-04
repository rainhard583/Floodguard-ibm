import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/ai_analysis.dart';
import '../models/hazard_analysis.dart';
import '../models/selected_location.dart';
import '../repositories/ai_analyst_repository.dart';

final aiAnalystRepositoryProvider = Provider<AiAnalystRepository>((ref) {
  return HttpAiAnalystRepository();
});

final aiAnalystProvider =
    FutureProvider.autoDispose.family<AiAnalysisResult, AiAnalystRequest>((ref, request) {
  return ref.watch(aiAnalystRepositoryProvider).analyze(
        location: request.location,
        analysis: request.analysis,
        question: request.question,
      );
});

class AiAnalystRequest {
  final SelectedLocation? location;
  final HazardAnalysis? analysis;
  final String question;

  const AiAnalystRequest({
    this.location,
    this.analysis,
    this.question = '',
  });

  @override
  bool operator ==(Object other) =>
      other is AiAnalystRequest &&
      other.location?.latitude == location?.latitude &&
      other.location?.longitude == location?.longitude &&
      other.analysis?.analyzedAt == analysis?.analyzedAt &&
      other.question == question;

  @override
  int get hashCode => Object.hash(
        location?.latitude,
        location?.longitude,
        analysis?.analyzedAt,
        question,
      );
}
