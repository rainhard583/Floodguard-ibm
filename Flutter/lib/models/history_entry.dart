import 'package:flutter/foundation.dart';

/// Jenis aktivitas/peristiwa yang disimpan di Riwayat FloodGuard.
enum HistoryEntryType { weather, rain, flood, earthquake, ai, report }

@immutable
class HistoryEntry {
  final String id;
  final HistoryEntryType type;
  final String title;
  final String message;
  final String source;
  final String location;
  final DateTime timestamp;
  final bool isWarning;

  const HistoryEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.source,
    required this.location,
    required this.timestamp,
    this.isWarning = false,
  });
}
