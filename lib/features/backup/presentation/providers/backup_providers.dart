import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../contacts/presentation/providers/contact_providers.dart';
import '../../../../core/providers/media_provider.dart';
import '../../../../services/backup/backup_service.dart';

final backupServiceProvider = Provider<BackupService>((ref) {
  final contactRepo = ref.watch(contactRepositoryProvider);
  final media = ref.watch(mediaServiceProvider);
  return BackupService(contactRepository: contactRepo, media: media);
});
