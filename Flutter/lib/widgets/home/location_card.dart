import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/relative_time.dart';
import '../../models/app_location_model.dart';

class LocationCard extends StatelessWidget {
  final AsyncValue<AppLocation> location;
  final VoidCallback? onRetry;
  final VoidCallback? onChangeLocation;
  const LocationCard({super.key, required this.location, this.onRetry, this.onChangeLocation});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: [BoxShadow(color: const Color(0xFF6D9ACB).withValues(alpha: .10), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: location.when(
        loading: () => _row(Icons.location_searching_rounded, AppColors.textSecondary, 'Mencari lokasi...', null, null),
        error: (_, __) => _row(Icons.location_off_rounded, AppColors.riskBahaya, 'Gagal memuat lokasi', 'Ketuk untuk coba lagi', onRetry),
        data: (data) {
          switch (data.status) {
            case LocationStatus.permissionRequired:
              return _row(Icons.pin_drop_rounded, AppColors.riskWaspada, 'Izin lokasi diperlukan', 'Aktifkan izin lokasi', onChangeLocation);
            case LocationStatus.unavailable:
              return _row(Icons.location_off_rounded, AppColors.textSecondary, 'Lokasi belum tersedia', 'Pilih lokasi secara manual', onChangeLocation);
            case LocationStatus.available:
              return _row(Icons.location_on_rounded, AppColors.primary, data.label ?? 'Lokasi tidak diketahui', 'Diperbarui ${formatRelativeTime(data.updatedAt)}', onChangeLocation);
          }
        },
      ),
    ).animate().fadeIn().slideY(begin: .03, end: 0);
  }

  Widget _row(IconData icon, Color color, String title, String? subtitle, VoidCallback? action) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: color.withValues(alpha: .10), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        Material(
          color: AppColors.primarySoft,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: action,
            child: const SizedBox(width: 42, height: 42, child: Icon(Icons.chevron_right_rounded, color: AppColors.primary, size: 25)),
          ),
        ),
      ],
    );
  }
}
