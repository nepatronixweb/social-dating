import 'package:flutter/foundation.dart';

import '../models/profile_photo.dart';
import 'json_codec.dart';

@immutable
class PhotoDto {
  const PhotoDto({
    required this.id,
    required this.url,
    required this.sortOrder,
  });

  final String id;
  final String url;
  final int sortOrder;

  factory PhotoDto.fromJson(Object? json) =>
      PhotoDto.fromMap(JsonMap.from(json));

  factory PhotoDto.fromMap(JsonMap map) => PhotoDto(
    id: map.string('id'),
    url: map.string('url'),
    sortOrder: map.integer('sortOrder'),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'url': url,
    'sortOrder': sortOrder,
  };

  ProfilePhoto toDomain() =>
      ProfilePhoto(id: id, source: url, sortOrder: sortOrder);
}
