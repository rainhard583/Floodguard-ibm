import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/hazard_analysis.dart';

/// Kartu hasil satu jenis bahaya. Bisa dibuka (expand) untuk melihat
/// faktor & keterbatasan.
///
/// Keterbatasan SENGAJA ditaruh di dalam kartu yang sama, bukan di
/// footer terpisah — supaya user membacanya bersama levelnya, bukan
/// setelah terlanjur menyimpulkan.
class HazardResultCard extends StatefulWidget {
  final HazardResult result;

  const HazardResultCard({super.key, required this.result});

  @override
  State<HazardResultCard> createState() => _HazardResultCardState();
}

class _HazardResultCardState extends State<HazardResultCard> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    // Kartu yang GAGAL (tidak ada data) otomatis terbuka — kalau
    // ditutup, satu-satunya info penting (alasan gagalnya) tersembunyi
    // dan user cuma melihat "DATA TIDAK TERSEDIA" tanpa penjelasan.
    // Kartu yang punya data tetap tertutup dulu supaya tidak penuh.
    _expanded = widget.result.level == HazardLevel.tidakTersedia;
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final available = r.level != HazardLevel.tidakTersedia;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: r.level.color.withOpacity(0.15),
                    ),
                    child: Icon(r.type.icon, color: r.level.color, size: 19),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.type.label,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: r.level.color.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                r.level.label,
                                style: TextStyle(
                                  color: r.level.color,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (r.hazardIndex != null) ...[
                              const SizedBox(width: 8),
                              Text(
                                'indeks ${r.hazardIndex!.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (available)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: _levelBar(r.level),
            ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r.factors.isNotEmpty) ...[
                    const Text(
                      'Faktor yang dipakai',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final f in r.factors)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                f.label,
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            Text(
                              f.value,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                  if (r.limitation != null)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.textSecondary, size: 14),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              r.limitation!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Bar 3 segmen — mengikuti 3 kelas resmi InaRISK, bukan 5.
  Widget _levelBar(HazardLevel level) {
    return Row(
      children: List.generate(3, (i) {
        final filled = i < level.step;
        return Expanded(
          child: Container(
            height: 5,
            margin: EdgeInsets.only(right: i < 2 ? 5 : 0),
            decoration: BoxDecoration(
              color: filled ? level.color : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}
