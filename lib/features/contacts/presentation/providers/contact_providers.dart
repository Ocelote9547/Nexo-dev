import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';
import '../../../../core/providers/media_provider.dart';
import '../../data/repositories/contact_repository_impl.dart';
import '../../data/services/contact_search_service.dart';
import '../../domain/entities/contact.dart';
import '../../domain/repositories/contact_repository.dart';
import '../../domain/usecases/contact_usecases.dart';

final contactUseCasesProvider = Provider<ContactUseCases>((ref) {
  final repo = ref.watch(contactRepositoryProvider);
  return ContactUseCases(repo);
});

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final media = ref.watch(mediaServiceProvider);
  final search = ContactSearchService(db);
  return ContactRepositoryImpl(db, media, search);
});

final recentContactsProvider = FutureProvider<List<Contact>>((ref) async {
  final repo = ref.watch(contactRepositoryProvider);
  return repo.getRecentContacts();
});

final contactsListProvider = StreamProvider((ref) {
  final repo = ref.watch(contactRepositoryProvider);
  return repo.watchContacts();
});

final contactByIdProvider = StreamProvider.family((ref, String id) {
  final repo = ref.watch(contactRepositoryProvider);
  return repo.watchContactById(id);
});

final contactWithRelationsProvider = FutureProvider.family<ContactWithRelations?, String>((ref, id) {
  final repo = ref.read(contactRepositoryProvider);
  return repo.getContactWithRelations(id);
});
