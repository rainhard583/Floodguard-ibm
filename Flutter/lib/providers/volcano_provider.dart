import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/volcano_model.dart';
import '../repositories/static_volcano_repository.dart';
import '../repositories/volcano_repository.dart';

final volcanoRepositoryProvider = Provider<VolcanoRepository>((ref) {
  return StaticVolcanoRepository();
});

final volcanoListProvider = FutureProvider.autoDispose<List<VolcanoModel>>((ref) {
  return ref.watch(volcanoRepositoryProvider).getActiveVolcanoes();
});
