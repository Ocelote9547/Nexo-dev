import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/quick_actions_service.dart';

final quickActionsServiceProvider = Provider<QuickActionsService>((ref) {
  return QuickActionsService();
});
