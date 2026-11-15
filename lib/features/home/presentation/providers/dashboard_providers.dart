import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/database_provider.dart';
import '../../../birthdays/domain/services/birthday_service.dart';
import '../../../dashboard/domain/services/dashboard_service.dart';

final dashboardServiceProvider = Provider<DashboardService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DashboardService(db);
});

final dashboardSummaryProvider = FutureProvider((ref) async {
  final service = ref.watch(dashboardServiceProvider);
  return service.getSummary();
});

final birthdayServiceProvider = Provider<BirthdayService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return BirthdayService(db);
});

final upcomingDatesProvider = FutureProvider((ref) async {
  final service = ref.watch(birthdayServiceProvider);
  return service.getUpcomingDates(days: 30);
});
