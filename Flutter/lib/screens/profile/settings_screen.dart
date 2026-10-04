import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/location_provider.dart';
import '../../services/floodguard_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final settings = FloodGuardSettings.instance;

  @override
  void initState() {
    super.initState();
    settings.addListener(_refresh);
  }

  @override
  void dispose() {
    settings.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _saved(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1100),
      ));
  }

  void _showChoiceDialog({
    required String title,
    required String value,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              ...options.map((option) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(option),
                    trailing: option == value
                        ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                        : const Icon(Icons.circle_outlined, color: AppColors.textMuted),
                    onTap: () {
                      Navigator.pop(context);
                      onSelected(option);
                    },
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationProvider).valueOrNull;
    final locationLabel = location?.label ?? 'Lokasi perangkat';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.pop(context)),
        title: const Text('Pengaturan', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        children: [
          const _SectionTitle('Notifikasi'),
          _SettingsCard(children: [
            _SwitchRow(icon: Icons.notifications_active_outlined, title: 'Notifikasi bencana', subtitle: 'Aktif/nonaktifkan seluruh peringatan FloodGuard', value: settings.notificationsEnabled, onChanged: (v) { settings.setNotificationsEnabled(v); _saved(v ? 'Semua notifikasi diaktifkan' : 'Semua notifikasi dinonaktifkan'); }),
            const _Divider(),
            _SwitchRow(icon: Icons.vibration_outlined, title: 'Gempa bumi', subtitle: 'Peringatan gempa dari BMKG', value: settings.earthquakeNotification, onChanged: (v) { settings.setEarthquakeNotification(v); _saved(v ? 'Notifikasi gempa aktif' : 'Notifikasi gempa dimatikan'); }),
            const _Divider(),
            _SwitchRow(icon: Icons.water_drop_outlined, title: 'Banjir', subtitle: 'Peringatan risiko dan kondisi banjir', value: settings.floodNotification, onChanged: (v) { settings.setFloodNotification(v); _saved(v ? 'Notifikasi banjir aktif' : 'Notifikasi banjir dimatikan'); }),
            const _Divider(),
            _SwitchRow(icon: Icons.cloud_outlined, title: 'Cuaca ekstrem', subtitle: 'Hujan lebat dan kondisi berbahaya', value: settings.weatherNotification, onChanged: (v) { settings.setWeatherNotification(v); _saved(v ? 'Notifikasi cuaca aktif' : 'Notifikasi cuaca dimatikan'); }),
            const _Divider(),
            _SwitchRow(icon: Icons.terrain_outlined, title: 'Longsor', subtitle: 'Peringatan kondisi longsor', value: settings.landslideNotification, onChanged: (v) { settings.setLandslideNotification(v); _saved(v ? 'Notifikasi longsor aktif' : 'Notifikasi longsor dimatikan'); }),
            const _Divider(),
            _SwitchRow(icon: Icons.landscape_outlined, title: 'Gunung api', subtitle: 'Peringatan aktivitas gunung api', value: settings.volcanoNotification, onChanged: (v) { settings.setVolcanoNotification(v); _saved(v ? 'Notifikasi gunung api aktif' : 'Notifikasi gunung api dimatikan'); }),
          ]),

          const _SectionTitle('Lokasi & Pemantauan'),
          _SettingsCard(children: [
            _InfoRow(icon: Icons.location_on_outlined, title: 'Lokasi aktif', subtitle: locationLabel, onTap: () => _saved('Lokasi aktif mengikuti lokasi FloodGuard saat ini')),
            const _Divider(),
            _SwitchRow(icon: Icons.my_location_outlined, title: 'Gunakan lokasi otomatis', subtitle: 'Perbarui lokasi dari perangkat', value: settings.autoLocation, onChanged: (v) { settings.setAutoLocation(v); _saved(v ? 'Lokasi otomatis aktif' : 'Lokasi otomatis dimatikan'); }),
            const _Divider(),
            _ValueRow(icon: Icons.radar_outlined, title: 'Radius pemantauan', value: '${settings.monitoringRadiusKm.round()} km', onTap: () => _showChoiceDialog(title: 'Radius pemantauan', value: '${settings.monitoringRadiusKm.round()} km', options: const ['50 km', '100 km', '150 km', '250 km', '300 km'], onSelected: (v) { settings.setRadius(double.parse(v.split(' ').first)); _saved('Radius pemantauan: $v'); })),
          ]),

          const _SectionTitle('Peringatan Gempa'),
          _SettingsCard(children: [
            _ValueRow(icon: Icons.speed_outlined, title: 'Magnitudo minimum', value: 'M${settings.earthquakeMagnitude.toStringAsFixed(1)}', onTap: () => _showChoiceDialog(title: 'Magnitudo minimum', value: 'M${settings.earthquakeMagnitude.toStringAsFixed(1)}', options: const ['M3.5', 'M4.0', 'M4.5', 'M5.0', 'M5.5'], onSelected: (v) { settings.setMagnitude(double.parse(v.substring(1))); _saved('Minimum gempa: $v'); })),
            const _Divider(),
            const Padding(padding: EdgeInsets.fromLTRB(14, 4, 14, 14), child: Text('Aturan notifikasi gempa sekarang memakai pengaturan di atas: ON/OFF, magnitudo minimum, radius, dan umur kejadian maksimum 10 menit.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45))),
          ]),

          const _SectionTitle('Sumber Cuaca'),
          _SettingsCard(children: [
            const _ValueRowStatic(icon: Icons.cloud_queue_rounded, title: 'Sumber data saat ini', value: 'WeatherAPI'),
            const _Divider(),
            _ValueRow(icon: Icons.sync_outlined, title: 'Pembaruan cuaca', value: settings.weatherUpdate, onTap: () => _showChoiceDialog(title: 'Pembaruan cuaca', value: settings.weatherUpdate, options: const ['5 menit', '10 menit', '15 menit', '30 menit'], onSelected: (v) { settings.setWeatherUpdate(v); _saved('Interval cuaca: $v'); })),
            const _Divider(),
            _ValueRow(icon: Icons.thermostat_outlined, title: 'Satuan suhu', value: settings.temperatureUnit, onTap: () => _showChoiceDialog(title: 'Satuan suhu', value: settings.temperatureUnit, options: const ['°C', '°F'], onSelected: (v) { settings.setTemperatureUnit(v); _saved('Satuan suhu: $v'); })),
          ]),

          const _SectionTitle('Peta'),
          _SettingsCard(children: [
            _SwitchRow(icon: Icons.water_drop_outlined, title: 'Radar hujan', subtitle: 'Tampilkan layer hujan pada peta', value: settings.rainLayer, onChanged: (v) { settings.setRainLayer(v); _saved(v ? 'Layer radar hujan aktif' : 'Layer radar hujan dimatikan'); }),
            const _Divider(),
            _SwitchRow(icon: Icons.public_outlined, title: 'Gempa', subtitle: 'Tampilkan kejadian gempa BMKG', value: settings.earthquakeLayer, onChanged: (v) { settings.setEarthquakeLayer(v); _saved(v ? 'Layer gempa aktif' : 'Layer gempa dimatikan'); }),
            const _Divider(),
            _SwitchRow(icon: Icons.landscape_outlined, title: 'Gunung api', subtitle: 'Tampilkan informasi aktivitas gunung api', value: settings.volcanoLayer, onChanged: (v) { settings.setVolcanoLayer(v); _saved(v ? 'Layer gunung api aktif' : 'Layer gunung api dimatikan'); }),
          ]),

          const _SectionTitle('AI Analyst'),
          _SettingsCard(children: [_SwitchRow(icon: Icons.auto_awesome_outlined, title: 'Analisis AI', subtitle: 'Izinkan FloodGuard menganalisis kondisi bencana', value: settings.aiAnalysis, onChanged: (v) { settings.setAiAnalysis(v); _saved(v ? 'AI Analyst aktif' : 'AI Analyst dimatikan'); })]),

          const _SectionTitle('Tampilan'),
          _SettingsCard(children: [_ValueRow(icon: Icons.brightness_6_outlined, title: 'Mode tampilan', value: settings.themeMode, onTap: () => _showChoiceDialog(title: 'Mode tampilan', value: settings.themeMode, options: const ['Terang', 'Gelap', 'Mengikuti sistem'], onSelected: (v) { settings.setThemeMode(v); _saved('Mode tampilan: $v'); }))]),

          const _SectionTitle('Tentang'),
          _SettingsCard(children: [
            const _ValueRowStatic(icon: Icons.info_outline_rounded, title: 'Tentang FloodGuard', value: 'Aplikasi peringatan & pemantauan bencana'),
            const _Divider(),
            const _ValueRowStatic(icon: Icons.verified_outlined, title: 'Sumber data', value: 'BMKG dan layanan cuaca yang dikonfigurasi'),
            const _Divider(),
            const _ValueRowStatic(icon: Icons.apps_outlined, title: 'Versi aplikasi', value: 'FloodGuard'),
          ]),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget { final String title; const _SectionTitle(this.title); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.fromLTRB(4, 22, 4, 9), child: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w800))); }
class _SettingsCard extends StatelessWidget { final List<Widget> children; const _SettingsCard({required this.children}); @override Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .035), blurRadius: 16, offset: const Offset(0, 5))]), child: Column(children: children)); }
class _Divider extends StatelessWidget { const _Divider(); @override Widget build(BuildContext context) => const Divider(height: 1, indent: 60, endIndent: 14, color: AppColors.primarySoft); }
class _SwitchRow extends StatelessWidget { final IconData icon; final String title; final String subtitle; final bool value; final ValueChanged<bool> onChanged; const _SwitchRow({required this.icon, required this.title, required this.subtitle, required this.value, required this.onChanged}); @override Widget build(BuildContext context) => SwitchListTile(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3), secondary: Icon(icon, color: AppColors.primary), title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.25))); }
class _ValueRow extends StatelessWidget { final IconData icon; final String title; final String value; final VoidCallback onTap; const _ValueRow({required this.icon, required this.title, required this.value, required this.onTap}); @override Widget build(BuildContext context) => ListTile(onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), leading: Icon(icon, color: AppColors.primary), title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(width: 5), const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)])); }
class _ValueRowStatic extends StatelessWidget { final IconData icon; final String title; final String value; const _ValueRowStatic({required this.icon, required this.title, required this.value}); @override Widget build(BuildContext context) => ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), leading: Icon(icon, color: AppColors.primary), title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)), subtitle: Text(value, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5))); }
class _InfoRow extends StatelessWidget { final IconData icon; final String title; final String subtitle; final VoidCallback onTap; const _InfoRow({required this.icon, required this.title, required this.subtitle, required this.onTap}); @override Widget build(BuildContext context) => ListTile(onTap: onTap, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2), leading: Icon(icon, color: AppColors.primary), title: Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)), subtitle: Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5)), trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted)); }
