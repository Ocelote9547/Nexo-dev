import 'dart:convert';
import 'dart:typed_data';

import 'package:nexo/core/errors/nexo_exception.dart';
import 'package:nexo/features/import_export/data/services/quoted_printable_decoder.dart';
import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexo/features/import_export/data/services/duplicate_detection_service.dart';
import 'package:nexo/features/import_export/domain/entities/import_export.dart';
import 'package:nexo/features/import_export/domain/repositories/import_export_repository.dart';
import 'package:nexo/features/tags/domain/repositories/tag_repository.dart';
import 'package:nexo/features/collections/domain/repositories/collection_repository.dart';
import 'package:nexo/services/media/media_service.dart';

/// Una propiedad vCard parseada, con sus parámetros y valores.
class _VcardProperty {
  final String name;
  final Map<String, String> parameters;
  final List<String> values;

  _VcardProperty({required this.name, this.parameters = const {}, this.values = const []});

  /// Valor decodificado según los parámetros de la propiedad.
  ///
  /// Siempre aplica decodificación Quoted-Printable, incluso si falta el
  /// parámetro ENCODING=QUOTED-PRINTABLE. Algunos exportadores no lo
  /// incluyen aunque el valor contenga secuencias =HH.
  String get decodedValue {
    final raw = values.join('');
    return decodeVCardValue(raw);
  }

  /// Valor decodificado como Base64 (para fotografías).
  Uint8List? get base64Decoded {
    final raw = values.join('');
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }
}

/// Una tarjeta vCard parseada.
class _VcardCard {
  final String? version;
  final List<_VcardProperty> properties;

  _VcardCard({this.version, this.properties = const []});

  String? get(String name) {
    for (final p in properties) {
      if (p.name.toUpperCase() == name.toUpperCase()) {
        return p.decodedValue;
      }
    }
    return null;
  }

  List<String> getAll(String name) {
    final result = <String>[];
    for (final p in properties) {
      if (p.name.toUpperCase() == name.toUpperCase()) {
        result.addAll(p.values.map((v) => p.decodedValue));
      }
    }
    return result;
  }

  /// Obtiene el parámetro TYPE de una propiedad (ej. TEL;TYPE=CELL).
  String? getTypeParam(String name) {
    for (final p in properties) {
      if (p.name.toUpperCase() == name.toUpperCase()) {
        return p.parameters['TYPE'];
      }
    }
    return null;
  }
}

/// Parsea el contenido de un archivo vCard/VCF en una lista de tarjetas.
///
/// Soporta:
/// - Líneas plegadas (continuación con espacio/tab)
/// - vCard 2.1 y 3.0
/// - Parámetros CHARSET, ENCODING, TYPE
/// - Quoted-Printable (solo cuando ENCODING=QUOTED-PRINTABLE)
/// - Base64 (fotografías)
/// - Propiedades desconocidas (se conservan sin hacer fallar la tarjeta)
List<_VcardCard> _parseVcfCards(String vcfContent) {
  final cards = <_VcardCard>[];
  var current = <_VcardProperty>[];
  var inCard = false;

  // Reconstruir líneas plegadas: una línea que empieza con espacio o tab
  // es continuación de la línea anterior.
  // Se mantiene la línea actual como "pendiente" hasta que llega la siguiente
  // línea no-continuación, momento en que se añade a lines completa.
  final lines = <String>[];
  String? pendingLine;
  for (final rawLine in vcfContent.split('\n')) {
    final line = rawLine.replaceAll('\r', '');
    if (line.isEmpty) continue;
    if (line.startsWith(' ') || line.startsWith('\t')) {
      // Continuación de la línea anterior: append al valor después de ':'
      if (pendingLine != null) {
        final colonIdx = pendingLine.lastIndexOf(':');
        if (colonIdx != -1) {
          pendingLine =
              pendingLine.substring(0, colonIdx + 1) +
              pendingLine.substring(colonIdx + 1) +
              line.trim();
        }
      }
    } else {
      // Nueva propiedad: guardar la pendiente si existe
      if (pendingLine != null) {
        lines.add(pendingLine);
      }
      pendingLine = line;
    }
  }
  // Última línea pendiente
  if (pendingLine != null) {
    lines.add(pendingLine);
  }

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed == 'BEGIN:VCARD') {
      current = [];
      inCard = true;
    } else if (trimmed == 'END:VCARD') {
      if (inCard) {
        cards.add(_VcardCard(version: _getVersion(current), properties: List.unmodifiable(current)));
      }
      current = [];
      inCard = false;
    } else if (inCard) {
      _parseVcfLine(trimmed, current);
    }
  }

  return cards;
}

/// Extrae la versión de una lista de propiedades vCard.
String? _getVersion(List<_VcardProperty> props) {
  for (final p in props) {
    if (p.name.toUpperCase() == 'VERSION') {
      return p.values.isNotEmpty ? p.values.first : null;
    }
  }
  return null;
}

/// Parsea una única línea vCard y la añade a las propiedades de la tarjeta actual.
void _parseVcfLine(String line, List<_VcardProperty> props) {
  final colonIdx = line.indexOf(':');
  if (colonIdx == -1) return;

  final keyPart = line.substring(0, colonIdx);
  final value = line.substring(colonIdx + 1);

  // Separar nombre de propiedad de parámetros: FN;CHARSET=UTF-8;ENCODING=QP
  final segments = keyPart.split(';');
  final name = segments.first.toUpperCase();
  final parameters = <String, String>{};
  for (var i = 1; i < segments.length; i++) {
    final seg = segments[i];
    final eqIdx = seg.indexOf('=');
    if (eqIdx != -1) {
      parameters[seg.substring(0, eqIdx).toUpperCase()] = seg.substring(eqIdx + 1);
    } else {
      // Parámetro sin valor (ej. TYPE=CELL en vCard 2.1 a veces es solo CELL)
      parameters[seg.toUpperCase()] = '';
    }
  }

  props.add(_VcardProperty(name: name, parameters: parameters, values: [value]));
}

/// Resultado de convertir una tarjeta vCard a PortableContact.
///
/// Incluye advertencias por propiedades que no se pudieron procesar
/// completamente (fotos inválidas, URLs de foto, etc.) sin fallar el contacto.
class _VcardConversionResult {
  final PortableContact contact;
  final List<String> warnings;
  final int photosImported;
  final int photosUnavailable;

  _VcardConversionResult({
    required this.contact,
    required this.warnings,
    this.photosImported = 0,
    this.photosUnavailable = 0,
  });
}

/// Convierte una tarjeta vCard parseada en un PortableContact.
///
/// Las propiedades desconocidas o con errores no hacen fallar la tarjeta;
/// se registran como advertencias en [warnings].
_VcardConversionResult _vCardToPortableContact(_VcardCard card) {
  final warnings = <String>[];
  final fn = card.get('FN') ?? '';
  final nProp = card.properties.where((p) => p.name == 'N').firstOrNull;
  final nValues = nProp != null ? nProp.values.map((v) => nProp.decodedValue).toList() : <String>[];

  String? givenName;
  String? familyName;
  if (nValues.isNotEmpty) {
    final nameParts = nValues.first.split(';');
    familyName = nameParts.isNotEmpty && nameParts[0].isNotEmpty ? nameParts[0] : null;
    givenName = nameParts.length > 1 ? nameParts[1] : null;
  }
  if ((givenName == null || givenName.isEmpty) &&
      (familyName == null || familyName.isEmpty) &&
      fn.isNotEmpty) {
    givenName = fn;
  }

  // Teléfonos (incluidos tipos personalizados: X-Móvil, X-Fijo, X-WhatsApp)
  final phones = <PortablePhone>[];
  var phoneIndex = 0;
  for (final p in card.properties.where((p) => p.name == 'TEL')) {
    final typeParam = p.parameters['TYPE'] ?? '';
    final label = _mapVcardPhoneLabel(typeParam);
    phones.add(PortablePhone(
      id: '',
      valueRaw: p.decodedValue,
      label: label,
      customLabel: typeParam.isNotEmpty && !_isStandardPhoneType(typeParam) ? typeParam : null,
      sortOrder: phoneIndex++,
    ));
  }

  // Correos electrónicos
  final emails = <PortableEmail>[];
  var emailIndex = 0;
  for (final p in card.properties.where((p) => p.name == 'EMAIL')) {
    final typeParam = p.parameters['TYPE'] ?? '';
    final label = _mapVcardEmailLabel(typeParam);
    emails.add(PortableEmail(
      id: '',
      value: p.decodedValue,
      label: label,
      customLabel: typeParam.isNotEmpty && !_isStandardEmailType(typeParam) ? typeParam : null,
      sortOrder: emailIndex++,
    ));
  }

  // Direcciones
  final addresses = <PortableAddress>[];
  var addrIndex = 0;
  for (final p in card.properties.where((p) => p.name == 'ADR')) {
    final parts = p.decodedValue.split(';');
    addresses.add(PortableAddress(
      id: '',
      label: p.parameters['TYPE'] ?? '',
      street: parts.length > 2 ? parts[2] : null,
      city: parts.length > 3 ? parts[3] : null,
      region: parts.length > 4 ? parts[4] : null,
      postalCode: parts.length > 6 ? parts[6] : null,
      country: parts.length > 7 ? parts[7] : null,
      sortOrder: addrIndex++,
    ));
  }

  // Organizaciones (vCard 2.1 usa ORG; vCard 3.0 también)
  final organizations = <PortableOrganization>[];
  var orgIndex = 0;
  for (final p in card.properties.where((p) => p.name == 'ORG')) {
    final parts = p.decodedValue.split(';');
    organizations.add(PortableOrganization(
      id: '',
      company: parts.isNotEmpty ? parts[0] : null,
      title: parts.length > 1 ? parts[1] : null,
      sortOrder: orgIndex++,
    ));
  }

  // Redes sociales (vCard 2.1 no tiene URL estándar; usar X- propiedades)
  final socialLinks = <PortableSocialLink>[];
  var socialIndex = 0;
  for (final p in card.properties.where((p) => p.name.startsWith('X-') || p.name == 'URL')) {
    socialLinks.add(PortableSocialLink(
      id: '',
      type: p.name,
      value: p.decodedValue,
      sortOrder: socialIndex++,
    ));
  }

  // Fechas (cumpleaños completos y parciales --MM-DD)
  final dates = <PortableContactDate>[];
  var dateIndex = 0;
  for (final p in card.properties.where((p) => p.name == 'BDAY')) {
    final bdayStr = p.decodedValue;
    final parsed = _parseVcardBirthday(bdayStr);
    if (parsed != null) {
      dates.add(PortableContactDate(
        id: '',
        type: 'birthday',
        date: parsed['date'] as DateTime,
        yearUnknown: parsed['yearUnknown'] as bool,
        sortOrder: dateIndex++,
      ));
    }
  }

  // Notas
  final notes = <PortableNote>[];
  for (final p in card.properties.where((p) => p.name == 'NOTE')) {
    notes.add(PortableNote(
      id: '',
      content: p.decodedValue,
      source: 'vcard',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ));
  }

  // Apodo (NICKNAME) — solo de campo explícito, nunca derivado de FN
  String? nickname;
  for (final p in card.properties.where((p) => p.name == 'NICKNAME')) {
    final nick = p.decodedValue.trim();
    if (nick.isNotEmpty) {
      nickname = nick;
      break; // Usar el primer NICKNAME válido
    }
  }

  // Campos personalizados (X-ANDROID-CUSTOM y otras X- propiedades no sociales)
  final customFields = <PortableCustomField>[];
  var customIndex = 0;
  for (final p in card.properties.where((p) => p.name.startsWith('X-') && p.name != 'X-ANDROID-CUSTOM')) {
    customFields.add(PortableCustomField(
      id: '',
      name: p.name,
      type: 'text',
      value: p.decodedValue,
      sortOrder: customIndex++,
    ));
  }

  // Fotografía (Base64)
  String? photoBase64;
  String? photoMimeType;
  var photoWarning = <String>[];
  var photosImported = 0;
  var photosUnavailable = 0;
  for (final p in card.properties.where((p) => p.name == 'PHOTO')) {
    final typeParam = p.parameters['TYPE'] ?? '';
    final rawValue = p.values.join('');

    // Detectar URL de foto externa (no se puede importar localmente)
    if (rawValue.startsWith('http://') || rawValue.startsWith('https://')) {
      photoWarning.add('Foto ignorada: URL externa no admitida (${rawValue.substring(0, rawValue.length.clamp(0, 50))})');
      photosUnavailable++;
      continue;
    }

    photoMimeType = typeParam.isNotEmpty ? 'image/$typeParam' : 'image/jpeg';

    // Para ENCODING=BASE64 / ENCODING=b, el valor ya está en decodedValue como texto crudo
    // (no se aplicó QP). Para otros casos, decodedValue puede tener QP aplicado.
    final decoded = p.base64Decoded;
    if (decoded != null) {
      photoBase64 = base64Encode(decoded);
      photosImported++;
    } else {
      // Intentar decodificar como Base64 el valor crudo (texto plano)
      try {
        final decodedBytes = base64Decode(rawValue);
        photoBase64 = base64Encode(decodedBytes);
        photosImported++;
      } catch (_) {
        photoWarning.add('Foto ignorada: datos Base64 inválidos o no reconocidos');
        photosUnavailable++;
        photoBase64 = null;
      }
    }
  }

  warnings.addAll(photoWarning);

  return _VcardConversionResult(
    contact: PortableContact(
      id: '',
      givenName: givenName?.isNotEmpty == true ? givenName : null,
      familyName: familyName?.isNotEmpty == true ? familyName : null,
      nickname: nickname,
      photoBase64: photoBase64,
      photoMimeType: photoMimeType,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      phones: phones,
      emails: emails,
      addresses: addresses,
      socialLinks: socialLinks,
      organizations: organizations,
      dates: dates,
      notes: notes,
      customFields: customFields,
    ),
    warnings: warnings,
    photosImported: photosImported,
    photosUnavailable: photosUnavailable,
  );
}

/// Convierte el parámetro TYPE de un teléfono vCard a una etiqueta estándar.
String _mapVcardPhoneLabel(String typeParam) {
  final upper = typeParam.toUpperCase();
  switch (upper) {
    case 'CELL':
    case 'MOBILE':
      return 'mobile';
    case 'HOME':
      return 'home';
    case 'WORK':
    case 'PREF':
      return 'work';
    case 'FAX':
      return 'fax';
    case 'PAGER':
      return 'pager';
    default:
      return 'mobile';
  }
}

/// Convierte el parámetro TYPE de un correo vCard a una etiqueta estándar.
String _mapVcardEmailLabel(String typeParam) {
  final upper = typeParam.toUpperCase();
  switch (upper) {
    case 'HOME':
      return 'home';
    case 'WORK':
    case 'PREF':
      return 'work';
    case 'INTERNET':
      return 'home';
    default:
      return 'home';
  }
}

/// Determina si un tipo de teléfono es estándar (no necesita customLabel).
bool _isStandardPhoneType(String type) {
  final upper = type.toUpperCase();
  return upper.isEmpty ||
      upper == 'CELL' ||
      upper == 'MOBILE' ||
      upper == 'HOME' ||
      upper == 'WORK' ||
      upper == 'PREF' ||
      upper == 'FAX' ||
      upper == 'PAGER';
}

/// Determina si un tipo de correo es estándar (no necesita customLabel).
bool _isStandardEmailType(String type) {
  final upper = type.toUpperCase();
  return upper.isEmpty ||
      upper == 'HOME' ||
      upper == 'WORK' ||
      upper == 'PREF' ||
      upper == 'INTERNET';
}

/// Parsea un cumpleaños vCard, soportando formatos completos y parciales.
///
/// - `YYYY-MM-DD`: fecha completa
/// - `--MM-DD`: fecha parcial (año desconocido), se almacena con yearUnknown=true
///   y una fecha ficticia en el año 2000 para permitir ordenamiento.
///
/// Devuelve null si el formato no es reconocible.
Map<String, dynamic>? _parseVcardBirthday(String value) {
  if (value.isEmpty) return null;

  // Formato parcial --MM-DD
  if (value.startsWith('--')) {
    final rest = value.substring(2);
    final parts = rest.split('-');
    if (parts.length == 2) {
      final month = int.tryParse(parts[0]);
      final day = int.tryParse(parts[1]);
      if (month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return {
          'date': DateTime(2000, month, day),
          'yearUnknown': true,
        };
      }
    }
    return null;
  }

  // Formato completo YYYY-MM-DD
  final parts = value.split('-');
  if (parts.length == 3) {
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year != null && month != null && day != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
      try {
        return {
          'date': DateTime(year, month, day),
          'yearUnknown': false,
        };
      } catch (_) {
        return null;
      }
    }
  }

  return null;
}

class ImportExportRepositoryImpl implements ImportExportRepository {
  final ContactRepository _contactRepository;
  final DuplicateDetectionService _duplicateDetection;
  final TagRepository? _tagRepository;
  final CollectionRepository? _collectionRepository;
  final MediaService _media;

  ImportExportRepositoryImpl({
    required this._contactRepository,
    required this._duplicateDetection,
    required this._media,
    this._tagRepository,
    this._collectionRepository,
  });

  Future<PortableContact> _contactToPortableWithRelations(
    ContactWithRelations rel,
  ) async {
    return PortableContact(
      id: rel.contact.id,
      givenName: rel.contact.givenName,
      middleName: rel.contact.middleName,
      familyName: rel.contact.familyName,
      prefix: rel.contact.prefix,
      suffix: rel.contact.suffix,
      phoneticGiven: rel.contact.phoneticGiven,
      phoneticFamily: rel.contact.phoneticFamily,
      nickname: rel.contact.nickname,
      photoPath: rel.contact.photoPath,
      photoHash: rel.contact.photoHash,
      isFavorite: rel.contact.isFavorite,
      favoriteMarkedAt: rel.contact.favoriteMarkedAt,
      createdAt: rel.contact.createdAt,
      updatedAt: rel.contact.updatedAt,
      phones: rel.phones.map((p) => PortablePhone(
        id: p.id,
        valueRaw: p.valueRaw,
        valueNormalized: p.valueNormalized,
        label: p.label,
        isPrimary: p.isPrimary,
        sortOrder: p.sortOrder,
      )).toList(),
      emails: rel.emails.map((e) => PortableEmail(
        id: e.id,
        value: e.value,
        label: e.label,
        isPrimary: e.isPrimary,
        sortOrder: e.sortOrder,
      )).toList(),
      addresses: rel.addresses.map((a) => PortableAddress(
        id: a.id,
        label: a.label,
        street: a.street,
        number: a.number,
        apartment: a.apartment,
        postalCode: a.postalCode,
        city: a.city,
        region: a.region,
        country: a.country,
        latitude: a.latitude,
        longitude: a.longitude,
        sortOrder: a.sortOrder,
      )).toList(),
      socialLinks: rel.socialLinks.map((s) => PortableSocialLink(
        id: s.id,
        type: s.type,
        value: s.value,
        url: s.url,
        label: s.label,
        sortOrder: s.sortOrder,
      )).toList(),
      organizations: rel.organizations.map((o) => PortableOrganization(
        id: o.id,
        company: o.company,
        title: o.title,
        department: o.department,
        website: o.website,
        notes: o.notes,
        isPrimary: o.isPrimary,
        sortOrder: o.sortOrder,
      )).toList(),
      dates: rel.dates.map((d) => PortableContactDate(
        id: d.id,
        type: d.type,
        label: d.label,
        date: d.date,
        yearUnknown: d.yearUnknown,
        recurrence: d.recurrence,
        sortOrder: d.sortOrder,
      )).toList(),
      notes: rel.notes.map((n) => PortableNote(
        id: n.id,
        content: n.content,
        source: n.source,
        createdAt: n.createdAt,
        updatedAt: n.updatedAt,
      )).toList(),
      customFields: rel.customFields.map((c) => PortableCustomField(
        id: c.id,
        name: c.name,
        type: c.type,
        value: c.value,
        sortOrder: c.sortOrder,
      )).toList(),
      tagIds: _tagRepository != null
          ? await _tagRepository.getTagIdsForContact(rel.contact.id)
          : const [],
      collectionIds: _collectionRepository != null
          ? await _collectionRepository.getCollectionIdsForContact(rel.contact.id)
          : const [],
    );
  }

  Future<ContactWithRelations> _portableToContactWithRelations(
    PortableContact pc, {
    bool isNew = true,
  }) async {
    final contact = Contact(
      id: isNew ? null : pc.id,
      givenName: pc.givenName,
      middleName: pc.middleName,
      familyName: pc.familyName,
      prefix: pc.prefix,
      suffix: pc.suffix,
      phoneticGiven: pc.phoneticGiven,
      phoneticFamily: pc.phoneticFamily,
      nickname: pc.nickname,
      photoPath: pc.photoPath,
      photoHash: pc.photoHash,
      isFavorite: pc.isFavorite,
      favoriteMarkedAt: pc.favoriteMarkedAt,
      createdAt: pc.createdAt,
      updatedAt: pc.updatedAt,
    );

    final phones = pc.phones.map((p) => Phone(
      id: isNew ? null : p.id,
      contactId: contact.id,
      valueRaw: p.valueRaw,
      valueNormalized: p.valueNormalized,
      label: p.label,
      isPrimary: p.isPrimary,
      sortOrder: p.sortOrder,
    )).toList();

    final emails = pc.emails.map((e) => Email(
      id: isNew ? null : e.id,
      contactId: contact.id,
      value: e.value,
      label: e.label,
      isPrimary: e.isPrimary,
      sortOrder: e.sortOrder,
    )).toList();

    final addresses = pc.addresses.map((a) => Address(
      id: isNew ? null : a.id,
      contactId: contact.id,
      label: a.label,
      street: a.street,
      number: a.number,
      apartment: a.apartment,
      postalCode: a.postalCode,
      city: a.city,
      region: a.region,
      country: a.country,
      latitude: a.latitude,
      longitude: a.longitude,
      sortOrder: a.sortOrder,
    )).toList();

    final socialLinks = pc.socialLinks.map((s) => SocialLink(
      id: isNew ? null : s.id,
      contactId: contact.id,
      type: s.type,
      value: s.value,
      url: s.url,
      label: s.label,
      sortOrder: s.sortOrder,
    )).toList();

    final organizations = pc.organizations.map((o) => Organization(
      id: isNew ? null : o.id,
      contactId: contact.id,
      company: o.company,
      title: o.title,
      department: o.department,
      website: o.website,
      notes: o.notes,
      isPrimary: o.isPrimary,
      sortOrder: o.sortOrder,
    )).toList();

    final dates = pc.dates.map((d) => ContactDate(
      id: isNew ? null : d.id,
      contactId: contact.id,
      type: d.type,
      label: d.label,
      date: d.date,
      yearUnknown: d.yearUnknown,
      recurrence: d.recurrence,
      sortOrder: d.sortOrder,
    )).toList();

    final notes = pc.notes.map((n) => Note(
      id: isNew ? null : n.id,
      contactId: contact.id,
      content: n.content,
      source: n.source,
      createdAt: n.createdAt,
      updatedAt: n.updatedAt,
    )).toList();

    final customFields = pc.customFields.map((c) => CustomField(
      id: isNew ? null : c.id,
      contactId: contact.id,
      name: c.name,
      type: c.type,
      value: c.value,
      sortOrder: c.sortOrder,
    )).toList();

    return ContactWithRelations(
      contact: contact,
      phones: phones,
      emails: emails,
      addresses: addresses,
      socialLinks: socialLinks,
      organizations: organizations,
      dates: dates,
      notes: notes,
      customFields: customFields,
    );
  }

  @override
  Future<String> importPortableContact(
    PortableContact contact, {
    DuplicateResolution? resolution,
    List<String>? warnings,
    List<ContactWithRelations>? existingContacts,
  }) async {
    final duplicates = await _duplicateDetection.findDuplicates(
      contact,
      existingContacts: existingContacts,
    );

    if (duplicates.isNotEmpty && resolution == null) {
      // Solo omitir si hay una coincidencia fuerte (confianza >= 0.8).
      // Coincidencias débiles (solo nombre o solo apellido) no deben bloquear la importación.
      DuplicateCandidate? strongDup;
      for (final d in duplicates) {
        if (d.isStrongMatch) {
          strongDup = d;
          break;
        }
      }
      if (strongDup != null) {
        // Enriquecer el contacto existente con la fotografía del VCF si
        // el contacto no tiene foto y el entrante sí la tiene.
        if (contact.photoBase64 != null && contact.photoBase64!.isNotEmpty) {
          try {
            await _enrichExistingContactPhoto(strongDup.nexoContactId, contact, warnings);
          } catch (_) {
            // No fallar la importación si el enriquecimiento de foto falla.
          }
        }
        return strongDup.nexoContactId;
      }
    }

    // Si el contacto entrante ya tiene un ID y ese contacto existe en la BD,
    // tratarlo como duplicado (no crear uno nuevo con ID existente).
    if (contact.id.isNotEmpty) {
      final existingId = existingContacts?.firstWhere(
        (c) => c.contact.id == contact.id,
        orElse: () => ContactWithRelations(contact: Contact(id: '')),
      ).contact.id;
      if (existingId != null && existingId.isNotEmpty) {
        return existingId;
      }
      final existingById = await _contactRepository.getContactById(contact.id);
      if (existingById != null) {
        return contact.id;
      }
    }

    final isNew = contact.id.isEmpty;
    final cwr = await _portableToContactWithRelations(contact, isNew: isNew);
    final created = await _contactRepository.createContact(
      cwr.contact,
      phones: cwr.phones,
      emails: cwr.emails,
      addresses: cwr.addresses,
      socialLinks: cwr.socialLinks,
      organizations: cwr.organizations,
      dates: cwr.dates,
      notes: cwr.notes,
      customFields: cwr.customFields,
    );

    // Guardar fotografía importada desde vCard (Base64 -> archivo local)
    if (contact.photoBase64 != null && contact.photoBase64!.isNotEmpty) {
      try {
        final photoBytes = base64Decode(contact.photoBase64!);
        final mime = contact.photoMimeType ?? 'image/jpeg';
        final ext = mime.contains('jpeg') || mime.contains('jpg')
            ? 'jpg'
            : mime.contains('png')
                ? 'png'
                : 'bin';
        final rel = await _media.saveBytes(created.id, 'photo.$ext', photoBytes);
        await _contactRepository.updateContactPhotoPath(created.id, rel);
      } catch (e) {
        final displayName = contact.givenName != null && contact.familyName != null
            ? '${contact.givenName} ${contact.familyName}'
            : contact.givenName ?? contact.familyName ?? contact.id;
        warnings?.add('Foto no guardada para contacto "$displayName": ${e.toString()}');
      }
    }

    if (_tagRepository != null) {
      for (final tagId in contact.tagIds) {
        await _tagRepository.addTagToContact(tagId, created.id);
      }
    }
    if (_collectionRepository != null) {
      for (final collId in contact.collectionIds) {
        await _collectionRepository.addContactToCollection(collId, created.id);
      }
    }

    return created.id;
  }

  /// Enriquece un contacto existente con la fotografía del VCF cuando el
  /// contacto no tiene foto y el entrante sí la tiene.
  /// No sobrescribe si el contacto ya tiene fotoPath.
  Future<void> _enrichExistingContactPhoto(
    String existingContactId,
    PortableContact incomingContact, [
    List<String>? warnings,
  ]) async {
    final existing = await _contactRepository.getContactWithRelations(existingContactId);
    if (existing == null) return;
    if (existing.contact.photoPath != null && existing.contact.photoPath!.isNotEmpty) return;
    if (incomingContact.photoBase64 == null || incomingContact.photoBase64!.isEmpty) return;

    try {
      final photoBytes = base64Decode(incomingContact.photoBase64!);
      final mime = incomingContact.photoMimeType ?? 'image/jpeg';
      final ext = mime.contains('jpeg') || mime.contains('jpg')
          ? 'jpg'
          : mime.contains('png')
              ? 'png'
              : 'bin';
      final rel = await _media.saveBytes(existingContactId, 'photo.$ext', photoBytes);
      await _contactRepository.updateContactPhotoPath(existingContactId, rel);
    } catch (e) {
      warnings?.add('Foto no guardada para contacto existente $existingContactId: $e');
    }
  }

  @override
  Future<PortableContact> exportContactToPortable(String contactId) async {
    final rel = await _contactRepository.getContactWithRelations(contactId);
    if (rel == null) {
      throw const NotFoundException('Contacto no encontrado');
    }
    return await _contactToPortableWithRelations(rel);
  }

  @override
  Future<List<PortableContact>> exportAllContactsToPortable({
    ImportProgressCallback? onProgress,
  }) async {
    final rels = await _contactRepository.getAllContactsWithRelations();
    final result = <PortableContact>[];
    int processed = 0;
    final total = rels.length;

    for (final rel in rels) {
      result.add(await _contactToPortableWithRelations(rel));
      processed++;
      // Yield to event loop between contacts to keep UI responsive
      await Future.delayed(Duration.zero);
      if (processed % 10 == 0) {
        onProgress?.call(ImportProgressInfo(
          processed: processed,
          total: total,
          created: processed,
          errors: 0,
          photosImported: 0,
          photosUnavailable: 0,
          currentSource: rel.contact.id,
        ));
      }
    }

    onProgress?.call(ImportProgressInfo(
      processed: processed,
      total: total,
      created: processed,
      errors: 0,
      currentSource: null,
    ));

    return result;
  }

  @override
  Future<String> exportContactToVCard(String contactId) async {
    final rel = await _contactRepository.getContactWithRelations(contactId);
    if (rel == null) {
      throw const NotFoundException('Contacto no encontrado');
    }
    return _contactToVCardString(rel);
  }

  @override
  Future<String> exportAllContactsToVCard({
    ImportProgressCallback? onProgress,
  }) async {
    final rels = await _contactRepository.getAllContactsWithRelations();
    final cards = <String>[];
    int processed = 0;
    final total = rels.length;

    for (final rel in rels) {
      cards.add(_contactToVCardString(rel));
      processed++;
      // Yield to event loop between contacts to keep UI responsive
      await Future.delayed(Duration.zero);
      if (processed % 5 == 0) {
        await Future.delayed(Duration(milliseconds: 10));
        onProgress?.call(ImportProgressInfo(
          processed: processed,
          total: total,
          created: processed,
          errors: 0,
          photosImported: 0,
          photosUnavailable: 0,
          currentSource: rel.contact.id,
        ));
      }
    }

    onProgress?.call(ImportProgressInfo(
      processed: processed,
      total: total,
      created: processed,
      errors: 0,
      currentSource: null,
    ));

    return cards.join('\r\n');
  }

  /// Build vCard content from already-loaded relations (avoids per-contact DB queries).
  String _contactToVCardString(ContactWithRelations rel) {
    final lines = <String>[];
    lines.add('BEGIN:VCARD');
    lines.add('VERSION:3.0');

    lines.add('FN:${encodeVCardValue(rel.contact.displayName)}');

    if (rel.contact.givenName != null || rel.contact.familyName != null) {
      lines.add(
        'N:${encodeVCardValue(rel.contact.familyName ?? '')};'
        '${encodeVCardValue(rel.contact.givenName ?? '')};'
        '${encodeVCardValue(rel.contact.middleName ?? '')};'
        '${encodeVCardValue(rel.contact.prefix ?? '')};'
        '${encodeVCardValue(rel.contact.suffix ?? '')}',
      );
    }

    for (final p in rel.phones) {
      lines.add('TEL;TYPE=${p.label}:${encodeVCardValue(p.valueRaw)}');
    }

    for (final e in rel.emails) {
      lines.add('EMAIL;TYPE=${e.label}:${encodeVCardValue(e.value)}');
    }

    for (final a in rel.addresses) {
      lines.add(
        'ADR;TYPE=${a.label ?? ''}:;;${encodeVCardValue(a.street ?? '')};'
        '${encodeVCardValue(a.city ?? '')};'
        '${encodeVCardValue(a.region ?? '')};${encodeVCardValue(a.postalCode ?? '')};'
        '${encodeVCardValue(a.country ?? '')}',
      );
    }

    for (final o in rel.organizations) {
      lines.add('ORG:${encodeVCardValue(o.company ?? '')};'
          '${encodeVCardValue(o.title ?? '')}');
      if (o.department != null) {
        lines.add('X-DEPARTMENT:${encodeVCardValue(o.department!)}');
      }
    }

    for (final s in rel.socialLinks) {
      lines.add('X-${s.type}:${encodeVCardValue(s.value)}');
    }

    for (final d in rel.dates) {
      final dateStr = d.yearUnknown
          ? '--${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}'
          : '${d.date.year}-${d.date.month.toString().padLeft(2, '0')}-${d.date.day.toString().padLeft(2, '0')}';
      lines.add('BDAY:$dateStr');
    }

    lines.add('END:VCARD');
    return lines.join('\r\n');
  }

  @override
  Future<String> exportContactsToCsv({
    List<String>? contactIds,
    ImportProgressCallback? onProgress,
  }) async {
    final rels = await _contactRepository.getAllContactsWithRelations();
    final contactsToExport = contactIds != null
        ? rels.where((r) => contactIds.contains(r.contact.id)).toList()
        : rels;

    final lines = <String>[];
    // Cabecera CSV
    lines.add(
      'id,givenName,middleName,familyName,prefix,suffix,nickname,isFavorite,'
      'createdAt,updatedAt,phones,emails,addresses,socialLinks,organizations,'
      'dates,notes,customFields,photoPath,photoHash,favoriteMarkedAt',
    );

    int processed = 0;
    final total = contactsToExport.length;
    for (final rel in contactsToExport) {
      lines.add(_contactToCsvRow(rel));
      processed++;
      // Yield to event loop between contacts to keep UI responsive
      await Future.delayed(Duration.zero);
      if (processed % 10 == 0) {
        onProgress?.call(ImportProgressInfo(
          processed: processed,
          total: total,
          created: processed,
          errors: 0,
          currentSource: rel.contact.id,
        ));
      }
    }

    onProgress?.call(ImportProgressInfo(
      processed: processed,
      total: total,
      created: processed,
      errors: 0,
      currentSource: null,
    ));

    return lines.join('\n');
  }

  @override
  Future<ImportResult> importContactsFromCsv(
    String csvContent, {
    int batchSize = 50,
    ImportProgressCallback? onProgress,
  }) async {
    final result = ImportResult();
    // Strip UTF-8 BOM if present
    final cleanContent = stripUtf8Bom(csvContent);
    final lines = cleanContent.split('\n');
    if (lines.isEmpty) return result;

    final dataLines = <List<String>>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      final fields = _parseCsvLine(line);
      if (fields.length >= 3) {
        dataLines.add(fields);
      }
    }

    result.total = dataLines.length;

    // Cargar contactos existentes UNA SOLA VEZ para detección de duplicados.
    final existingContacts = await _contactRepository.getAllContactsWithRelations();

    for (var batchStart = 0; batchStart < dataLines.length; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize).clamp(0, dataLines.length);
      final batch = dataLines.sublist(batchStart, batchEnd);

      for (final fields in batch) {
        try {
          final pc = _csvFieldsToPortableContact(fields);
          final createdId = await importPortableContact(pc, existingContacts: existingContacts);
          // Si el ID devuelto ya existía, el contacto fue omitido (duplicado),
          // no creado.
          final alreadyExists = existingContacts.any((c) => c.contact.id == createdId);
          if (alreadyExists) {
            result.skipped++;
          } else {
            result.created++;
          }

          // Agregar el contacto recién creado a existingContacts para que
          // las filas siguientes dentro del mismo batch puedan detectarlo
          // como duplicado.
          if (!alreadyExists) {
            final newContact = await _contactRepository.getContactWithRelations(createdId);
            if (newContact != null) {
              existingContacts.add(newContact);
            }
          }
        } catch (e) {
          result.errors++;
          result.errorMessages.add('CSV import error: $e');
          result.failedRecords.add(ImportedContactResult(
            success: false,
            sourceIdentifier: fields.isNotEmpty ? fields[0] : 'unknown',
            errorMessage: e.toString(),
            contactData: {'givenName': fields.length > 1 ? fields[1] : null,
                          'familyName': fields.length > 3 ? fields[3] : null},
          ));
        }

        result.processed = batchStart + (batch.indexOf(fields) + 1);
        // Yield to event loop between contacts to keep UI responsive
        await Future.delayed(Duration.zero);
        onProgress?.call(ImportProgressInfo(
          processed: result.processed,
          total: result.total,
          created: result.created,
          errors: result.errors,
          photosImported: result.photosImported,
          photosUnavailable: result.photosUnavailable,
          currentSource: fields.isNotEmpty ? fields[0] : null,
        ));
      }
    }

    return result;
  }

  /// Convierte una fila de CSV (lista de campos) en un PortableContact.
  PortableContact _csvFieldsToPortableContact(List<String> fields) {
    final givenName = fields.length > 1 && fields[1].isNotEmpty ? fields[1] : null;
    final familyName = fields.length > 3 && fields[3].isNotEmpty ? fields[3] : null;

    // Teléfonos (campo 10: JSON array)
    final phones = <PortablePhone>[];
    if (fields.length > 10 && fields[10].isNotEmpty) {
      try {
        final decoded = jsonDecode(fields[10]) as List;
        int idx = 0;
        for (final item in decoded) {
          phones.add(PortablePhone(
            id: item['id']?.toString() ?? '',
            valueRaw: item['value']?.toString() ?? '',
            label: item['label']?.toString() ?? 'mobile',
            isPrimary: item['isPrimary'] == true,
            sortOrder: item['sortOrder'] is int ? item['sortOrder'] : idx++,
          ));
        }
      } catch (_) {}
    }

    // Correos electrónicos (campo 11: JSON array)
    final emails = <PortableEmail>[];
    if (fields.length > 11 && fields[11].isNotEmpty) {
      try {
        final decoded = jsonDecode(fields[11]) as List;
        int idx = 0;
        for (final item in decoded) {
          emails.add(PortableEmail(
            id: item['id']?.toString() ?? '',
            value: item['value']?.toString() ?? '',
            label: item['label']?.toString() ?? 'home',
            isPrimary: item['isPrimary'] == true,
            sortOrder: item['sortOrder'] is int ? item['sortOrder'] : idx++,
          ));
        }
      } catch (_) {}
    }

    return PortableContact(
      id: fields.isNotEmpty && fields[0].isNotEmpty ? fields[0] : '',
      givenName: givenName,
      middleName: fields.length > 2 && fields[2].isNotEmpty ? fields[2] : null,
      familyName: familyName,
      prefix: fields.length > 4 && fields[4].isNotEmpty ? fields[4] : null,
      suffix: fields.length > 5 && fields[5].isNotEmpty ? fields[5] : null,
      nickname: fields.length > 6 && fields[6].isNotEmpty ? fields[6] : null,
      isFavorite: fields.length > 7 && fields[7] == '1',
      createdAt: fields.length > 8 && fields[8].isNotEmpty
          ? DateTime.tryParse(fields[8]) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: fields.length > 9 && fields[9].isNotEmpty
          ? DateTime.tryParse(fields[9]) ?? DateTime.now()
          : DateTime.now(),
      phones: phones,
      emails: emails,
      addresses: const [],
      socialLinks: const [],
      organizations: const [],
      dates: const [],
      notes: const [],
      customFields: const [],
    );
  }

  @override
  Future<ImportResult> importContactsFromJson(
    String jsonContent, {
    int batchSize = 50,
    ImportProgressCallback? onProgress,
  }) async {
    final result = ImportResult();
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (e) {
      result.errors++;
      result.errorMessages.add('JSON inválido: $e');
      return result;
    }

    final contacts = (decoded['contacts'] as List? ?? []);
    result.total = contacts.length;

    // Cargar contactos existentes UNA SOLA VEZ para detección de duplicados.
    final existingContacts = await _contactRepository.getAllContactsWithRelations();

    for (var batchStart = 0; batchStart < contacts.length; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize).clamp(0, contacts.length);
      final batch = contacts.sublist(batchStart, batchEnd);

      for (final c in batch) {
        try {
          final pc = PortableContact.fromJson(c as Map<String, dynamic>);
          final createdId = await importPortableContact(pc, existingContacts: existingContacts);
          // Si el ID devuelto ya existía, el contacto fue omitido (duplicado),
          // no creado.
          final alreadyExists = existingContacts.any((c) => c.contact.id == createdId);
          if (alreadyExists) {
            result.skipped++;
          } else {
            result.created++;
          }

          // Agregar el contacto recién creado a existingContacts para que
          // las tarjetas siguientes dentro del mismo batch puedan detectarlo
          // como duplicado.
          if (!alreadyExists) {
            final newContact = await _contactRepository.getContactWithRelations(createdId);
            if (newContact != null) {
              existingContacts.add(newContact);
            }
          }
        } catch (e) {
          result.errors++;
          result.errorMessages.add('JSON import error: $e');
          result.failedRecords.add(ImportedContactResult(
            success: false,
            sourceIdentifier: c['id'] ?? 'unknown',
            errorMessage: e.toString(),
            contactData: c,
          ));
        }

        result.processed = batchStart + (batch.indexOf(c) + 1);
        // Yield to event loop between contacts to keep UI responsive
        await Future.delayed(Duration.zero);
        onProgress?.call(ImportProgressInfo(
          processed: result.processed,
          total: result.total,
          created: result.created,
          errors: result.errors,
          photosImported: result.photosImported,
          photosUnavailable: result.photosUnavailable,
          currentSource: c['id']?.toString(),
        ));
      }
    }

    return result;
  }

  String _contactToCsvRow(ContactWithRelations rel) {
    String esc(String? v) {
      if (v == null) return '';
      final s = v.replaceAll('"', '""');
      return '"$s"';
    }

    final phonesJson = jsonEncode(rel.phones.map((p) => {
      'id': p.id,
      'valueRaw': p.valueRaw,
      'label': p.label,
      'isPrimary': p.isPrimary,
      'sortOrder': p.sortOrder,
    }).toList());

    final emailsJson = jsonEncode(rel.emails.map((e) => {
      'id': e.id,
      'value': e.value,
      'label': e.label,
      'isPrimary': e.isPrimary,
      'sortOrder': e.sortOrder,
    }).toList());

    final addressesJson = jsonEncode(rel.addresses.map((a) => {
      'id': a.id,
      'label': a.label,
      'street': a.street,
      'number': a.number,
      'apartment': a.apartment,
      'postalCode': a.postalCode,
      'city': a.city,
      'region': a.region,
      'country': a.country,
      'latitude': a.latitude,
      'longitude': a.longitude,
      'sortOrder': a.sortOrder,
    }).toList());

    final socialsJson = jsonEncode(rel.socialLinks.map((s) => {
      'id': s.id,
      'type': s.type,
      'value': s.value,
      'url': s.url,
      'label': s.label,
      'sortOrder': s.sortOrder,
    }).toList());

    final orgsJson = jsonEncode(rel.organizations.map((o) => {
      'id': o.id,
      'company': o.company,
      'title': o.title,
      'department': o.department,
      'website': o.website,
      'notes': o.notes,
      'isPrimary': o.isPrimary,
      'sortOrder': o.sortOrder,
    }).toList());

    final datesJson = jsonEncode(rel.dates.map((d) => {
      'id': d.id,
      'type': d.type,
      'label': d.label,
      'date': d.date.toIso8601String(),
      'yearUnknown': d.yearUnknown,
      'recurrence': d.recurrence,
      'sortOrder': d.sortOrder,
    }).toList());

    final notesJson = jsonEncode(rel.notes.map((n) => {
      'id': n.id,
      'content': n.content,
      'source': n.source,
      'createdAt': n.createdAt.toIso8601String(),
      'updatedAt': n.updatedAt.toIso8601String(),
    }).toList());

    final customsJson = jsonEncode(rel.customFields.map((c) => {
      'id': c.id,
      'name': c.name,
      'type': c.type,
      'value': c.value,
      'sortOrder': c.sortOrder,
    }).toList());

    return [
      esc(rel.contact.id),
      esc(rel.contact.givenName),
      esc(rel.contact.middleName),
      esc(rel.contact.familyName),
      esc(rel.contact.prefix),
      esc(rel.contact.suffix),
      esc(rel.contact.nickname),
      rel.contact.isFavorite ? '1' : '0',
      esc(rel.contact.createdAt.toIso8601String()),
      esc(rel.contact.updatedAt.toIso8601String()),
      esc(phonesJson),
      esc(emailsJson),
      esc(addressesJson),
      esc(socialsJson),
      esc(orgsJson),
      esc(datesJson),
      esc(notesJson),
      esc(customsJson),
      esc(rel.contact.photoPath),
      esc(rel.contact.photoHash),
      esc(rel.contact.favoriteMarkedAt?.toIso8601String()),
    ].join(',');
  }

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    var i = 0;
    while (i < line.length) {
      if (line[i] == '"') {
        i++;
        var field = '';
        while (i < line.length) {
          if (line[i] == '"') {
            if (i + 1 < line.length && line[i + 1] == '"') {
              field += '"';
              i += 2;
            } else {
              i++;
              break;
            }
          } else {
            field += line[i];
            i++;
          }
        }
        fields.add(field);
        if (i < line.length && line[i] == ',') i++;
      } else {
        var end = line.indexOf(',', i);
        if (end == -1) end = line.length;
        fields.add(line.substring(i, end));
        i = end + 1;
      }
    }
    return fields;
  }

  @override
  Future<ImportResult> importContactsFromVCard(
    String vcfContent, {
    int batchSize = 50,
    ImportProgressCallback? onProgress,
    DuplicateResolution? resolution,
  }) async {
    final result = ImportResult();
    final cards = _parseVcfCards(vcfContent);
    result.total = cards.length;

    // Cargar contactos existentes UNA SOLA VEZ para detección de duplicados.
    // Sin esto, cada contacto importado dispararía getAllContacts() (O(n²)).
    final existingContacts = await _contactRepository.getAllContactsWithRelations();

    for (var batchStart = 0; batchStart < cards.length; batchStart += batchSize) {
      final batchEnd = (batchStart + batchSize).clamp(0, cards.length);
      final batch = cards.sublist(batchStart, batchEnd);

      for (final card in batch) {
        final fn = card.get('FN') ?? 'unknown';
        try {
          final conversion = _vCardToPortableContact(card);
          result.warnings.addAll(conversion.warnings);
          result.photosImported += conversion.photosImported;
          result.photosUnavailable += conversion.photosUnavailable;
          final createdId = await importPortableContact(
            conversion.contact,
            resolution: resolution,
            warnings: result.warnings,
            existingContacts: existingContacts,
          );
          // Si el ID devuelto ya existía, el contacto fue omitido (duplicado),
          // no creado.
          final alreadyExists = existingContacts.any((c) => c.contact.id == createdId);
          if (alreadyExists) {
            result.skipped++;
          } else {
            result.created++;
          }

          // Agregar el contacto recién creado a existingContacts para que
          // las tarjetas siguientes dentro del mismo batch puedan detectarlo
          // como duplicado.
          if (!alreadyExists) {
            final newContact = await _contactRepository.getContactWithRelations(createdId);
            if (newContact != null) {
              existingContacts.add(newContact);
            }
          }
        } catch (e) {
          result.errors++;
          result.errorMessages.add('vCard import error ($fn): $e');
          result.failedRecords.add(ImportedContactResult(
            success: false,
            sourceIdentifier: fn,
            errorMessage: e.toString(),
            contactData: null,
          ));
        }

        result.processed = batchStart + (batch.indexOf(card) + 1);
        // Yield to event loop between contacts to keep UI responsive
        await Future.delayed(Duration.zero);
        onProgress?.call(ImportProgressInfo(
          processed: result.processed,
          total: result.total,
          created: result.created,
          errors: result.errors,
          photosImported: result.photosImported,
          photosUnavailable: result.photosUnavailable,
          warningsCount: result.warnings.length,
          currentSource: fn,
        ));
      }
    }

    return result;
  }

  /// Cuenta el número de tarjetas vCard (BEGIN:VCARD) en el contenido.
  ///
  /// Cada tarjeta se contabiliza una sola vez, independientemente de cuántos
  /// teléfonos, correos, fotos o propiedades contenga.
  @override
  int countVcfCards(String vcfContent) {
    int count = 0;
    for (final line in vcfContent.split('\n')) {
      if (line.trim() == 'BEGIN:VCARD') {
        count++;
      }
    }
    return count;
  }
}