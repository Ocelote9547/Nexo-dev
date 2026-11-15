import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/repositories/android_contacts_repository.dart';
import '../../data/repositories/android_contacts_repository_impl.dart';

final androidContactsRepositoryProvider =
    Provider<AndroidContactsRepository>((ref) {
  return AndroidContactsRepositoryImpl();
});
