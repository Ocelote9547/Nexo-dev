import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../services/privacy/privacy_service.dart';

final privacyServiceProvider = Provider<PrivacyService>((ref) {
  return PrivacyService();
});
