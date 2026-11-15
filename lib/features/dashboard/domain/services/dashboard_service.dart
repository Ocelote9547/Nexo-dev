import 'package:nexo/database/app_database.dart';

/// Aggregated dashboard data for NEXO.
class DashboardSummary {
  final int totalContacts;
  final int favoriteContacts;
  final int recentContacts; // last 30 days
  final int upcomingBirthdays; // next 30 days
  final int totalCollections;
  final int totalTags;
  final int contactsWithoutPhoto;
  final int contactsWithoutPhone;

  DashboardSummary({
    required this.totalContacts,
    required this.favoriteContacts,
    required this.recentContacts,
    required this.upcomingBirthdays,
    required this.totalCollections,
    required this.totalTags,
    required this.contactsWithoutPhoto,
    required this.contactsWithoutPhone,
  });
}

class DashboardService {
  final AppDatabase _db;

  DashboardService(this._db);

  Future<DashboardSummary> getSummary({int recentDays = 30, int birthdayDays = 30}) async {
    final contacts = await _db.select(_db.contacts).get();
    final favorites = contacts.where((c) => c.isFavorite).length;
    final since = DateTime.now().subtract(Duration(days: recentDays));
    final recent = contacts.where((c) => c.updatedAt.isAfter(since)).length;
    final noPhoto = contacts.where((c) => c.photoPath == null).length;

    final phones = await _db.select(_db.phones).get();
    final contactsWithPhone = phones.map((p) => p.contactId).toSet();
    final noPhone = contacts.where((c) => !contactsWithPhone.contains(c.id)).length;

    final collections = await _db.select(_db.collections).get();
    final tags = await _db.select(_db.tags).get();

    // Count upcoming birthdays
    final now = DateTime.now();
    final cutoff = now.add(Duration(days: birthdayDays));
    final dates = await _db.select(_db.contactDates).get();
    int upcoming = 0;
    for (final d in dates) {
      if (d.type == 'birthday' || d.type == 'anniversary') {
        // Simple: check if month/day falls within next N days
        final thisYear = DateTime(now.year, d.date.month, d.date.day);
        final next = thisYear.isBefore(now) ? DateTime(now.year + 1, d.date.month, d.date.day) : thisYear;
        if (!next.isAfter(cutoff)) {
          upcoming++;
        }
      }
    }

    return DashboardSummary(
      totalContacts: contacts.length,
      favoriteContacts: favorites,
      recentContacts: recent,
      upcomingBirthdays: upcoming,
      totalCollections: collections.length,
      totalTags: tags.length,
      contactsWithoutPhoto: noPhoto,
      contactsWithoutPhone: noPhone,
    );
  }
}
