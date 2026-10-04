import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/flood_alert_model.dart';
import '../../models/flood_risk_model.dart';
import '../../models/weather_model.dart';
import '../../providers/flood_alert_provider.dart';
import '../../providers/weather_provider.dart';
import '../../providers/location_provider.dart';
import '../../models/history_entry.dart';
import '../../services/history_service.dart';

/// Badge notifikasi yang dipakai HomeHeader.
final ValueNotifier<int> notificationUnreadCount = ValueNotifier<int>(0);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  int _filter = 0;
  final Set<String> _readKeys = <String>{};

  @override
  void initState() {
    super.initState();
    HistoryService.instance.entries.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    HistoryService.instance.entries.removeListener(_onHistoryChanged);
    super.dispose();
  }

  void _onHistoryChanged() {
    if (mounted) setState(() {});
  }

  List<_Notice> _buildNotices({
    required List<FloodAlert> alerts,
    required Weather? weather,
    required String? locationLabel,
  }) {
    final result = <_Notice>[];

    for (final alert in alerts) {
      result.add(_Notice.fromFloodAlert(alert, unread: !_readKeys.contains(alert.id)));
    }

    final rain = _nextHourRainNotice(weather);
    if (rain != null) result.add(rain);

    final normalizedLocation = (locationLabel ?? '').trim().toLowerCase();
    final recentHistory = HistoryService.instance.entries.value.where((entry) {
      if (entry.type != HistoryEntryType.earthquake) return false;
      if (normalizedLocation.isNotEmpty &&
          entry.location.trim().toLowerCase() != normalizedLocation) {
        return false;
      }
      return DateTime.now().difference(entry.timestamp).inHours <= 24;
    });
    for (final entry in recentHistory) {
      result.add(_Notice.fromHistory(entry, unread: !_readKeys.contains(entry.id)));
    }

    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  List<_Notice> _filtered(List<_Notice> notices) {
    switch (_filter) {
      case 1:
        return notices.where((e) => e.unread).toList();
      case 2:
        return notices.where((e) => e.type == _NoticeType.earthquake).toList();
      case 3:
        return notices.where((e) => e.type == _NoticeType.weather || e.type == _NoticeType.rain).toList();
      case 4:
        return notices.where((e) => e.type == _NoticeType.flood).toList();
      default:
        return notices;
    }
  }

  _Notice? _nextHourRainNotice(Weather? weather) {
    final forecast = weather?.forecast ?? const <WeatherForecastItem>[];
    final now = DateTime.now();
    WeatherForecastItem? item;
    for (final candidate in forecast) {
      final t = candidate.forecastTime;
      if (t == null || t.isBefore(now)) continue;
      final minutes = t.difference(now).inMinutes;
      if (minutes <= 60) {
        item = candidate;
        break;
      }
    }
    if (item == null) return null;

    final chance = item.chanceOfRainPercent;
    final rainMm = item.precipitationMm;
    final rainCondition = item.condition == WeatherCondition.hujanLebat ||
        item.condition == WeatherCondition.badai;
    if (!(rainCondition || (chance != null && chance >= 60) || rainMm >= 1)) return null;

    final t = item.forecastTime!;
    final chanceText = chance == null ? '' : 'Peluang hujan ${chance.round()}%. ';
    final rainText = rainMm == rainMm.roundToDouble()
        ? '${rainMm.toStringAsFixed(0)} mm'
        : '${rainMm.toStringAsFixed(1)} mm';

    return _Notice(
      id: 'rain-${t.toIso8601String()}',
      type: _NoticeType.rain,
      title: rainCondition || rainMm >= 5 || (chance != null && chance >= 80) ? 'Peringatan Hujan Lebat' : 'Peringatan Hujan',
      message: '${chanceText}Estimasi presipitasi $rainText. Periksa kondisi sekitar jika akan bepergian.',
      source: weather?.source.isNotEmpty == true ? weather!.source : 'WeatherAPI',
      tag: 'CUACA',
      timestamp: t,
      unread: !_readKeys.contains('rain-${t.toIso8601String()}'),
    );
  }

  void _markRead(_Notice notice) {
    if (!notice.unread) return;
    setState(() => _readKeys.add(notice.id));
  }

  void _markAllRead(List<_Notice> notices) {
    setState(() {
      _readKeys.addAll(notices.map((e) => e.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final alertsAsync = ref.watch(floodAlertProvider);
    final weather = ref.watch(weatherProvider).valueOrNull;
    final location = ref.watch(locationProvider).valueOrNull;

    return alertsAsync.when(
      loading: () => _ScaffoldShell(child: _loading()),
      error: (error, stack) => _ScaffoldShell(child: _error()),
      data: (alerts) {
        final notices = _buildNotices(
          alerts: alerts,
          weather: weather,
          locationLabel: location?.label,
        );
        final unread = notices.where((e) => e.unread).length;
        notificationUnreadCount.value = unread;
        final filtered = _filtered(notices);

        return _ScaffoldShell(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _header(unread, notices, location?.label)),
              SliverToBoxAdapter(child: _summary(unread, notices)),
              SliverToBoxAdapter(child: _filters()),
              if (filtered.isEmpty)
                SliverFillRemaining(hasScrollBody: false, child: _empty())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 34),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _NoticeCard(
                      notice: filtered[i],
                      index: i,
                      onTap: () => _markRead(filtered[i]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(int unread, List<_Notice> notices, String? locationLabel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      child: Row(children: [
        _RoundButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Peringatan', style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -.6)),
          const SizedBox(height: 3),
          Text(unread == 0 ? 'Tidak ada peringatan baru' : '$unread peringatan perlu diperhatikan', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
          if (locationLabel != null && locationLabel.trim().isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(locationLabel.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ])),
        if (unread > 0)
          _RoundButton(icon: Icons.done_all_rounded, onTap: () => _markAllRead(notices)),
      ]),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -.06, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _summary(int unread, List<_Notice> notices) {
    final flood = notices.where((e) => e.type == _NoticeType.flood).length;
    final weather = notices.where((e) => e.type == _NoticeType.weather || e.type == _NoticeType.rain).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Expanded(child: _StatCard(icon: Icons.warning_amber_rounded, color: const Color(0xFFE85D5D), value: '$flood', label: 'Banjir aktif')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.cloud_rounded, color: const Color(0xFF1687F7), value: '$weather', label: 'Cuaca')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(icon: Icons.mark_email_unread_rounded, color: const Color(0xFFFF9D2E), value: '$unread', label: 'Belum dibaca')),
      ]),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: .04, end: 0);
  }

  Widget _filters() {
    const labels = ['Semua', 'Belum dibaca', 'Gempa', 'Cuaca', 'Banjir'];
    return SizedBox(
      height: 58,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final selected = _filter == index;
          return GestureDetector(
            onTap: () => setState(() => _filter = index),
            child: AnimatedContainer(
              duration: 220.ms,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: selected ? AppColors.primary : Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? AppColors.primary : const Color(0xFFE2EBF4))),
              child: Text(labels[index], style: TextStyle(color: selected ? Colors.white : AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
          );
        },
      ),
    );
  }

  Widget _loading() => const Center(child: CircularProgressIndicator());
  Widget _error() => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
    const Icon(Icons.notifications_off_rounded, size: 42, color: AppColors.textMuted),
    const SizedBox(height: 12),
    const Text('Peringatan belum dapat dimuat', style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
    const SizedBox(height: 6),
    const Text('Tarik layar untuk mencoba lagi.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
  ])));
  Widget _empty() => Center(child: Padding(padding: const EdgeInsets.all(30), child: Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 72, height: 72, decoration: const BoxDecoration(color: Color(0xFFEAF6FF), shape: BoxShape.circle), child: const Icon(Icons.notifications_none_rounded, color: AppColors.primary, size: 36)),
    const SizedBox(height: 16),
    const Text('Semua aman untuk saat ini', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
    const SizedBox(height: 6),
    const Text('Belum ada peringatan baru untuk lokasi yang sedang dipantau.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
  ])));
}

class _ScaffoldShell extends StatelessWidget {
  final Widget child;
  const _ScaffoldShell({required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: AppColors.background, body: Stack(children: [
    Positioned(top: -100, right: -90, child: _Glow(size: 250, color: const Color(0xFF62BFFF))),
    Positioned(top: 300, left: -130, child: _Glow(size: 220, color: const Color(0xFFB8E9FF))),
    SafeArea(child: child),
  ]));
}

class _StatCard extends StatelessWidget {
  final IconData icon; final Color color; final String value; final String label;
  const _StatCard({required this.icon, required this.color, required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: .9), borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE7EEF6))),
    child: Row(children: [
      Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withValues(alpha: .1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 17)),
      const SizedBox(width: 7),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textPrimary)), Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8.5, color: AppColors.textSecondary))])),
    ]),
  );
}

class _NoticeCard extends StatelessWidget {
  final _Notice notice; final int index; final VoidCallback onTap;
  const _NoticeCard({required this.notice, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final v = notice.visual;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .95), borderRadius: BorderRadius.circular(21), border: Border.all(color: notice.unread ? v.color.withValues(alpha: .24) : const Color(0xFFE7EEF6)), boxShadow: [BoxShadow(color: const Color(0xFF5C7898).withValues(alpha: .06), blurRadius: 16, offset: const Offset(0, 7))]),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: v.color.withValues(alpha: .11), shape: BoxShape.circle), child: Icon(v.icon, color: v.color, size: 22)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Expanded(child: Text(notice.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800, height: 1.25))), if (notice.unread) Container(width: 8, height: 8, decoration: BoxDecoration(color: v.color, shape: BoxShape.circle))]),
            const SizedBox(height: 5),
            Text(notice.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.4)),
            const SizedBox(height: 10),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: v.color.withValues(alpha: .09), borderRadius: BorderRadius.circular(8)), child: Text(notice.tag, style: TextStyle(color: v.color, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: .3))),
              const SizedBox(width: 8),
              Expanded(child: Text(notice.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w600))),
              const Icon(Icons.schedule_rounded, size: 13, color: AppColors.textMuted), const SizedBox(width: 4),
              Text(_formatTime(notice.timestamp), style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w600)),
            ]),
          ])),
        ]),
      ),
    ).animate().fadeIn(delay: (70 + index * 50).ms, duration: 350.ms).slideX(begin: .04, end: 0, curve: Curves.easeOutCubic);
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon; final VoidCallback onTap;
  const _RoundButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: Colors.white.withValues(alpha: .88), shape: const CircleBorder(), child: InkWell(onTap: onTap, customBorder: const CircleBorder(), child: Container(width: 46, height: 46, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.2), boxShadow: [BoxShadow(color: const Color(0xFF7DA6D4).withValues(alpha: .12), blurRadius: 14, offset: const Offset(0, 6))]), child: Icon(icon, color: AppColors.textPrimary, size: 20))));
}

class _Glow extends StatelessWidget {
  final double size; final Color color;
  const _Glow({required this.size, required this.color});
  @override
  Widget build(BuildContext context) => IgnorePointer(child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: .12))).animate(onPlay: (c) => c.repeat(reverse: true)).blur(begin: const Offset(24, 24), end: const Offset(40, 40), duration: 2600.ms));
}

enum _NoticeType { weather, rain, earthquake, temperature, safe, flood }

class _Notice {
  final String id;
  final _NoticeType type;
  final String title;
  final String message;
  final String source;
  final String tag;
  final DateTime timestamp;
  final bool unread;

  const _Notice({required this.id, required this.type, required this.title, required this.message, required this.source, required this.tag, required this.timestamp, required this.unread});

  factory _Notice.fromFloodAlert(FloodAlert alert, {required bool unread}) => _Notice(
    id: 'flood-${alert.id}', type: _NoticeType.flood, title: alert.title, message: '${alert.message} Lokasi: ${alert.location}.', source: 'Peringatan banjir', tag: alert.severity.label.toUpperCase(), timestamp: alert.timestamp, unread: unread,
  );

  factory _Notice.fromHistory(HistoryEntry entry, {required bool unread}) => _Notice(
    id: entry.id,
    type: entry.type == HistoryEntryType.earthquake ? _NoticeType.earthquake : _NoticeType.weather,
    title: entry.title,
    message: entry.message,
    source: entry.source,
    tag: entry.isWarning ? 'PERINGATAN' : 'INFO',
    timestamp: entry.timestamp,
    unread: unread,
  );

  _NoticeVisual get visual {
    switch (type) {
      case _NoticeType.weather: return const _NoticeVisual(Icons.cloud_rounded, Color(0xFF1687F7));
      case _NoticeType.rain: return const _NoticeVisual(Icons.umbrella_rounded, Color(0xFF4D9CF5));
      case _NoticeType.earthquake: return const _NoticeVisual(Icons.public_rounded, Color(0xFFFF8A22));
      case _NoticeType.temperature: return const _NoticeVisual(Icons.thermostat_rounded, Color(0xFFE95D55));
      case _NoticeType.safe: return const _NoticeVisual(Icons.verified_rounded, Color(0xFF18B86A));
      case _NoticeType.flood: return const _NoticeVisual(Icons.flood_rounded, Color(0xFFE85D5D));
    }
  }
}

class _NoticeVisual { final IconData icon; final Color color; const _NoticeVisual(this.icon, this.color); }

String _formatTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} mnt lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
