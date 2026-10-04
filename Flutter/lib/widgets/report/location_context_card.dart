import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_colors.dart';
import '../../models/selected_location.dart';

/// Kartu "lokasi yang sedang dianalisis". Koordinat yang ditampilkan
/// SELALU berasal dari lokasi asli yang dipilih user di Peta — tidak
/// pernah dummy.
class LocationContextCard extends StatelessWidget {
  final SelectedLocation? location;
  final bool analyzing;
  final VoidCallback onAnalyze;
  final VoidCallback onOpenMap;

  const LocationContextCard({
    super.key,
    required this.location,
    required this.analyzing,
    required this.onAnalyze,
    required this.onOpenMap,
  });

  @override
  Widget build(BuildContext context) {
    final loc = location;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Analisis Risiko Lokasi',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (loc == null) ..._empty(context) else ..._filled(context, loc),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  List<Widget> _empty(BuildContext context) {
    return [
      const Text(
        'Belum ada lokasi yang dipilih.',
        style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      const Text(
        'Buka Peta, cari wilayah yang ingin dianalisis (atau ketuk langsung '
        'di peta), lalu kembali ke sini.',
        style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5),
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: onOpenMap,
          icon: const Icon(Icons.map_rounded, size: 18),
          label: const Text('Pilih Lokasi di Peta'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
    ];
  }

  List<Widget> _filled(BuildContext context, SelectedLocation loc) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.location_on_rounded, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              loc.safeLabel,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _coordinate('Latitude', loc.formattedLatitude)),
          const SizedBox(width: 10),
          Expanded(child: _coordinate('Longitude', loc.formattedLongitude)),
        ],
      ),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: analyzing ? null : onAnalyze,
          icon: analyzing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.analytics_rounded, size: 18),
          label: Text(analyzing ? 'Menganalisis...' : 'Analisis Sekarang'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onOpenMap,
        icon: const Icon(Icons.edit_location_alt_rounded, size: 16),
        label: const Text('Ganti lokasi', style: TextStyle(fontSize: 12.5)),
        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
      ),
    ];
  }

  Widget _coordinate(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5)),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
