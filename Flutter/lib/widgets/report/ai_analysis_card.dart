import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/ai_analysis.dart';

class AiAnalysisCard extends StatelessWidget {
  final AiAnalysisResult result;
  const AiAnalysisCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 19),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'AI Analisis FloodGuard',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.answer,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.55),
          ),
          const SizedBox(height: 10),
          Text(
            '${result.model} • jawaban ${_formatTime(result.generatedAt)}',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
          ),
          if (result.realtime != null) ...[
            const SizedBox(height: 4),
            Text(
              _realtimeLabel(result.realtime!),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime value) {
    final local = value.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
  String _realtimeLabel(Map<String, dynamic> data) {
    final weather = data['weather'];
    if (weather is Map) {
      final source = weather['source']?.toString() ?? 'sumber cuaca';
      final updated = weather['last_updated']?.toString();
      if (updated != null && updated.isNotEmpty) {
        return 'Konteks realtime: $source • observasi $updated';
      }
      return 'Konteks realtime: $source';
    }
    return 'Konteks realtime diperbarui saat pertanyaan dikirim';
  }

}
