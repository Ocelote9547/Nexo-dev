import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';
import '../../data/services/contact_search_service.dart';
import '../providers/contact_providers.dart';

final contactSearchServiceProvider = Provider<ContactSearchService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ContactSearchService(db);
});

/// Resultados de búsqueda de contactos basados en una consulta dada.
///
/// Devuelve vacía cuando la consulta está vacía (sin búsqueda activa).
final contactSearchResultsProvider =
    FutureProvider.family<List<String>, String>((ref, query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty) return <String>[];
  final search = ref.read(contactSearchServiceProvider);
  return search.searchIds(trimmed);
});

/// Número de contactos que se están mostrando en pantalla para una consulta dada.
///
/// Cuando la consulta está vacía, devuelve el total de contactos.
/// Cuando hay búsqueda activa, devuelve el número de resultados de búsqueda.
final contactDisplayCountProvider = Provider.family<int, String>((ref, query) {
  final trimmed = query.trim();
  final contactsAsync = ref.watch(contactsListProvider);

  if (trimmed.isEmpty) {
    return contactsAsync.when(
      data: (list) => list.length,
      loading: () => 0,
      error: (Object error, StackTrace stackTrace) => 0,
    );
  }

  final resultsAsync = ref.watch(contactSearchResultsProvider(trimmed));
  return resultsAsync.when(
    data: (ids) => ids.length,
    loading: () => 0,
    error: (Object error, StackTrace stackTrace) => 0,
  );
});
