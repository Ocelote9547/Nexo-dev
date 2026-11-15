import '../entities/contact.dart';

abstract class ContactRepository {
  Future<Contact> createContact(
    Contact contact, {
    List<Phone> phones = const [],
    List<Email> emails = const [],
    List<Address> addresses = const [],
    List<SocialLink> socialLinks = const [],
    List<Organization> organizations = const [],
    List<ContactDate> dates = const [],
    List<Note> notes = const [],
    List<CustomField> customFields = const [],
  });

  Future<Contact> updateContact(
    Contact contact, {
    List<Phone>? phones,
    List<Email>? emails,
    List<Address>? addresses,
    List<SocialLink>? socialLinks,
    List<Organization>? organizations,
    List<ContactDate>? dates,
    List<Note>? notes,
    List<CustomField>? customFields,
  });

  Future<void> deleteContact(String id);

  Future<Contact> duplicateContact(String id);

  Future<Contact?> getContactById(String id);

  Future<ContactWithRelations?> getContactWithRelations(String id);

  Future<List<Contact>> getAllContacts();

  Future<List<ContactWithRelations>> getAllContactsWithRelations();

  Stream<List<Contact>> watchContacts();

  Stream<Contact?> watchContactById(String id);

  Future<List<Contact>> getRecentContacts({int days = 30, int limit = 20});

  Future<void> toggleFavorite(String id, bool value);

  // Children CRUD
  Future<Phone> addPhone(Phone phone);
  Future<void> updatePhone(Phone phone);
  Future<void> deletePhone(String id);
  Future<void> setPrimaryPhone(String contactId, String phoneId);

  Future<Email> addEmail(Email email);
  Future<void> updateEmail(Email email);
  Future<void> deleteEmail(String id);
  Future<void> setPrimaryEmail(String contactId, String emailId);

  Future<Organization> addOrganization(Organization org);
  Future<void> updateOrganization(Organization org);
  Future<void> deleteOrganization(String id);
  Future<void> setPrimaryOrganization(String contactId, String orgId);

  Future<Address> addAddress(Address address);
  Future<void> updateAddress(Address address);
  Future<void> deleteAddress(String id);

  Future<SocialLink> addSocialLink(SocialLink link);
  Future<void> updateSocialLink(SocialLink link);
  Future<void> deleteSocialLink(String id);

  Future<Note> addNote(Note note);
  Future<void> updateNote(Note note);
  Future<void> deleteNote(String id);

  Future<CustomField> addCustomField(CustomField field);
  Future<void> updateCustomField(CustomField field);
  Future<void> deleteCustomField(String id);

  Future<ContactDate> addContactDate(ContactDate date);
  Future<void> updateContactDate(ContactDate date);
  Future<void> deleteContactDate(String id);

  Future<List<ContactDate>> getContactDates(String contactId);
  Future<List<ContactDate>> getContactDatesByMonthDay(int month, int day);

  Future<void> updateContactPhotoPath(String contactId, String photoPath);
}
