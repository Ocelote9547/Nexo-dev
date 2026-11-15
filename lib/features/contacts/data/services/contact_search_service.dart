import 'dart:async';

import '../../../../database/app_database.dart';

/// Servicio de búsqueda de contactos.
///
/// Utiliza búsqueda por subcadena sobre contenido normalizado (sin tildes,
/// minúsculas) para que buscar "jos" encuentre "José" y buscar "612" encuentre
/// "+34 612 345 678". No depende de FTS5 para el matching principal, ya que
/// FTS5 tokeniza las palabras y no encuentra coincidencias parciales dentro de
/// palabras.
///
/// Todas las operaciones de escritura que modifican contenido indexado pueden
/// ejecutarse dentro de una transacción SQLite mediante
/// [upsertWithinTransaction] y [deleteWithinTransaction], de modo que la base
/// de datos y el índice FTS5 se confirman (o se revierten) juntos.
class ContactSearchService {
  final AppDatabase? _db;
  final bool _forceFallback;

  ContactSearchService(this._db, {this._forceFallback = false});

  /// Comprueba de forma real si FTS5 está disponible creando y consultando una
  /// tabla virtual de prueba que se elimina al terminar.
  Future<bool> isFts5Available() async {
    if (_db == null || _forceFallback) return false;
    try {
      await _db.customStatement('CREATE VIRTUAL TABLE IF NOT EXISTS fts5_probe USING fts5(content);');
      await _db.customStatement("INSERT INTO fts5_probe(content) VALUES ('probe');");
      final rows = await _db.customSelect("SELECT content FROM fts5_probe WHERE fts5_probe MATCH 'probe'").get();
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    } finally {
      try {
        await _db.customStatement('DROP TABLE IF EXISTS fts5_probe;');
      } catch (_) {}
    }
  }

  /// Crea la tabla virtual de búsqueda si no existe.
  ///
  /// Cuando [forceFallback] está activado no hace nada (simula que FTS5 no
  /// existe) para poder probar el fallback.
  Future<void> ensureFtsTable() async {
    if (_db == null || _forceFallback) return;
    await _db.customStatement(
      'CREATE VIRTUAL TABLE IF NOT EXISTS contacts_fts USING fts5(contact_id UNINDEXED, content);',
    );
  }

  /// Construye el texto indexable de un contacto a partir de sus datos reales.
  Future<String> _buildContent(String contactId) async {
    if (_db == null) return '';
    final contact = await (_db.select(_db.contacts)..where((t) => t.id.equals(contactId))).getSingleOrNull();
    if (contact == null) return '';
    final parts = <String>[];
    void add(String? v) {
      if (v != null && v.trim().isNotEmpty) parts.add(v.trim());
    }

    add(contact.givenName);
    add(contact.middleName);
    add(contact.familyName);
    add(contact.nickname);
    add(contact.phoneticGiven);
    add(contact.phoneticFamily);

    final phones = await (_db.select(_db.phones)..where((t) => t.contactId.equals(contactId))).get();
    for (final p in phones) {
      add(p.valueRaw);
    }
    final emails = await (_db.select(_db.emails)..where((t) => t.contactId.equals(contactId))).get();
    for (final e in emails) {
      add(e.value);
    }
    final addresses = await (_db.select(_db.addresses)..where((t) => t.contactId.equals(contactId))).get();
    for (final a in addresses) {
      add(a.street);
      add(a.city);
      add(a.region);
      add(a.country);
      add(a.postalCode);
    }
    final orgs = await (_db.select(_db.organizations)..where((t) => t.contactId.equals(contactId))).get();
    for (final o in orgs) {
      add(o.company);
      add(o.title);
      add(o.department);
    }
    final socials = await (_db.select(_db.socialLinks)..where((t) => t.contactId.equals(contactId))).get();
    for (final s in socials) {
      add(s.value);
    }
    final notes = await (_db.select(_db.notes)..where((t) => t.contactId.equals(contactId))).get();
    for (final n in notes) {
      add(n.content);
    }
    final customs = await (_db.select(_db.customFields)..where((t) => t.contactId.equals(contactId))).get();
    for (final c in customs) {
      add(c.value);
    }
    return parts.join(' ');
  }

  /// Inserta o actualiza un contacto en el índice FTS5.
  ///
  /// Debe llamarse dentro de una transacción SQLite activa (por ejemplo dentro
  /// de `_db!.transaction`). Asume que [ensureFtsTable] ya se ha ejecutado.
  Future<void> upsertWithinTransaction(String contactId) async {
    if (_db == null) return;
    try {
      final content = await _buildContent(contactId);
      await _db.customStatement('DELETE FROM contacts_fts WHERE contact_id = ?', [contactId]);
      await _db.customStatement(
        'INSERT INTO contacts_fts(contact_id, content) VALUES (?, ?)',
        [contactId, content],
      );
    } on Exception catch (_) {
      if (_forceFallback) {
        // FTS5 no está disponible; la búsqueda por fallback lee de SQLite, por
        // tanto los datos no se pierden, solo se busca más lento.
        return;
      }
      rethrow;
    }
  }

  /// Elimina un contacto del índice FTS5.
  ///
  /// Debe llamarse dentro de una transacción SQLite activa. Asume que
  /// [ensureFtsTable] ya se ha ejecutado.
  Future<void> deleteWithinTransaction(String contactId) async {
    if (_db == null) return;
    try {
      await _db.customStatement('DELETE FROM contacts_fts WHERE contact_id = ?', [contactId]);
    } on Exception catch (_) {
      if (_forceFallback) {
        return;
      }
      rethrow;
    }
  }

  /// Versión autónoma de [upsertWithinTransaction] (fuera de transacción).
  Future<void> upsert(String contactId) async {
    await ensureFtsTable();
    await upsertWithinTransaction(contactId);
  }

  /// Versión autónoma de [deleteWithinTransaction] (fuera de transacción).
  Future<void> delete(String contactId) async {
    await ensureFtsTable();
    await deleteWithinTransaction(contactId);
  }

  /// Normaliza texto para búsqueda: minúsculas, elimina tildes y acentos.
  ///
  /// Usa un mapeo manual de caracteres acentuados a su equivalente sin tilde,
  /// evitando dependencias externas y problemas de compatibilidad con Dart.
  static String _normalizeSearchText(String text) {
    final lower = text.toLowerCase();
    final result = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower.codeUnitAt(i);
      final base = _stripAccent(ch);
      result.writeCharCode(base);
    }
    return result.toString();
  }

  /// Devuelve el código de carácter base sin acento para un código dado.
  /// Si el carácter no es una letra acentuada, se devuelve igual.
  /// Devuelve el código de carácter base sin acento para un código dado.
  /// Si el carácter no es una letra acentuada, se devuelve igual.
  /// El código de entrada ya está en minúsculas (tras toLowerCase).
  static int _stripAccent(int code) {
    switch (code) {
      // a variantes (minúsculas)
      case 0x00E0: case 0x00E1: case 0x00E2: case 0x00E3: case 0x00E4: case 0x00E5:
      case 0x0101: case 0x0103: case 0x0105:
        return 0x0061; // 'a'
      // c variantes (minúsculas)
      case 0x00E7:
      case 0x0107: case 0x0109: case 0x010B: case 0x010D:
        return 0x0063; // 'c'
      // d variantes (minúsculas)
      case 0x00F0:
      case 0x010F: case 0x0111:
        return 0x0064; // 'd'
      // e variantes (minúsculas)
      case 0x00E8: case 0x00E9: case 0x00EA: case 0x00EB:
      case 0x0113: case 0x0115: case 0x0117: case 0x0119: case 0x011B:
      case 0x011D: case 0x011F:
        return 0x0065; // 'e'
      // g variantes (minúsculas)
      case 0x011E: case 0x0121: case 0x0123:
        return 0x0067; // 'g'
      // h variantes (minúsculas)
      case 0x0125: case 0x0127:
        return 0x0068; // 'h'
      // i variantes (minúsculas)
      case 0x00EC: case 0x00ED: case 0x00EE: case 0x00EF:
      case 0x0129: case 0x012B: case 0x012D: case 0x012F: case 0x0131:
        return 0x0069; // 'i'
      // j variantes (minúsculas)
      case 0x0135:
        return 0x006A; // 'j'
      // k variantes (minúsculas)
      case 0x0137:
        return 0x006B; // 'k'
      // l variantes (minúsculas)
      case 0x013A: case 0x013C: case 0x013E: case 0x0140: case 0x0142:
        return 0x006C; // 'l'
      // n variantes (minúsculas)
      case 0x00F1:
      case 0x0144: case 0x0146: case 0x0148:
        return 0x006E; // 'n'
      // o variantes (minúsculas)
      case 0x00F2: case 0x00F3: case 0x00F4: case 0x00F5: case 0x00F6: case 0x00F8:
      case 0x014D: case 0x014F: case 0x0151:
        return 0x006F; // 'o'
      // r variantes (minúsculas)
      case 0x0155: case 0x0157: case 0x0159:
        return 0x0072; // 'r'
      // s variantes (minúsculas)
      case 0x015B: case 0x015D: case 0x015F: case 0x0161:
        return 0x0073; // 's'
      // t variantes (minúsculas)
      case 0x0163: case 0x0165: case 0x0167:
        return 0x0074; // 't'
      // u variantes (minúsculas)
      case 0x00F9: case 0x00FA: case 0x00FB: case 0x00FC:
      case 0x0169: case 0x016B: case 0x016D: case 0x016F: case 0x0171: case 0x0173:
        return 0x0075; // 'u'
      // w variantes (minúsculas)
      case 0x0175: case 0x0177:
        return 0x0077; // 'w'
      // y variantes (minúsculas)
      case 0x00FF: case 0x0179:
        return 0x0079; // 'y'
      // z variantes (minúsculas)
      case 0x017A: case 0x017C: case 0x017E:
        return 0x007A; // 'z'
      default:
        return code;
    }
  }

  /// Normaliza un número de teléfono para búsqueda: elimina todo lo que no sea
  /// dígito o signo más.
  static String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  /// Busca identificadores de contacto que coincidan con la consulta.
  ///
  /// La búsqueda es insensible a tildes y mayúsculas: buscar "jos" encuentra
  /// "José", buscar "gar" encuentra "García". También busca por teléfonos y
  /// correos electrónicos de forma parcial.
  ///
  /// Usa coincidencia de subcadena sobre contenido normalizado (sin tildes),
  /// ya que FTS5 tokeniza las palabras y no encuentra coincidencias parciales
  /// dentro de palabras.
  Future<List<String>> searchIds(String query, {bool favoritesOnly = false, String? tagId, String? collectionId}) async {
    if (_db == null) return [];
    await ensureFtsTable();
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final normalizedQuery = _normalizeSearchText(trimmed);
    final normalizedPhone = _normalizePhone(trimmed);

    final all = await _db.select(_db.contacts).get();
    var result = <String>[];
    final seen = <String>{};

    for (final c in all) {
      // 1) Búsqueda por nombre/nombre completo (normalizado, sin tildes)
      final content = await _buildContent(c.id);
      final normContent = _normalizeSearchText(content);
      if (normContent.contains(normalizedQuery)) {
        result.add(c.id);
        seen.add(c.id);
        continue;
      }

      // 2) Búsqueda por teléfono (coincidencia parcial)
      final phones = await (_db.select(_db.phones)..where((t) => t.contactId.equals(c.id))).get();
      for (final p in phones) {
        final normPhone = _normalizePhone(p.valueRaw);
        if (normalizedPhone.isNotEmpty && normPhone.isNotEmpty && normPhone.contains(normalizedPhone)) {
          result.add(c.id);
          seen.add(c.id);
          break;
        }
      }
      if (seen.contains(c.id)) continue;

      // 3) Búsqueda por correo electrónico
      final emails = await (_db.select(_db.emails)..where((t) => t.contactId.equals(c.id))).get();
      for (final e in emails) {
        if (_normalizeSearchText(e.value).contains(normalizedQuery)) {
          result.add(c.id);
          seen.add(c.id);
          break;
        }
      }
    }

    result = result.toSet().toList();

    // Aplicar filtros (funcionan tanto con FTS5 como con fallback).
    if (favoritesOnly) {
      final favs = await (_db.select(_db.contacts)..where((t) => t.isFavorite.equals(true))).get();
      final favIds = favs.map((c) => c.id).toSet();
      result = result.where((id) => favIds.contains(id)).toList();
    }
    if (tagId != null) {
      final rows = await (_db.select(_db.contactTags)..where((t) => t.tagId.equals(tagId))).get();
      final tagContactIds = rows.map((r) => r.contactId).toSet();
      result = result.where((id) => tagContactIds.contains(id)).toList();
    }
    if (collectionId != null) {
      final rows = await (_db.select(_db.collectionContacts)..where((t) => t.collectionId.equals(collectionId))).get();
      final collContactIds = rows.map((r) => r.contactId).toSet();
      result = result.where((id) => collContactIds.contains(id)).toList();
    }
    return result;
  }

  /// Cancela cualquier búsqueda en progreso. Útil cuando el widget se descarta.
  void cancel() {
    // No-op: el debounce se gestiona en el widget de búsqueda
  }
}
