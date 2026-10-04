import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/relative_time.dart';
import '../../models/flood_alert_model.dart';
import '../../models/flood_risk_model.dart'; // dibutuhkan agar extension FloodRiskLevelX (.icon/.color/.label) terlihat di file ini
import '../states/app_empty_view.dart';
import '../states/app_error_view.dart';
import '../states/app_loading_view.dart';

/// Menampilkan daftar peringatan banjir aktif, atau state kosong/loading/
/// error yang sesuai. Bukan push notification sungguhan — hanya presentasi
/// data dari [floodAlertProvider] (Phase 12 akan mengisi sumber data & push
/// notification asli).
class AlertList extends StatelessWidget {
  final AsyncValue<List<FloodAlert>> alerts;
  final VoidCallback? onRetry;

  const AlertList({super.key, required this.alerts, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return alerts.when(
      loading: () => const SizedBox(height: 100, child: AppLoadingView()),
      error: (error, _) => SizedBox(
        height: 120,
        child: AppErrorView(message: 'Gagal memuat data.', onRetry: onRetry),
      ),
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox(
            height: 110,
            child: AppEmptyView(
              icon: Icons.notifications_off_outlined,
              title: 'Tidak ada peringatan banjir aktif',
            ),
          );
        }
        return Column(
          children: [
            for (final alert in data) ...[
              _AlertCard(alert: alert),
              if (alert != data.last) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  final FloodAlert alert;
  const _AlertCard({required this.alert});

  @override
  Widget build(BuildContext context) {
    final color = alert.severity.color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(alert.severity.icon, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alert.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  alert.severity.label,
                  style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.message,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.place_outlined, color: AppColors.textSecondary, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  alert.location,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
                ),
              ),
              Text(
                formatRelativeTime(alert.timestamp),
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }
}
