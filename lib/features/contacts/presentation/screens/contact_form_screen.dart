import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/media_provider.dart';
import '../../../../core/theme/nexo_theme.dart';
import '../../../../shared/widgets/nexo_widgets.dart';
import '../../domain/entities/contact.dart';
import '../providers/contact_providers.dart';
import '../../../tags/presentation/providers/tag_providers.dart';
import '../../../collections/presentation/providers/collection_providers.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../../services/notifications/notification_providers.dart';

class ContactFormScreen extends ConsumerStatefulWidget {
  final String? contactId;
  const ContactFormScreen({super.key, this.contactId});

  @override
  ConsumerState<ContactFormScreen> createState() => _ContactFormScreenState();
}

class _ContactFormScreenState extends ConsumerState<ContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  String? _photoPath;
  String? _photoHash;
  bool _isFavorite = false;
  DateTime? _favoriteMarkedAt;

  final _givenName = TextEditingController();
  final _middleName = TextEditingController();
  final _familyName = TextEditingController();
  final _prefix = TextEditingController();
  final _suffix = TextEditingController();
  final _nickname = TextEditingController();

  List<Phone> _phones = [];
  List<Email> _emails = [];
  List<Address> _addresses = [];
  List<Organization> _organizations = [];
  List<SocialLink> _socialLinks = [];
  List<Note> _notes = [];
  List<CustomField> _customFields = [];
  List<ContactDate> _dates = [];

  Set<String> _selectedTagIds = {};
  Set<String> _selectedCollectionIds = {};

  bool get _isEditing => widget.contactId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_isEditing) {
      final repo = ref.read(contactRepositoryProvider);
      final cwr = await repo.getContactWithRelations(widget.contactId!);
      if (cwr != null) {
        final c = cwr.contact;
        _givenName.text = c.givenName ?? '';
        _middleName.text = c.middleName ?? '';
        _familyName.text = c.familyName ?? '';
        _prefix.text = c.prefix ?? '';
        _suffix.text = c.suffix ?? '';
        _nickname.text = c.nickname ?? '';
        _photoPath = c.photoPath;
        _photoHash = c.photoHash;
        _isFavorite = c.isFavorite;
        _favoriteMarkedAt = c.favoriteMarkedAt;
        _phones = List.of(cwr.phones);
        _emails = List.of(cwr.emails);
        _addresses = List.of(cwr.addresses);
        _organizations = List.of(cwr.organizations);
        _socialLinks = List.of(cwr.socialLinks);
        _notes = List.of(cwr.notes);
        _customFields = List.of(cwr.customFields);
        _dates = List.of(cwr.dates);
        final tagRepo = ref.read(tagRepositoryProvider);
        final collRepo = ref.read(collectionRepositoryProvider);
        _selectedTagIds = (await tagRepo.getTagIdsForContact(widget.contactId!)).toSet();
        _selectedCollectionIds = (await collRepo.getCollectionIdsForContact(widget.contactId!)).toSet();
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _givenName.dispose();
    _middleName.dispose();
    _familyName.dispose();
    _prefix.dispose();
    _suffix.dispose();
    _nickname.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await FilePicker.pickFiles(type: FileType.image);
    if (picked.isEmpty) return;
    final path = picked.single.path;
    if (path == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar fotografía',
          toolbarColor: const Color(0xFF1A1F26),
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: const Color(0xFF4F8CFF),
          backgroundColor: const Color(0xFF0B0F14),
          statusBarLight: false,
        ),
      ],
    );
    if (cropped == null) return;
    final bytes = await cropped.readAsBytes();
    final media = ref.read(mediaServiceProvider);
    final contactId = widget.contactId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final rel = await media.savePhoto(contactId, bytes);
    final hash = media.sha256Of(bytes);
    if (mounted) {
      setState(() {
        _photoPath = rel;
        _photoHash = hash;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_givenName.text.trim().isEmpty && _familyName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Se requiere nombre o apellido')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(contactRepositoryProvider);
      final contact = Contact(
        id: widget.contactId,
        givenName: _givenName.text.trim().isEmpty ? null : _givenName.text.trim(),
        middleName: _middleName.text.trim().isEmpty ? null : _middleName.text.trim(),
        familyName: _familyName.text.trim().isEmpty ? null : _familyName.text.trim(),
        prefix: _prefix.text.trim().isEmpty ? null : _prefix.text.trim(),
        suffix: _suffix.text.trim().isEmpty ? null : _suffix.text.trim(),
        nickname: _nickname.text.trim().isEmpty ? null : _nickname.text.trim(),
        photoPath: _photoPath,
        photoHash: _photoHash,
        isFavorite: _isFavorite,
        favoriteMarkedAt: _favoriteMarkedAt,
      );

      String savedId;
      if (_isEditing) {
        await repo.updateContact(
          contact,
          phones: _phones,
          emails: _emails,
          addresses: _addresses,
          socialLinks: _socialLinks,
          organizations: _organizations,
          dates: _dates,
          notes: _notes,
          customFields: _customFields,
        );
        savedId = contact.id;
      } else {
        final created = await repo.createContact(
          contact,
          phones: _phones,
          emails: _emails,
          addresses: _addresses,
          socialLinks: _socialLinks,
          organizations: _organizations,
          dates: _dates,
          notes: _notes,
          customFields: _customFields,
        );
        savedId = created.id;
      }

      final tagRepo = ref.read(tagRepositoryProvider);
      final collRepo = ref.read(collectionRepositoryProvider);
      final existingTags = _isEditing ? await tagRepo.getTagIdsForContact(savedId) : <String>[];
      for (final t in existingTags) {
        if (!_selectedTagIds.contains(t)) await tagRepo.removeTagFromContact(t, savedId);
      }
      for (final t in _selectedTagIds) {
        await tagRepo.addTagToContact(t, savedId);
      }
      final existingCols = _isEditing ? await collRepo.getCollectionIdsForContact(savedId) : <String>[];
      for (final c in existingCols) {
        if (!_selectedCollectionIds.contains(c)) await collRepo.removeContactFromCollection(c, savedId);
      }
      for (final c in _selectedCollectionIds) {
        await collRepo.addContactToCollection(c, savedId);
      }

      // Notificaciones de cumpleaños
      try {
        final notif = ref.read(notificationServiceProvider);
        final settings = ref.read(settingsRepositoryProvider);
        final globalOn = await settings.getBool('birthday_notifications', defaultValue: true);
        final globalAdvance = await settings.getInt('birthday_advance_days', defaultValue: 0);
        final sound = await settings.getBool('birthday_sound', defaultValue: true);
        final contactName = contact.displayName;
        for (final d in _dates) {
          if (d.type != 'birthday') continue;
          final indivEnabled = await settings.getBool(
            'birthday_indiv_enabled_${d.id}',
            defaultValue: true,
          );
          if (!globalOn || !indivEnabled) {
            await notif.cancelBirthdayNotifications(d.id);
            continue;
          }
          final indivAdvance = await settings.getInt(
            'birthday_indiv_advance_${d.id}',
            defaultValue: -1,
          );
          final effAdvance = indivAdvance >= 0 ? indivAdvance : globalAdvance;
          await notif.scheduleBirthdayNotifications(
            dateId: d.id,
            contactName: contactName,
            month: d.date.month,
            day: d.date.day,
            advanceDays: effAdvance,
            sound: sound,
          );
        }
      } catch (_) {
        // No falla el guardado si la programación de avisos falla.
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Contacto actualizado' : 'Contacto creado')),
        );
        // Invalidar el proveedor de contactos con relaciones para que el detalle
        // se reconstruya con los datos actualizados al volver a la pantalla de detalle.
        ref.invalidate(contactWithRelationsProvider(widget.contactId ?? ''));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _addPhone() {
    setState(() {
      _phones = [..._phones, Phone(contactId: widget.contactId ?? '', valueRaw: '')];
    });
  }

  void _removePhone(int index) {
    setState(() {
      _phones = [..._phones]..removeAt(index);
    });
  }

  void _addEmail() {
    setState(() {
      _emails = [..._emails, Email(contactId: widget.contactId ?? '', value: '')];
    });
  }

  void _removeEmail(int index) {
    setState(() {
      _emails = [..._emails]..removeAt(index);
    });
  }

  void _addNote() {
    setState(() {
      _notes = [..._notes, Note(contactId: widget.contactId ?? '', content: '')];
    });
  }

  void _removeNote(int index) {
    setState(() {
      _notes = [..._notes]..removeAt(index);
    });
  }

  void _addAddress() {
    setState(() {
      _addresses = [..._addresses, Address(contactId: widget.contactId ?? '', street: '')];
    });
  }

  void _removeAddress(int index) {
    setState(() {
      _addresses = [..._addresses]..removeAt(index);
    });
  }

  void _addOrganization() {
    setState(() {
      _organizations = [..._organizations, Organization(contactId: widget.contactId ?? '', company: '')];
    });
  }

  void _removeOrganization(int index) {
    setState(() {
      _organizations = [..._organizations]..removeAt(index);
    });
  }

  void _addSocialLink() {
    setState(() {
      _socialLinks = [..._socialLinks, SocialLink(contactId: widget.contactId ?? '', type: 'Website', value: '')];
    });
  }

  void _removeSocialLink(int index) {
    setState(() {
      _socialLinks = [..._socialLinks]..removeAt(index);
    });
  }

  void _addCustomField() {
    setState(() {
      _customFields = [..._customFields, CustomField(contactId: widget.contactId ?? '', name: '', value: '')];
    });
  }

  void _removeCustomField(int index) {
    setState(() {
      _customFields = [..._customFields]..removeAt(index);
    });
  }

  void _addDate() {
    setState(() {
      _dates = [..._dates, ContactDate(contactId: widget.contactId ?? '', date: DateTime.now())];
    });
  }

  void _removeDate(int index) {
    setState(() {
      _dates = [..._dates]..removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: NexoLoading());
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        toolbarHeight: 64,
        title: Text(_isEditing ? 'Editar contacto' : 'Nuevo contacto'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: Theme(
        data: Theme.of(context).copyWith(
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.48),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
                width: 1.5,
              ),
            ),
          ),
        ),
        child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 42),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 21),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.11),
                    Theme.of(context).colorScheme.surfaceContainerLow,
                  ],
                ),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.account_circle_outlined,
                        color: Theme.of(context).colorScheme.primary, size: 20),
                      const SizedBox(width: 9),
                      Text(
                        'Perfil del contacto',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: GestureDetector(
                      onTap: _pickPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.55),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                              blurRadius: 18,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            NexoAvatar(
                              displayName: _givenName.text.isEmpty ? '?' : _givenName.text,
                              size: 88,
                              photoPath: _photoPath,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 31,
                                height: 31,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.surface,
                                    width: 2.5,
                                  ),
                                ),
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _photoPath == null ? 'Toca la cámara para añadir una foto' : 'Foto del contacto',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_photoPath != null)
                    TextButton.icon(
                      onPressed: () => setState(() {
                        _photoPath = null;
                        _photoHash = null;
                      }),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Eliminar foto'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: NexoSpacing.xl),
            Text(
              'INFORMACIÓN PRINCIPAL',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: NexoSpacing.md),
            Text('Nombre', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: NexoSpacing.md),
            TextField(controller: _givenName, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: NexoSpacing.sm),
            TextField(controller: _familyName, decoration: const InputDecoration(labelText: 'Apellidos')),
            const SizedBox(height: NexoSpacing.md),
            ExpansionTile(
              title: const Text('Detalles del nombre'),
              children: [
                TextField(controller: _prefix, decoration: const InputDecoration(labelText: 'Prefijo')),
                const SizedBox(height: NexoSpacing.sm),
                TextField(controller: _middleName, decoration: const InputDecoration(labelText: 'Segundo nombre')),
                const SizedBox(height: NexoSpacing.sm),
                TextField(controller: _suffix, decoration: const InputDecoration(labelText: 'Sufijo')),
                const SizedBox(height: NexoSpacing.sm),
                TextField(controller: _nickname, decoration: const InputDecoration(labelText: 'Apodo')),
                const SizedBox(height: NexoSpacing.sm),
              ],
            ),
            const SizedBox(height: NexoSpacing.lg),
            _SectionHeader(title: 'Teléfonos', onAdd: _addPhone),
            ..._phones.asMap().entries.map((e) => _PhoneRow(
              phone: e.value,
              onChanged: (p) => _phones[e.key] = p,
              onRemove: () => _removePhone(e.key),
            )),
            const SizedBox(height: NexoSpacing.lg),
            _SectionHeader(title: 'Correos', onAdd: _addEmail),
            ..._emails.asMap().entries.map((e) => _EmailRow(
              email: e.value,
              onChanged: (em) => _emails[e.key] = em,
              onRemove: () => _removeEmail(e.key),
            )),
            const SizedBox(height: NexoSpacing.lg),
            _SectionHeader(title: 'Direcciones', onAdd: _addAddress),
            ..._addresses.asMap().entries.map((e) => _AddressRow(
              address: e.value,
              onChanged: (a) => _addresses[e.key] = a,
              onRemove: () => _removeAddress(e.key),
            )),
            const SizedBox(height: NexoSpacing.xl),
            _SectionHeader(title: 'Organizaciones', onAdd: _addOrganization),
            ..._organizations.asMap().entries.map((e) => _OrganizationRow(
              organization: e.value,
              onChanged: (o) => _organizations[e.key] = o,
              onRemove: () => _removeOrganization(e.key),
            )),
            const SizedBox(height: NexoSpacing.xl),
            _SectionHeader(title: 'Redes sociales', onAdd: _addSocialLink),
            ..._socialLinks.asMap().entries.map((e) => _SocialRow(
              link: e.value,
              onChanged: (s) => setState(() => _socialLinks[e.key] = s),
              onRemove: () => _removeSocialLink(e.key),
            )),
            const SizedBox(height: NexoSpacing.xl),
            _SectionHeader(title: 'Fechas importantes', onAdd: _addDate),
            ..._dates.asMap().entries.map((e) => _DateRow(
              date: e.value,
              onChanged: (d) => setState(() => _dates[e.key] = d),
              onRemove: () => _removeDate(e.key),
            )),
            const SizedBox(height: NexoSpacing.xl),
            _SectionHeader(title: 'Notas', onAdd: _addNote),
            ..._notes.asMap().entries.map((e) => _NoteRow(
              note: e.value,
              onChanged: (n) => _notes[e.key] = n,
              onRemove: () => _removeNote(e.key),
            )),
            const SizedBox(height: NexoSpacing.xl),
            _SectionHeader(title: 'Campos personalizados', onAdd: _addCustomField),
            ..._customFields.asMap().entries.map((e) => _CustomFieldRow(
              field: e.value,
              onChanged: (f) => _customFields[e.key] = f,
              onRemove: () => _removeCustomField(e.key),
            )),
            const SizedBox(height: NexoSpacing.xl),
            Row(
              children: [
                Icon(Icons.sell_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 9),
                Text(
                  'Etiquetas',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: NexoSpacing.sm),
            ref.watch(tagsListProvider).when(
              data: (tags) => Column(
                children: tags.map((t) {
                  final id = t['id'] as String;
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(t['name'] as String),
                    value: _selectedTagIds.contains(id),
                    onChanged: (v) => setState(() {
                      if (v == true) { _selectedTagIds.add(id); } else { _selectedTagIds.remove(id); }
                    }),
                  );
                }).toList(),
              ),
              loading: () => const NexoLoading(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: NexoSpacing.xl),
            Row(
              children: [
                Icon(Icons.folder_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 9),
                Text(
                  'Colecciones',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: NexoSpacing.sm),
            ref.watch(collectionsListProvider).when(
              data: (cols) => Column(
                children: cols.map((c) {
                  final id = c['id'] as String;
                  return CheckboxListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    title: Text(c['name'] as String),
                    value: _selectedCollectionIds.contains(id),
                    onChanged: (v) => setState(() {
                      if (v == true) { _selectedCollectionIds.add(id); } else { _selectedCollectionIds.remove(id); }
                    }),
                  );
                }).toList(),
              ),
              loading: () => const NexoLoading(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: NexoSpacing.xxl),
          ],
        ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 7, 8, 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          TextButton.icon(onPressed: onAdd, icon: const Icon(Icons.add, size: 18), label: const Text('Añadir')),
        ],
      ),
    );
  }
}

class _PhoneRow extends StatelessWidget {
  final Phone phone;
  final ValueChanged<Phone> onChanged;
  final VoidCallback onRemove;
  const _PhoneRow({required this.phone, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: phone.valueRaw,
              decoration: const InputDecoration(labelText: 'Número'),
              onChanged: (v) => onChanged(phone.copyWith(valueRaw: v)),
            ),
          ),
          const SizedBox(width: NexoSpacing.sm),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

class _EmailRow extends StatelessWidget {
  final Email email;
  final ValueChanged<Email> onChanged;
  final VoidCallback onRemove;
  const _EmailRow({required this.email, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: email.value,
              decoration: const InputDecoration(labelText: 'Correo'),
              onChanged: (v) => onChanged(email.copyWith(value: v)),
            ),
          ),
          const SizedBox(width: NexoSpacing.sm),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final Note note;
  final ValueChanged<Note> onChanged;
  final VoidCallback onRemove;
  const _NoteRow({required this.note, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: note.content,
              decoration: const InputDecoration(labelText: 'Nota'),
              onChanged: (v) => onChanged(note.copyWith(content: v)),
              maxLines: 3,
            ),
          ),
          const SizedBox(width: NexoSpacing.sm),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

class _AddressRow extends StatefulWidget {
  final Address address;
  final ValueChanged<Address> onChanged;
  final VoidCallback onRemove;

  const _AddressRow({
    required this.address,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<_AddressRow> createState() => _AddressRowState();
}

class _AddressRowState extends State<_AddressRow> {
  static final Map<String, List<_AddressSuggestion>> _cache = {};
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<_AddressSuggestion> _suggestions = [];
  bool _searching = false;
  bool _searched = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.text = _formatAddress(widget.address);
  }

  String _formatAddress(Address address) {
    final street = [
      address.street,
      if ((address.number ?? '').trim().isNotEmpty) address.number,
      if ((address.apartment ?? '').trim().isNotEmpty) address.apartment,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');
    return [
      street,
      address.postalCode,
      address.city,
      address.region,
      address.country,
    ].whereType<String>().where((part) => part.trim().isNotEmpty).join(', ');
  }

  void _onQueryChanged(String value) {
    _query = value.trim();
    widget.onChanged(Address(
      id: widget.address.id,
      contactId: widget.address.contactId,
      label: widget.address.label,
      street: value.trim(),
      sortOrder: widget.address.sortOrder,
    ));
    _debounce?.cancel();
    if (_query.length < 4) {
      setState(() {
        _suggestions = [];
        _searching = false;
        _searched = false;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 1100), _search);
  }

  Future<void> _search() async {
    final query = _query;
    if (query.length < 4 || !mounted) return;
    final key = query.toLowerCase();
    final cached = _cache[key];
    if (cached != null) {
      if (mounted && query == _query) {
        setState(() {
          _suggestions = cached;
          _searching = false;
          _searched = true;
        });
      }
      return;
    }

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 7)
        ..userAgent = 'NEXO/1.2 (https://github.com/Ocelote9547/Nexo-dev)';
      final uri = Uri.https('photon.komoot.io', '/api/', {
        'q': query,
        'limit': '5',
        'lang': 'es',
      });
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 8));
      final response = await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Photon HTTP ${response.statusCode}');
      }
      final body = await response.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final features = decoded['features'] as List<dynamic>? ?? [];
      final results = features.map((feature) {
        final item = feature as Map<String, dynamic>;
        final properties = item['properties'] as Map<String, dynamic>? ?? {};
        final geometry = item['geometry'] as Map<String, dynamic>? ?? {};
        final coordinates = geometry['coordinates'] as List<dynamic>? ?? [];
        return _AddressSuggestion(
          name: (properties['name'] ?? '').toString(),
          street: (properties['street'] ?? '').toString(),
          number: (properties['housenumber'] ?? '').toString(),
          postalCode: (properties['postcode'] ?? '').toString(),
          city: (properties['city'] ?? properties['locality'] ?? properties['district'] ?? '').toString(),
          region: (properties['state'] ?? '').toString(),
          country: (properties['country'] ?? '').toString(),
          latitude: coordinates.length > 1 ? (coordinates[1] as num).toDouble() : null,
          longitude: coordinates.isNotEmpty ? (coordinates[0] as num).toDouble() : null,
        );
      }).where((item) => item.display.isNotEmpty).toList();
      _cache[key] = results;
      if (mounted && query == _query) {
        setState(() {
          _suggestions = results;
          _searching = false;
          _searched = true;
        });
      }
    } catch (_) {
      if (mounted && query == _query) {
        setState(() {
          _suggestions = [];
          _searching = false;
          _searched = true;
        });
      }
    } finally {
      client?.close(force: true);
    }
  }

  void _selectSuggestion(_AddressSuggestion suggestion) {
    final street = suggestion.street.isNotEmpty
        ? suggestion.street
        : suggestion.name;
    final address = Address(
      id: widget.address.id,
      contactId: widget.address.contactId,
      label: widget.address.label,
      street: street,
      number: suggestion.number.isEmpty ? null : suggestion.number,
      postalCode: suggestion.postalCode.isEmpty ? null : suggestion.postalCode,
      city: suggestion.city.isEmpty ? null : suggestion.city,
      region: suggestion.region.isEmpty ? null : suggestion.region,
      country: suggestion.country.isEmpty ? null : suggestion.country,
      latitude: suggestion.latitude,
      longitude: suggestion.longitude,
      sortOrder: widget.address.sortOrder,
    );
    _controller.text = suggestion.display;
    widget.onChanged(address);
    FocusScope.of(context).unfocus();
    setState(() => _suggestions = []);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Buscar dirección',
              hintText: 'Número, calle, localidad y país',
              prefixIcon: const Icon(Icons.location_on_outlined),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Eliminar dirección',
                    onPressed: widget.onRemove,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
            onChanged: _onQueryChanged,
            onSubmitted: (_) {
              _debounce?.cancel();
              _search();
            },
          ),
          if (_suggestions.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Column(
                children: [
                  for (var i = 0; i < _suggestions.length; i++)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(_suggestions[i].display, maxLines: 2, overflow: TextOverflow.ellipsis),
                      onTap: () => _selectSuggestion(_suggestions[i]),
                    ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(12, 0, 12, 9),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Resultados de Photon · © OpenStreetMap contributors',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_searched && _suggestions.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                'No se encontraron coincidencias. Puedes modificar la búsqueda o guardarla como texto manual.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Selecciona un resultado para asociar la dirección a una ubicación reconocida. También puedes guardarla manualmente. La búsqueda envía el texto al servicio de mapas.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: NexoSpacing.md),
        ],
      ),
    );
  }
}

class _AddressSuggestion {
  final String name;
  final String street;
  final String number;
  final String postalCode;
  final String city;
  final String region;
  final String country;
  final double? latitude;
  final double? longitude;

  const _AddressSuggestion({
    required this.name,
    required this.street,
    required this.number,
    required this.postalCode,
    required this.city,
    required this.region,
    required this.country,
    required this.latitude,
    required this.longitude,
  });

  String get display {
    final streetLine = [
      if (number.isNotEmpty) number,
      if (street.isNotEmpty) street else name,
    ].join(' ');
    return [
      streetLine,
      postalCode,
      city,
      region,
      country,
    ].where((part) => part.trim().isNotEmpty).join(', ');
  }
}

class _OrganizationRow extends StatelessWidget {
  final Organization organization;
  final ValueChanged<Organization> onChanged;
  final VoidCallback onRemove;
  const _OrganizationRow({required this.organization, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        children: [
          Expanded(child: TextFormField(initialValue: organization.company, decoration: const InputDecoration(labelText: 'Empresa'), onChanged: (v) => onChanged(organization.copyWith(company: v)))),
          const SizedBox(width: NexoSpacing.sm),
          Expanded(child: TextFormField(initialValue: organization.title, decoration: const InputDecoration(labelText: 'Puesto'), onChanged: (v) => onChanged(organization.copyWith(title: v)))),
          const SizedBox(width: NexoSpacing.sm),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  final SocialLink link;
  final ValueChanged<SocialLink> onChanged;
  final VoidCallback onRemove;

  const _SocialRow({
    required this.link,
    required this.onChanged,
    required this.onRemove,
  });

  static const _platforms = [
    'Instagram', 'Facebook', 'TikTok', 'X', 'LinkedIn', 'YouTube',
    'Telegram', 'WhatsApp', 'Discord', 'Twitch', 'GitHub', 'Website', 'Otro',
  ];

  String get _selectedPlatform {
    final value = link.type.toLowerCase();
    for (final platform in _platforms) {
      if (platform.toLowerCase() == value || (value == 'web' && platform == 'Website')) return platform;
    }
    return 'Otro';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPlatform,
                  decoration: const InputDecoration(labelText: 'Plataforma'),
                  items: _platforms.map((platform) => DropdownMenuItem(
                    value: platform,
                    child: Text(platform),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) onChanged(link.copyWith(type: value));
                  },
                ),
              ),
              IconButton(
                tooltip: 'Eliminar enlace',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: NexoSpacing.sm),
          TextFormField(
            key: ValueKey('social-url-${link.id}'),
            initialValue: link.url ?? link.value,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL o perfil',
              hintText: 'https://...',
              prefixIcon: Icon(Icons.link),
            ),
            onChanged: (value) {
              final raw = value.trim();
              final parsed = Uri.tryParse(raw);
              final platformHosts = <String, String>{
                'instagram': 'instagram.com/',
                'facebook': 'facebook.com/',
                'tiktok': 'tiktok.com/@',
                'x': 'x.com/',
                'linkedin': 'linkedin.com/in/',
                'youtube': 'youtube.com/@',
                'telegram': 't.me/',
                'twitch': 'twitch.tv/',
                'github': 'github.com/',
                'whatsapp': 'wa.me/',
              };
              final host = platformHosts[link.type.toLowerCase()];
              final handle = raw.startsWith('@') ? raw.substring(1) : raw;
              final target = raw.isEmpty
                  ? raw
                  : (parsed != null && parsed.hasScheme)
                      ? raw
                      : raw.contains('.')
                          ? 'https://$raw'
                          : host != null
                              ? 'https://$host$handle'
                              : raw;
              onChanged(link.copyWith(url: target, value: raw));
            },
          ),
          const SizedBox(height: NexoSpacing.sm),
          TextFormField(
            key: ValueKey('social-label-${link.id}'),
            initialValue: link.label ?? '',
            decoration: const InputDecoration(
              labelText: 'Etiqueta (opcional)',
              hintText: 'Ej. Trabajo, personal, portfolio',
              prefixIcon: Icon(Icons.label_outline),
            ),
            onChanged: (value) => onChanged(link.copyWith(label: value)),
          ),
        ],
      ),
    );
  }
}

class _CustomFieldRow extends StatelessWidget {
  final CustomField field;
  final ValueChanged<CustomField> onChanged;
  final VoidCallback onRemove;
  const _CustomFieldRow({required this.field, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        children: [
          Expanded(child: TextFormField(initialValue: field.name, decoration: const InputDecoration(labelText: 'Nombre'), onChanged: (v) => onChanged(field.copyWith(name: v)))),
          const SizedBox(width: NexoSpacing.sm),
          Expanded(child: TextFormField(initialValue: field.value, decoration: const InputDecoration(labelText: 'Valor'), onChanged: (v) => onChanged(field.copyWith(value: v)))),
          const SizedBox(width: NexoSpacing.sm),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  final ContactDate date;
  final ValueChanged<ContactDate> onChanged;
  final VoidCallback onRemove;
  const _DateRow({required this.date, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NexoSpacing.sm),
      child: Row(
        children: [
          Expanded(child: TextFormField(initialValue: date.label ?? date.type, decoration: const InputDecoration(labelText: 'Etiqueta'), onChanged: (v) => onChanged(date.copyWith(label: v)))),
          const SizedBox(width: NexoSpacing.sm),
          Expanded(child: InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: date.date,
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(date.copyWith(date: picked));
            },
            child: Text(date.displayDate, style: Theme.of(context).textTheme.bodyMedium),
          )),
          const SizedBox(width: NexoSpacing.sm),
          IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
        ],
      ),
    );
  }
}