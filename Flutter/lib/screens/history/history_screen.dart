import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/history_entry.dart';
import '../../services/history_service.dart';
import '../../providers/location_provider.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationProvider).valueOrNull;
    final activeLocation = (location?.label ?? '').trim();
    return AnimatedBuilder(
      animation: Listenable.merge([
        HistoryService.instance.entries,
        HistoryService.instance.now,
        HistoryService.instance.lastSync,
      ]),
      builder: (context, _) {
        final allEntries = HistoryService.instance.entries.value;
        final entries = activeLocation.isEmpty
            ? allEntries
            : allEntries.where((e) => e.location.trim().toLowerCase() == activeLocation.toLowerCase()).toList(growable: false);
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFEAF6FF), Color(0xFFF7FBFF), Color(0xFFF3F8FD)],
                stops: [0.0, 0.38, 1.0],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header(entries, activeLocation)),
                  if (entries.isEmpty)
                    const SliverFillRemaining(hasScrollBody: false, child: _EmptyHistory())
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                      sliver: SliverList.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, index) => _HistoryCard(
                          entry: entries[index],
                          index: index,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _header(List<HistoryEntry> entries, String activeLocation) {
    final location = activeLocation.isNotEmpty
        ? activeLocation
        : (entries.isEmpty ? 'Lokasi yang sedang dipantau' : entries.first.location);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Riwayat', style: TextStyle(color: AppColors.textPrimary, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -.8)),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.location_on_rounded, color: AppColors.primary, size: 15),
          const SizedBox(width: 5),
          Expanded(child: Text(location, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE3EDF7))),
          child: Row(children: [
            Container(width: 38, height: 38, decoration: const BoxDecoration(color: Color(0xFFEAF6FF), shape: BoxShape.circle), child: const Icon(Icons.timeline_rounded, color: AppColors.primary, size: 21)),
            const SizedBox(width: 10),
            Expanded(child: ValueListenableBuilder<DateTime?>(
              valueListenable: HistoryService.instance.lastSync,
              builder: (context, sync, _) {
                final clock = HistoryService.instance.now.value;
                final syncText = sync == null
                    ? 'Menunggu pembaruan data real-time.'
                    : 'Update terakhir ${_clock(sync)} • waktu perangkat ${_clock(clock)}';
                return Text(
                  '${entries.length} pembaruan tersimpan selama sesi ini. $syncText',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600),
                );
              },
            )),
          ]),
        ),
      ]),
    ).animate().fadeIn(duration: 350.ms).slideY(begin: -.04, end: 0);
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryEntry entry;
  final int index;
  const _HistoryCard({required this.entry, required this.index});

  @override
  Widget build(BuildContext context) {
    final visual = _visual(entry.type, entry.isWarning);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 30,
        child: Column(children: [
          Container(width: 14, height: 14, decoration: BoxDecoration(color: visual.color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 3), boxShadow: [BoxShadow(color: visual.color.withValues(alpha: .22), blurRadius: 8)])),
          if (index < 99) Container(width: 2, height: 128, color: const Color(0xFFD8E7F4)),
        ]),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .96), borderRadius: BorderRadius.circular(21), border: Border.all(color: entry.isWarning ? visual.color.withValues(alpha: .22) : const Color(0xFFE4EDF6)), boxShadow: [BoxShadow(color: const Color(0xFF5C7898).withValues(alpha: .055), blurRadius: 16, offset: const Offset(0, 7))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: visual.color.withValues(alpha: .10), shape: BoxShape.circle), child: Icon(visual.icon, color: visual.color, size: 19)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(entry.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(_dateTime(entry.timestamp), style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700)),
              ])),
              if (entry.isWarning) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: const Color(0xFFFFEEE8), borderRadius: BorderRadius.circular(8)), child: const Text('PERINGATAN', style: TextStyle(color: Color(0xFFE76A3B), fontSize: 7.5, fontWeight: FontWeight.w900))),
            ]),
            const SizedBox(height: 11),
            Text(entry.message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11.5, height: 1.45)),
            const SizedBox(height: 11),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Expanded(child: Text(entry.location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5, fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: visual.color.withValues(alpha: .08), borderRadius: BorderRadius.circular(8)), child: Text(entry.source, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: visual.color, fontSize: 8, fontWeight: FontWeight.w800))),
            ]),
          ]),
        ).animate().fadeIn(delay: (60 + index * 35).ms, duration: 300.ms).slideX(begin: .03, end: 0),
      ),
    ]);
  }

  _HistoryVisual _visual(HistoryEntryType type, bool warning) {
    switch (type) {
      case HistoryEntryType.weather:
        return const _HistoryVisual(Icons.cloud_rounded, Color(0xFF1687F7));
      case HistoryEntryType.rain:
        return _HistoryVisual(Icons.umbrella_rounded, warning ? const Color(0xFFE85D5D) : const Color(0xFF4D9CF5));
      case HistoryEntryType.flood:
        return const _HistoryVisual(Icons.flood_rounded, Color(0xFFE85D5D));
      case HistoryEntryType.earthquake:
        return const _HistoryVisual(Icons.public_rounded, Color(0xFFFF8A22));
      case HistoryEntryType.ai:
        return const _HistoryVisual(Icons.auto_awesome_rounded, Color(0xFF8B5CF6));
      case HistoryEntryType.report:
        return const _HistoryVisual(Icons.report_rounded, Color(0xFF1687F7));
    }
  }

  String _dateTime(DateTime value) {
    final t = value.toLocal();
    final now = DateTime.now();
    final sameDay = t.year == now.year && t.month == now.month && t.day == now.day;
    final clock = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'Hari ini • $clock';
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year} • $clock';
  }
}

String _clock(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

class _HistoryVisual {
  final IconData icon;
  final Color color;
  const _HistoryVisual(this.icon, this.color);
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(40, 30, 40, 100),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 78, height: 78, decoration: const BoxDecoration(color: Color(0xFFEAF6FF), shape: BoxShape.circle), child: const Icon(Icons.history_rounded, color: AppColors.primary, size: 38)),
        const SizedBox(height: 17),
        const Text('Belum ada riwayat', style: TextStyle(color: AppColors.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 7),
        const Text('Pembaruan cuaca, peringatan hujan, dan peringatan banjir untuk lokasi yang sedang dipantau akan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary, fontSize: 12, height: 1.45)),
      ]),
    ),
  );
}
