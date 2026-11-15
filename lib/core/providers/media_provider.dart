import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/media/media_service.dart';

final mediaServiceProvider = Provider<MediaService>((ref) => MediaService());
