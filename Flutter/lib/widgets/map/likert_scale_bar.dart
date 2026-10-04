import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/disaster_risk_level.dart';

/// Bar segmen 5-tingkat untuk menampilkan [DisasterRiskLevel] secara
/// visual. Segmen yang sudah "terlewati" (termasuk level saat ini)
/// disorot dengan warna level tsb; sisanya abu-abu netral.
///
/// AKSESIBILITAS: level TIDAK hanya ditandai lewat warna bar — selalu
/// disertai label teks di bawahnya (mis. "TINGGI") supaya tetap terbaca
/// oleh pengguna yang tidak bisa membedakan warna.
class LikertScaleBar extends StatelessWidget {
  final DisasterRiskLevel level;

  const LikertScaleBar({super.key, required this.level});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (index) {
            final segmentStep = index + 1;
            final filled = segmentStep <= level.step;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index == 4 ? 0 : 4),
                height: 8,
                decoration: BoxDecoration(
                  color: filled ? level.color : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: level.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                level.label,
                style: TextStyle(color: level.color, fontSize: 11.5, fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${level.step}/5',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}
