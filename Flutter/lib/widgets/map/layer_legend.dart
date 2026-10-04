import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/map_layer_type.dart';

/// Legend generik untuk satu layer — dipakai lewat [LayerConfig], BUKAN
/// di-hardcode per layer di MapScreen/widget lain.
class LayerLegend extends StatelessWidget {
  final LayerConfig config;
  final List<String> steps;

  const LayerLegend({super.key, required this.config, required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(color: config.legendColor, shape: BoxShape.circle),
          ),
          for (final step in steps)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(step, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
            ),
          if (config.unit != null)
            Text(config.unit!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

/// Badge kecil "Source: X · Updated Y" — WAJIB dipasang di setiap kartu
/// data supaya user tidak pernah bingung mana observasi vs forecast.
class DataSourceBadge extends StatelessWidget {
  final String source;
  final DataOrigin origin;
  final String updatedLabel;

  const DataSourceBadge({
    super.key,
    required this.source,
    required this.origin,
    required this.updatedLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '${origin.label} · $source · $updatedLabel',
      style: const TextStyle(color: AppColors.textSecondary, fontSize: 10.5),
    );
  }
}
