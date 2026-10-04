/// Format waktu relatif sederhana ("baru saja", "5 menit lalu", dst)
/// tanpa dependency tambahan (`intl` dsb.) — cukup untuk kebutuhan label
/// "updated at" di kartu-kartu Home.
String formatRelativeTime(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inSeconds < 60) return 'Baru saja';
  if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
  if (diff.inHours < 24) return '${diff.inHours} jam lalu';
  return '${diff.inDays} hari lalu';
}
