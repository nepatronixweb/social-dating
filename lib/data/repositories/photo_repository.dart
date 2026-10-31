import 'dart:typed_data';

import '../models/profile_photo.dart';

/// Own-profile photos. Public cards read `photoUrls` on [Profile] instead.
abstract interface class PhotoRepository {
  Future<List<ProfilePhoto>> fetchMine();

  Future<ProfilePhoto> upload({
    required Uint8List bytes,
    required String filename,
    String? contentType,
  });

  Future<void> reorder(List<String> ids);

  Future<void> delete(String id);
}
