import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Header kecil di atas tiap section Home (mis. "Cuaca", "Peringatan
/// Aktif"). Dibuat reusable supaya style judul section konsisten dan
/// gampang menambah action di kanan (mis. "Lihat semua") nanti.
class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionHeader({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
