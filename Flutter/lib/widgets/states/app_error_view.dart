import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';

/// Error state standar: ikon, pesan yang manusiawi (bukan "Exception: ..."),
/// dan tombol coba lagi opsional. Icon bisa disesuaikan konteks (misal
/// Icons.wifi_off_rounded untuk error koneksi).
class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba Lagi',
    this.icon = Icons.error_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.riskBahaya.withOpacity(0.15),
              ),
              child: Icon(icon, color: AppColors.riskBahaya, size: 28),
            ).animate().fadeIn(duration: 300.ms).scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
            ).animate().fadeIn(delay: 150.ms),
            if (onRetry != null) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.primary),
                label: Text(
                  retryLabel,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ).animate().fadeIn(delay: 250.ms),
            ],
          ],
        ),
      ),
    );
  }
}
