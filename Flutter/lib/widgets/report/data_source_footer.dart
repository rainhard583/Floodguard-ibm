import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/relative_time.dart';
import '../../models/data_source.dart';

/// Daftar sumber data yang BENAR-BENAR dipakai pada satu analisis.
///
/// Sumber yang gagal diambil tidak pernah sampai ke sini — Risk Engine
/// hanya melampirkan [DataSource] untuk panggilan yang berhasil.
class DataSourceFooter extends StatelessWidget {
  final List<DataSource> sources;
  final bool mlUsed;

  const DataSourceFooter({super.key, required this.sources, required this.mlUsed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sumber Data',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (sources.isEmpty)
            const Text(
              'Tidak ada sumber data yang berhasil diambil.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
            ),
          for (final s in sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${s.type.label} · diambil ${formatRelativeTime(s.retrievedAt)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
                  ),
                  if (s.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        s.note!,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 10.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const Divider(height: 18, color: AppColors.surfaceElevated),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                mlUsed ? Icons.memory_rounded : Icons.science_outlined,
                color: AppColors.textSecondary,
                size: 14,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  mlUsed
                      ? 'Analisis ini menyertakan keluaran model ML FloodGuard.'
                      : 'Analisis ini BELUM memakai model ML. Seluruh tingkat bahaya '
                          'di atas dibaca langsung dari peta bahaya resmi dan katalog '
                          'kejadian, tanpa prediksi buatan FloodGuard.',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
