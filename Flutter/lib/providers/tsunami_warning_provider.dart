import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tsunami_warning_event.dart';
import '../repositories/bmkg_tsunami_warning_repository.dart';

final tsunamiWarningRepositoryProvider = Provider<TsunamiWarningRepository>((ref) {
  return BmkgTsunamiWarningRepository();
});

final tsunamiWarningEventsProvider = FutureProvider.autoDispose<List<TsunamiWarningEvent>>((ref) {
  return ref.watch(tsunamiWarningRepositoryProvider).getRecentPotentialEvents();
});
