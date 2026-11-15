import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../../../collections/presentation/providers/collection_providers.dart';
import '../../data/repositories/import_export_repository_impl.dart';
import '../../data/services/duplicate_detection_service.dart';
import '../../domain/repositories/import_export_repository.dart';
import '../../../../core/providers/media_provider.dart';

final duplicateDetectionServiceProvider = Provider<DuplicateDetectionService>(
  (ref) {
    final contactRepo = ref.watch(contactRepositoryProvider);
    return DuplicateDetectionService(contactRepo);
  },
);

final importExportRepositoryProvider = Provider<ImportExportRepository>((ref) {
  final contactRepo = ref.watch(contactRepositoryProvider);
  final dupDetection = ref.watch(duplicateDetectionServiceProvider);
  final tagRepo = ref.watch(tagRepositoryProvider);
  final collRepo = ref.watch(collectionRepositoryProvider);
  final media = ref.watch(mediaServiceProvider);
  return ImportExportRepositoryImpl(
    contactRepository: contactRepo,
    duplicateDetection: dupDetection,
    media: media,
    tagRepository: tagRepo,
    collectionRepository: collRepo,
  );
});
