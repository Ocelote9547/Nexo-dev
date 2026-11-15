import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';
import '../../data/repositories/collection_repository_impl.dart';

final collectionRepositoryProvider = Provider<CollectionRepositoryImpl>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CollectionRepositoryImpl(db);
});

final collectionsListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(collectionRepositoryProvider);
  return repo.watchCollections();
});
