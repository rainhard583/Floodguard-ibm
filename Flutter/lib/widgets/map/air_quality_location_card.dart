import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/air_quality_model.dart';

class AirQualityLocationCard extends StatelessWidget {
  final AirQuality? data;
  final VoidCallback? onRetry;
  final bool loading;
  final Object? error;

  const AirQualityLocationCard({super.key, this.data, this.onRetry, this.loading = false, this.error});

  @override
  Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
    if (error != null) {
      return Row(children: [const Expanded(child: Text('Data kualitas udara gagal dimuat.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))), TextButton(onPressed: onRetry, child: const Text('Coba lagi'))]);
    }
    if (data == null) return const Text('Data kualitas udara tidak tersedia untuk titik ini.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
    final items = <String, String>{
      'AQI': data!.europeanAqi.toString(),
      'PM2.5': '${data!.pm25.value.toStringAsFixed(1)} µg/m³',
      'PM10': '${data!.pm10.value.toStringAsFixed(1)} µg/m³',
      'SO₂': '${data!.so2.value.toStringAsFixed(1)} µg/m³',
      'NO₂': '${data!.no2.value.toStringAsFixed(1)} µg/m³',
      'CO': '${data!.co.value.toStringAsFixed(0)} µg/m³',
      'O₃': '${data!.ozone.value.toStringAsFixed(1)} µg/m³',
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surfaceElevated, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Icon(Icons.air_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 8), const Expanded(child: Text('Kualitas Udara', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700))), Text(data!.category.label, style: TextStyle(color: data!.category.color, fontWeight: FontWeight.w700, fontSize: 12))]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 8, children: items.entries.map((e) => Text('${e.key} ${e.value}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11))).toList()),
        const SizedBox(height: 10),
        Text('${data!.source} · Model/Forecast · ${data!.updatedAt.toLocal().toString().substring(0, 16)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 9.5)),
      ]),
    );
  }
}
