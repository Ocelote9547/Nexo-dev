import '../entities/import_export.dart';

abstract class DuplicateDetectionRepository {
  Future<List<DuplicateCandidate>> findDuplicates(PortableContact contact);
  Future<List<DuplicateCandidate>> findDuplicatesByPhone(String phone);
  Future<List<DuplicateCandidate>> findDuplicatesByEmail(String email);
  Future<List<DuplicateCandidate>> findDuplicatesByNameAndOrg({
    required String givenName,
    required String familyName,
    String? company,
  });
}

abstract class ImportExportRepository {
  Future<String> importPortableContact(
    PortableContact contact, {
    DuplicateResolution? resolution,
  });

  Future<PortableContact> exportContactToPortable(String contactId);
  Future<List<PortableContact>> exportAllContactsToPortable({
    ImportProgressCallback? onProgress,
  });
  Future<String> exportContactToVCard(String contactId);
  Future<String> exportAllContactsToVCard({
    ImportProgressCallback? onProgress,
  });
  Future<String> exportContactsToCsv({
    List<String>? contactIds,
    ImportProgressCallback? onProgress,
  });
  Future<ImportResult> importContactsFromCsv(
    String csvContent, {
    int batchSize = 50,
    ImportProgressCallback? onProgress,
  });
  Future<ImportResult> importContactsFromVCard(
    String vcfContent, {
    int batchSize = 50,
    ImportProgressCallback? onProgress,
    DuplicateResolution? resolution,
  });
  int countVcfCards(String vcfContent);
  Future<ImportResult> importContactsFromJson(
    String jsonContent, {
    int batchSize = 50,
    ImportProgressCallback? onProgress,
  });
}
