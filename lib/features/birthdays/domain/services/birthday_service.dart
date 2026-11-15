import 'package:nexo/database/app_database.dart' as db;
import 'package:nexo/features/contacts/domain/entities/contact.dart' as ce;

/// A computed upcoming date for a contact.
class UpcomingDate {
  final String contactId;
  final String? contactName;
  final String type;
  final String? label;
  final DateTime date;
  final int daysUntil;
  final bool yearUnknown;

  UpcomingDate({
    required this.contactId,
    this.contactName,
    required this.type,
    this.label,
    required this.date,
    required this.daysUntil,
    this.yearUnknown = false,
  });
}

/// Service for computing upcoming birthdays and important dates.
class BirthdayService {
  final db.AppDatabase _db;

  BirthdayService(this._db);

  bool _isLeapYear(int year) {
    return (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0);
  }

  /// Computes the next occurrence of a date.
  ///
  /// Policy for 29 February in non-leap years: 28 February.
  ///
  /// For yearly recurrence with unknown year, uses the current or next year.
  DateTime nextOccurrence(ce.ContactDate d, DateTime now) {
    final month = d.date.month;
    final day = d.date.day;

    if (d.recurrence == 'none') {
      return d.date;
    }

    if (d.recurrence == 'yearly') {
      int year = now.year;
      int effectiveDay = day;
      if (month == 2 && day == 29 && !_isLeapYear(year)) {
        effectiveDay = 28;
      }
      DateTime candidate = DateTime(year, month, effectiveDay);
      if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
        year = now.year + 1;
        if (month == 2 && day == 29 && !_isLeapYear(year)) {
          effectiveDay = 28;
        } else {
          effectiveDay = day;
        }
        candidate = DateTime(year, month, effectiveDay);
      }
      return candidate;
    }

    if (d.recurrence == 'monthly') {
      var year = now.year;
      var m = now.month;
      int effectiveDay = day;
      // Policy: if the original day does not exist in the target month,
      // use the last day of that month.
      int daysInMonth(int y, int month) {
        return DateTime(y, month + 1, 0).day;
      }
      if (effectiveDay > daysInMonth(year, m)) {
        effectiveDay = daysInMonth(year, m);
      }
      DateTime candidate = DateTime(year, m, effectiveDay);
      if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
        m += 1;
        if (m > 12) {
          m = 1;
          year += 1;
        }
        if (effectiveDay > daysInMonth(year, m)) {
          effectiveDay = daysInMonth(year, m);
        }
        candidate = DateTime(year, m, effectiveDay);
      }
      return candidate;
    }

    if (d.recurrence == 'weekly') {
      final weekday = d.date.weekday;
      var candidate = DateTime(now.year, now.month, now.day);
      while (candidate.weekday != weekday) {
        candidate = candidate.add(const Duration(days: 1));
      }
      if (candidate.isBefore(DateTime(now.year, now.month, now.day))) {
        candidate = candidate.add(const Duration(days: 7));
      }
      return candidate;
    }

    return d.date;
  }

  /// Returns upcoming dates within [days] days from [now].
  Future<List<UpcomingDate>> getUpcomingDates({int days = 30, DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final cutoff = reference.add(Duration(days: days));
    final allDates = await _db.select(_db.contactDates).get();
    final contacts = await _db.select(_db.contacts).get();
    final nameMap = {for (final c in contacts) c.id: c.displayName ?? c.givenName ?? ''};

    final result = <UpcomingDate>[];
    for (final d in allDates) {
      final next = nextOccurrence(
        ce.ContactDate(
          id: d.id,
          contactId: d.contactId,
          type: d.type,
          label: d.label,
          date: d.date,
          yearUnknown: d.yearUnknown,
          recurrence: d.recurrence,
          sortOrder: d.sortOrder,
        ),
        reference,
      );
      final today = DateTime(reference.year, reference.month, reference.day);
      if (!next.isBefore(today) && !next.isAfter(cutoff)) {
        result.add(UpcomingDate(
          contactId: d.contactId,
          contactName: nameMap[d.contactId],
          type: d.type,
          label: d.label,
          date: next,
          daysUntil: next.difference(today).inDays,
          yearUnknown: d.yearUnknown,
        ));
      }
    }

    result.sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
    return result;
  }
}
