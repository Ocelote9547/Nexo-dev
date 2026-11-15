import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';
import '../../data/repositories/tag_repository_impl.dart';
import '../../domain/repositories/tag_repository.dart';

final tagRepositoryProvider = Provider<TagRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return TagRepositoryImpl(db);
});

final tagsListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(tagRepositoryProvider);
  return repo.watchTags();
});
