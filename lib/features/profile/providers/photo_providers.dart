import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/profile_photo.dart';
import '../../../data/repositories/repository_providers.dart';

class PhotoRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final photoRevisionProvider = NotifierProvider<PhotoRevision, int>(
  PhotoRevision.new,
);

final myPhotosProvider = FutureProvider.autoDispose<List<ProfilePhoto>>((ref) {
  ref.watch(photoRevisionProvider);
  return ref.watch(photoRepositoryProvider).fetchMine();
}, retry: (_, _) => null);
