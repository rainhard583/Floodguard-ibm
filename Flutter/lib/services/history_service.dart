import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/history_entry.dart';

/// Session history for the active FloodGuard location.
class HistoryService {
  HistoryService._() {
    Timer.periodic(const Duration(seconds: 30), (_) {
      now.value = DateTime.now();
    });
  }
  static final HistoryService instance = HistoryService._();

  final ValueNotifier<List<HistoryEntry>> entries =
      ValueNotifier<List<HistoryEntry>>(const []);
  final ValueNotifier<DateTime> now = ValueNotifier<DateTime>(DateTime.now());
  final ValueNotifier<DateTime?> lastSync = ValueNotifier<DateTime?>(null);
  final ValueNotifier<String?> lastSyncSource = ValueNotifier<String?>(null);

  void add(HistoryEntry entry) {
    final current = entries.value;
    if (current.any((e) => e.id == entry.id)) return;
    final next = <HistoryEntry>[entry, ...current];
    if (next.length > 100) next.removeRange(100, next.length);
    entries.value = List.unmodifiable(next);
  }

  void markSync(String source) {
    lastSyncSource.value = source;
    lastSync.value = DateTime.now();
    now.value = DateTime.now();
  }

  void clear() => entries.value = const [];

  List<HistoryEntry> forLocation(String location) {
    final normalized = location.trim().toLowerCase();
    if (normalized.isEmpty) return entries.value;
    return entries.value
        .where((e) => e.location.trim().toLowerCase() == normalized)
        .toList(growable: false);
  }
}
