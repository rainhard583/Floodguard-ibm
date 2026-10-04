import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/relative_time.dart';
import '../../models/flood_risk_model.dart';
import '../states/app_error_view.dart';
import '../states/app_loading_view.dart';

class FloodRiskCard extends StatelessWidget {
  final AsyncValue<FloodRisk?> risk;
  final VoidCallback? onRetry;
  const FloodRiskCard({super.key, required this.risk, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFFFFFFF), Color(0xFFF0FFF8)]),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5FFF0)),
        boxShadow: [BoxShadow(color: const Color(0xFF54B88B).withValues(alpha: .10), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: risk.when(
        loading: () => const SizedBox(height: 140, child: AppLoadingView()),
        error: (_, __) => SizedBox(height: 170, child: AppErrorView(message: 'Gagal memuat data risiko banjir.', onRetry: onRetry)),
        data: (data) => data == null
            ? const SizedBox(height: 100, child: Center(child: Text('Risiko banjir belum tersedia untuk lokasi ini.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 13))))
            : _RiskContent(risk: data),
      ),
    ).animate().fadeIn().slideY(begin: .03, end: 0);
  }
}

class _RiskContent extends StatelessWidget {
  final FloodRisk risk;
  const _RiskContent({required this.risk});

  @override
  Widget build(BuildContext context) {
    final level = risk.level;
    return Stack(
      children: [
        Positioned(right: -6, top: 4, child: Opacity(opacity: .08, child: Icon(Icons.location_city_rounded, size: 118, color: level.color))),
        Positioned(right: 34, top: 30, child: Opacity(opacity: .10, child: Icon(Icons.water_rounded, size: 72, color: AppColors.primary))),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 58, height: 58, decoration: BoxDecoration(color: level.color.withValues(alpha: .13), shape: BoxShape.circle), child: Icon(level.icon, color: level.color, size: 29)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: level.color.withValues(alpha: .14), borderRadius: BorderRadius.circular(999)), child: Text(level.label, style: TextStyle(color: level.color, fontSize: 12, fontWeight: FontWeight.w900))),
                const SizedBox(width: 8),
                Text('Skor ${risk.score}/100', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 5),
              Text('Diperbarui ${formatRelativeTime(risk.updatedAt)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
            ])),
          ]),
          const SizedBox(height: 15),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (risk.score.clamp(0, 100)) / 100, minHeight: 8, backgroundColor: const Color(0xFFE2EBF4), valueColor: AlwaysStoppedAnimation(level.color))),
          const SizedBox(height: 14),
          Text(risk.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45)),
        ]),
      ],
    );
  }
}
