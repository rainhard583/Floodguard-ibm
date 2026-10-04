import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/coming_soon.dart';
import '../../models/app_location_model.dart';
import '../../models/flood_risk_model.dart';
import '../../models/searched_place_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/flood_alert_provider.dart';
import '../../providers/flood_risk_provider.dart';
import '../../providers/location_provider.dart';
import '../../providers/weather_provider.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../services/notification_service.dart';
import '../../services/rain_alert_service.dart';
import '../../services/history_service.dart';
import '../../models/history_entry.dart';
import '../../models/weather_model.dart';
import '../../widgets/home/alert_card.dart';
import '../../widgets/home/flood_risk_card.dart';
import '../../widgets/home/home_header.dart';
import '../../widgets/home/information_card.dart';
import '../../widgets/home/location_card.dart';
import '../../widgets/home/quick_action_grid.dart';
import '../../widgets/common/section_header.dart';
import '../../widgets/home/weather_summary_card.dart';
import '../../widgets/map/location_search_bar.dart';

/// Home / Dashboard utama FloodGuard — pusat komando aplikasi.
///
/// Phase 3: dibangun sebagai fondasi yang siap disambungkan ke sistem
/// nyata di fase-fase berikutnya (GPS Phase 4, Weather API Phase 5,
/// mesin Risiko Banjir Phase 6, dst) TANPA perlu menulis ulang layar ini.
/// Setiap section (Lokasi, Risiko Banjir, Cuaca, Peringatan) punya sumber
/// data sendiri lewat Riverpod provider -> repository, dan untuk sekarang
/// semuanya dilayani implementasi Mock — lihat komentar di masing-masing
/// provider untuk titik penggantian ke implementasi asli.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _onRefresh(WidgetRef ref) async {
    ref.invalidate(locationProvider);
    ref.invalidate(floodRiskProvider);
    ref.invalidate(weatherProvider);
    ref.invalidate(floodAlertProvider);
    // Tunggu semua selesai supaya RefreshIndicator tidak berhenti terlalu
    // cepat sebelum data baru benar-benar datang.
    await Future.wait([
      ref.read(locationProvider.future),
      ref.read(floodRiskProvider.future),
      ref.read(weatherProvider.future),
      ref.read(floodAlertProvider.future),
    ]);
  }

  /// Bottom sheet pencarian lokasi untuk kartu Lokasi di Home — supaya
  /// user bisa GANTI ke wilayah mana saja (bukan cuma lokasi mock/GPS
  /// bawaan), pakai ulang [LocationSearchBar] & Nominatim yang sudah ada
  /// di Peta, lalu simpan pilihannya lewat [manualLocationOverrideProvider].
  Future<void> _showChangeLocationSheet(BuildContext context, WidgetRef ref) {
    return showModalBottomSheet(
      context: context,
      // PENTING: `MainShell` (bottom nav bar mengambang) membungkus tiap
      // tab lewat Navigator BERSARANG milik go_router (StatefulShellRoute).
      // Tanpa `useRootNavigator: true`, sheet ini kebuka di Navigator
      // bersarang itu — yang areanya cuma sebatas isi tab Beranda, JADI
      // ketutupan/ketumpuk sama bottom nav bar mengambang di atasnya.
      // Dengan root navigator, sheet ini benar-benar full-screen di atas
      // segalanya, termasuk bottom nav bar.
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
                'Ganti Lokasi',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              const Text(
                'Cari wilayah mana saja untuk dicek di Beranda.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
              ),
              const SizedBox(height: 14),
              LocationSearchBar(
                onPlaceSelected: (SearchedPlace place) {
                  ref.read(manualLocationOverrideProvider.notifier).state = AppLocation(
                    status: LocationStatus.available,
                    label: place.displayName,
                    latitude: place.latitude,
                    longitude: place.longitude,
                    updatedAt: DateTime.now(),
                  );
                  Navigator.of(sheetContext).pop();
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
    final authState = ref.watch(authStateChangesProvider);
    final location = ref.watch(locationProvider);
    final risk = ref.watch(floodRiskProvider);
    final weather = ref.watch(weatherProvider);
    final alerts = ref.watch(floodAlertProvider);

    // Sinkronkan peringatan banjir + hujan ke notifikasi Android.
    // Semua evaluasi memakai data WeatherAPI yang sudah diterima Home;
    // tidak ada request cuaca tambahan di sini. De-dup dilakukan oleh
    // NotificationService/RainAlertService agar rebuild tidak menjadi spam.
    if (alerts.hasValue || (weather.hasValue && location.hasValue)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final activeAlerts = alerts.valueOrNull ?? const [];
        final currentLocation = location.valueOrNull;
        final currentWeather = weather.valueOrNull;

        notificationUnreadCount.value = activeAlerts.length +
            ((currentWeather != null && RainAlertService.instance.hasPendingWarning(currentWeather)) ? 1 : 0);

        if (currentLocation != null && currentWeather != null) {
          final locationLabel = (currentLocation.label ?? '').trim();
          if (locationLabel.isNotEmpty) {
            HistoryService.instance.add(
              HistoryEntry(
                id: 'weather-${locationLabel.toLowerCase()}-${currentWeather.updatedAt.toIso8601String()}',
                type: HistoryEntryType.weather,
                title: 'Pembaruan Cuaca',
                message: '${currentWeather.temperatureCelsius.toStringAsFixed(1)}°C, ${currentWeather.condition.label}. Kelembapan ${currentWeather.humidityPercent.round()}%.',
                source: 'WeatherAPI',
                location: locationLabel,
                timestamp: currentWeather.updatedAt,
              ),
            );
            RainAlertService.instance.evaluate(
              weather: currentWeather,
              location: currentLocation,
            );
          }
        }

        for (final alert in activeAlerts.where((a) => a.isActive)) {
          HistoryService.instance.add(
            HistoryEntry(
              id: 'flood-${alert.id}',
              type: HistoryEntryType.flood,
              title: alert.title,
              message: '${alert.message} Lokasi: ${alert.location}.',
              source: 'FloodGuard',
              location: alert.location,
              timestamp: alert.timestamp,
              isWarning: alert.severity != FloodRiskLevel.aman,
            ),
          );
          NotificationService.instance.showAlert(
            key: 'flood-${alert.id}',
            title: alert.title,
            body: '${alert.message} Lokasi: ${alert.location}.',
            important: alert.severity != FloodRiskLevel.aman,
          );
        }
      });
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFEAF6FF), Color(0xFFF7FBFF), Color(0xFFF3F8FD)],
            stops: [0.0, 0.38, 1.0],
          ),
        ),
        child: Stack(
          children: [
            Positioned(top: -90, right: -80, child: _GlowOrb(size: 240, color: Color(0xFF6BC5FF))),
            Positioned(top: 190, left: -120, child: _GlowOrb(size: 220, color: Color(0xFFB6E8FF))),
            SafeArea(
              child: RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: Colors.white,
                onRefresh: () => _onRefresh(ref),
                child: ListView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
                  children: [
              HomeHeader(user: authState.valueOrNull),
              const SizedBox(height: 20),

              LocationCard(
                location: location,
                onRetry: () => ref.invalidate(locationProvider),
                onChangeLocation: () => _showChangeLocationSheet(context, ref),
              ),
              const SizedBox(height: 16),

              const SectionHeader(title: 'Risiko Banjir'),
              FloodRiskCard(
                risk: risk,
                onRetry: () => ref.invalidate(floodRiskProvider),
              ),
              const SizedBox(height: 24),

              WeatherSummaryCard(
                weather: weather,
                onRetry: () => ref.invalidate(weatherProvider),
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Aksi Cepat'),
              QuickActionGrid(
                actions: [
                  QuickAction(
                    icon: Icons.camera_alt_rounded,
                    label: 'Deteksi Banjir',
                    onTap: () => context.go('/detection'),
                  ),
                  QuickAction(
                    icon: Icons.map_rounded,
                    label: 'Peta Banjir',
                    onTap: () => context.go('/map'),
                  ),
                  QuickAction(
                    icon: Icons.report_rounded,
                    label: 'Lapor Banjir',
                    onTap: () => showComingSoonSheet(
                      context,
                      icon: Icons.report_rounded,
                      title: 'Lapor Banjir',
                      message: 'Form laporan banjir manual akan tersedia pada Phase 10.',
                    ),
                  ),
                  QuickAction(
                    icon: Icons.emergency_rounded,
                    label: 'Emergency',
                    onTap: () => showComingSoonSheet(
                      context,
                      icon: Icons.emergency_rounded,
                      title: 'Emergency',
                      message: 'Informasi kontak darurat & evakuasi akan tersedia pada Phase 13.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SectionHeader(
                title: 'Peringatan Aktif',
                action: TextButton(
                  onPressed: () => context.go('/history'),
                  child: const Text(
                    'Riwayat',
                    style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              AlertList(
                alerts: alerts,
                onRetry: () => ref.invalidate(floodAlertProvider),
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'Informasi'),
              const InformationCard(
                icon: Icons.health_and_safety_rounded,
                title: 'Keselamatan Saat Banjir',
                description:
                    'Matikan listrik, hindari genangan air, dan pindah ke tempat lebih tinggi bila diperlukan.',
              ),
              const SizedBox(height: 10),
              const InformationCard(
                icon: Icons.newspaper_rounded,
                title: 'Berita Bencana',
                description: 'Integrasi berita bencana terkini akan tersedia pada fase berikutnya.',
              ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: .28), color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
