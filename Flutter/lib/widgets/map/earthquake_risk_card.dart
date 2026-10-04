import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/relative_time.dart';
import '../../models/earthquake_risk_model.dart';
import '../states/app_error_view.dart';
import '../states/app_loading_view.dart';
import 'earthquake_pulse_indicator.dart';
import 'likert_scale_bar.dart';

/// Kartu risiko gempa bumi untuk lokasi yang dipilih di Peta.
///
/// Data NYATA dari USGS Earthquake Catalog — lihat catatan di
/// [EarthquakeRisk]/[UsgsEarthquakeRiskRepository].
class EarthquakeRiskCard extends StatelessWidget {
  final AsyncValue<EarthquakeRisk?> risk;
  final VoidCallback? onRetry;

  const EarthquakeRiskCard({super.key, required this.risk, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: risk.when(
        loading: () => const SizedBox(height: 90, child: AppLoadingView()),
        error: (error, _) => SizedBox(
          height: 100,
          child: AppErrorView(message: 'Gagal memuat risiko gempa.', onRetry: onRetry),
        ),
        data: (data) {
          if (data == null) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Risiko gempa belum tersedia untuk lokasi ini.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.vibration_rounded, color: AppColors.primary, size: 18),
                  const SizedBox(width: 8),
                  const Text(
                    'Aktivitas Gempa Bumi',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    formatRelativeTime(data.updatedAt),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                  if (onRetry != null)
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary, size: 18),
                      tooltip: 'Muat ulang',
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                      onPressed: onRetry,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  EarthquakePulseIndicator(level: data.level),
                  const SizedBox(width: 14),
                  Expanded(child: LikertScaleBar(level: data.level)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '±${data.distanceKm.toStringAsFixed(1)} km dari pusat gempa terdekat yang tercatat',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Text(
                data.description,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4),
              ),
            ],
          );
        },
      ),
    );
  }
}
