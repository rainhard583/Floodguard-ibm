import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
import '../../models/searched_place_model.dart';
import '../../providers/earthquake_risk_provider.dart';
import '../../providers/air_quality_provider.dart';
import '../../providers/location_search_provider.dart';
import '../../providers/tsunami_risk_provider.dart';
import '../../providers/weather_provider.dart';
import '../common/section_header.dart';
import '../home/weather_summary_card.dart';
import 'earthquake_risk_card.dart';
import 'air_quality_location_card.dart';
import 'location_search_bar.dart';
import 'tsunami_risk_card.dart';

/// Panel yang tampil saat user memilih satu titik di Peta (lewat search
/// atau tap langsung): nama lokasi, risiko gempa, risiko tsunami, lalu
/// cuaca di bawahnya — sesuai urutan yang diminta.
class SelectedLocationPanel extends ConsumerWidget {
  final LatLng point;
  final ScrollController? scrollController;

  /// Dipanggil saat user memilih lokasi BARU lewat tombol cari di panel
  /// ini (bukan lewat search bar di atas peta). Ditambahkan supaya
  /// mencari wilayah lain TIDAK bergantung sepenuhnya pada search bar di
  /// atas — kalau user menarik panel ini sampai menutupi search bar (atau
  /// search bar itu sedang tidak kelihatan di layar), tetap ada jalan
  /// lain untuk cari lokasi lain langsung dari sini.
  final ValueChanged<SearchedPlace>? onSearchAnother;

  const SelectedLocationPanel({
    super.key,
    required this.point,
    this.scrollController,
    this.onSearchAnother,
  });

  void _openSearchSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      // Root navigator supaya sheet ini benar-benar full-screen di atas
      // segalanya (termasuk panel lokasi & bottom nav), sama seperti
      // sheet "Ganti Lokasi" di Beranda.
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const Text(
                'Cari Wilayah Lain',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cari kota, kecamatan, atau alamat mana saja.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              LocationSearchBar(
                onPlaceSelected: (place) {
                  Navigator.of(sheetContext).pop();
                  onSearchAnother?.call(place);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = ref.watch(selectedMapLocationLabelProvider);
    final earthquake = ref.watch(earthquakeRiskProvider(point));
    final tsunami = ref.watch(tsunamiRiskProvider(point));
    final weather = ref.watch(weatherForLocationProvider(point));
    final air = ref.watch(airQualityForLocationProvider(point));

    return ListView(
      controller: scrollController,
      // Bottom padding 110 (bukan 32) supaya kartu Cuaca di paling bawah
      // TIDAK ketutupan taskbar mengambang (bottom nav pill di MainShell)
      // — nilai ini sama seperti yang sudah dipakai di HomeScreen untuk
      // masalah yang sama persis.
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        Row(
          children: [
            const Icon(Icons.place_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label ?? '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (onSearchAnother != null)
              Material(
                color: AppColors.surfaceElevated,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => _openSearchSheet(context, ref),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),

        EarthquakeRiskCard(
          risk: earthquake,
          onRetry: () => ref.invalidate(earthquakeRiskProvider(point)),
        ),
        const SizedBox(height: 12),

        TsunamiRiskCard(
          risk: tsunami,
          onRetry: () => ref.invalidate(tsunamiRiskProvider(point)),
        ),
        const SizedBox(height: 20),

        const SectionHeader(title: 'Cuaca'),
        WeatherSummaryCard(
          weather: weather,
          onRetry: () => ref.invalidate(weatherForLocationProvider(point)),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: 'Kualitas Udara'),
        AirQualityLocationCard(
          data: air.valueOrNull,
          loading: air.isLoading,
          error: air.hasError ? air.error : null,
          onRetry: () => ref.invalidate(airQualityForLocationProvider(point)),
        ),
      ],
    );
  }
}
