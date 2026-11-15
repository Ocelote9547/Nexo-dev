import 'dart:math';

import 'package:nexo/features/contacts/domain/entities/contact.dart';
import 'package:nexo/features/contacts/domain/repositories/contact_repository.dart';
import 'package:nexo/features/import_export/domain/entities/import_export.dart';
import 'package:nexo/features/import_export/domain/repositories/import_export_repository.dart';

/// Service for detecting duplicate contacts using normalization and scoring.
class DuplicateDetectionService implements DuplicateDetectionRepository {
  final ContactRepository _contactRepository;

  DuplicateDetectionService(this._contactRepository);

  static String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^0-9+]'), '');
  }

  static String _normalizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  static String _normalizeName(String? name) {
    if (name == null) return '';
    return name.trim().toLowerCase();
  }

  @override
  Future<List<DuplicateCandidate>> findDuplicates(PortableContact contact,
      {List<ContactWithRelations>? existingContacts}) async {
    final existing = existingContacts ?? await _contactRepository.getAllContactsWithRelations();
    final candidates = <DuplicateCandidate>[];

    for (final e in existing) {
      final confidence = _computeConfidence(contact, e);
      if (confidence > 0.0) {
        final reasons = <String>[];
        if (_phonesMatch(contact, e)) reasons.add('phone');
        if (_emailsMatch(contact, e)) reasons.add('email');
        if (_namesMatch(contact, e)) reasons.add('name');
        if (_orgMatch(contact, e)) reasons.add('org');

        candidates.add(DuplicateCandidate(
          nexoContactId: e.contact.id,
          nexoDisplayName: e.contact.displayName,
          confidence: confidence,
          matchReasons: reasons,
          nexoContactData: _contactToMap(e),
          incomingContactData: _portableContactToMap(contact),
        ));
      }
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates;
  }

  @override
  Future<List<DuplicateCandidate>> findDuplicatesByPhone(String phone) async {
    final normalized = _normalizePhone(phone);
    final existing = await _contactRepository.getAllContacts();
    final candidates = <DuplicateCandidate>[];

    for (final e in existing) {
      final rel = await _contactRepository.getContactWithRelations(e.id);
      if (rel == null) continue;

      for (final p in rel.phones) {
        if (_normalizePhone(p.valueRaw) == normalized) {
          candidates.add(DuplicateCandidate(
            nexoContactId: e.id,
            nexoDisplayName: e.displayName,
            confidence: 0.95,
            matchReasons: ['phone'],
            nexoContactData: _contactToMap(rel),
            incomingContactData: {'phone': phone},
          ));
          break;
        }
      }
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates;
  }

  @override
  Future<List<DuplicateCandidate>> findDuplicatesByEmail(String email) async {
    final normalized = _normalizeEmail(email);
    final existing = await _contactRepository.getAllContacts();
    final candidates = <DuplicateCandidate>[];

    for (final e in existing) {
      final rel = await _contactRepository.getContactWithRelations(e.id);
      if (rel == null) continue;

      for (final e2 in rel.emails) {
        if (_normalizeEmail(e2.value) == normalized) {
          candidates.add(DuplicateCandidate(
            nexoContactId: e.id,
            nexoDisplayName: e.displayName,
            confidence: 0.95,
            matchReasons: ['email'],
            nexoContactData: _contactToMap(rel),
            incomingContactData: {'email': email},
          ));
          break;
        }
      }
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates;
  }

  @override
  Future<List<DuplicateCandidate>> findDuplicatesByNameAndOrg({
    required String givenName,
    required String familyName,
    String? company,
  }) async {
    final existing = await _contactRepository.getAllContacts();
    final candidates = <DuplicateCandidate>[];

    for (final e in existing) {
      final rel = await _contactRepository.getContactWithRelations(e.id);
      if (rel == null) continue;

      final conf = _computeNameOrgConfidence(
        givenName, familyName, company, rel,
      );
      if (conf > 0.0) {
        candidates.add(DuplicateCandidate(
          nexoContactId: e.id,
          nexoDisplayName: e.displayName,
          confidence: conf,
          matchReasons: ['name+org'],
          nexoContactData: _contactToMap(rel),
          incomingContactData: {
            'givenName': givenName,
            'familyName': familyName,
            'company': company,
          },
        ));
      }
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates;
  }

  double _computeConfidence(PortableContact incoming, ContactWithRelations existing) {
    double score = 0.0;

    final phoneMatch = _phonesMatch(incoming, existing);
    final emailMatch = _emailsMatch(incoming, existing);

    // Coincidencia de correo electrónico exacto: es suficiente para considerar
    // duplicado fuerte cuando el correo es único en la base de datos.
    if (emailMatch) score = max(score, 0.8);

    // Teléfono por sí solo NO es coincidencia fuerte.
    if (phoneMatch) score = max(score, 0.6);

    // Teléfono + correo juntos son evidencia muy fuerte.
    if (phoneMatch && emailMatch) score = 0.95;

    final nameMatch = _namesMatch(incoming, existing);
    if (nameMatch) score += 0.2;

    if (_orgMatch(incoming, existing)) score += 0.1;

    return min(score, 1.0);
  }

  double _computeNameOrgConfidence(
    String givenName,
    String familyName,
    String? company,
    ContactWithRelations existing,
  ) {
    double score = 0.0;

    final existingGiven = _normalizeName(existing.contact.givenName);
    final existingFamily = _normalizeName(existing.contact.familyName);
    final normGiven = _normalizeName(givenName);
    final normFamily = _normalizeName(familyName);

    if (existingGiven == normGiven && existingGiven.isNotEmpty) score += 0.3;
    if (existingFamily == normFamily && existingFamily.isNotEmpty) score += 0.3;

    if (company != null && company.isNotEmpty) {
      for (final o in existing.organizations) {
        if (_normalizeName(o.company) == _normalizeName(company)) {
          score += 0.2;
          break;
        }
      }
    }

    if (existingGiven.contains(normGiven) && normGiven.isNotEmpty) score += 0.1;
    if (existingFamily.contains(normFamily) && normFamily.isNotEmpty) score += 0.1;

    return min(score, 1.0);
  }

  bool _phonesMatch(PortableContact incoming, ContactWithRelations existing) {
    for (final p1 in incoming.phones) {
      final n1 = _normalizePhone(p1.valueRaw);
      if (n1.isEmpty) continue;
      for (final p2 in existing.phones) {
        if (_normalizePhone(p2.valueRaw) == n1) return true;
      }
    }
    return false;
  }

  bool _emailsMatch(PortableContact incoming, ContactWithRelations existing) {
    for (final e1 in incoming.emails) {
      final n1 = _normalizeEmail(e1.value);
      if (n1.isEmpty) continue;
      for (final e2 in existing.emails) {
        if (_normalizeEmail(e2.value) == n1) return true;
      }
    }
    return false;
  }

  bool _namesMatch(PortableContact incoming, ContactWithRelations existing) {
    final incGiven = _normalizeName(incoming.givenName);
    final incFamily = _normalizeName(incoming.familyName);
    final excGiven = _normalizeName(existing.contact.givenName);
    final excFamily = _normalizeName(existing.contact.familyName);

    // Ambos tienen nombre y apellido: deben coincidir ambos
    if (incGiven.isNotEmpty && incFamily.isNotEmpty &&
        excGiven.isNotEmpty && excFamily.isNotEmpty) {
      return incGiven == excGiven && incFamily == excFamily;
    }

    // NUEVO: Uno tiene nombre completo en givenName, otro tiene nombre y apellido separados.
    // Ejemplo: VCF con FN='Ana García' → givenName='Ana García', familyName=null.
    //          Contacto creado manualmente → givenName='Ana', familyName='García'.
    final incFull = _normalizeName('$incGiven $incFamily'.trim());
    final excFull = _normalizeName('$excGiven $excFamily'.trim());
    if (incFull.isNotEmpty && excFull.isNotEmpty && incFull == excFull) {
      return true;
    }

    // Solo se tiene nombre en ambos lados (y ninguno tiene apellido): debe coincidir el nombre
    if (incGiven.isNotEmpty && incFamily.isEmpty &&
        excGiven.isNotEmpty && excFamily.isEmpty) {
      return incGiven == excGiven;
    }
    // Solo se tiene apellido en ambos lados (y ninguno tiene nombre): debe coincidir el apellido
    if (incFamily.isNotEmpty && incGiven.isEmpty &&
        excFamily.isNotEmpty && excGiven.isEmpty) {
      return incFamily == excFamily;
    }
    // Combinaciones mixtas (uno tiene nombre, otro apellido, o uno tiene ambos y otro tiene solo uno):
    // no son necesariamente el mismo contacto
    return false;
  }

  bool _orgMatch(PortableContact incoming, ContactWithRelations existing) {
    for (final o1 in incoming.organizations) {
      final c1 = _normalizeName(o1.company);
      if (c1.isEmpty) continue;
      for (final o2 in existing.organizations) {
        if (_normalizeName(o2.company) == c1) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> _contactToMap(ContactWithRelations rel) {
    return {
      'id': rel.contact.id,
      'givenName': rel.contact.givenName,
      'familyName': rel.contact.familyName,
      'displayName': rel.contact.displayName,
      'phones': rel.phones.map((p) => p.valueRaw).toList(),
      'emails': rel.emails.map((e) => e.value).toList(),
      'organizations': rel.organizations.map((o) => o.company).toList(),
    };
  }

  Map<String, dynamic> _portableContactToMap(PortableContact contact) {
    return {
      'id': contact.id,
      'givenName': contact.givenName,
      'familyName': contact.familyName,
      'displayName': [
        contact.givenName,
        contact.middleName,
        contact.familyName,
      ].where((e) => e != null && e.trim().isNotEmpty).join(' '),
      'phones': contact.phones.map((p) => p.valueRaw).toList(),
      'emails': contact.emails.map((e) => e.value).toList(),
      'organizations': contact.organizations.map((o) => o.company).toList(),
    };
  }
}
