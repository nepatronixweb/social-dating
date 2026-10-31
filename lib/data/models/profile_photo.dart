import 'package:flutter/foundation.dart';

/// One photo on the signed-in profile. [source] is a local `assets/` path in
/// mock mode, or a signed media path from the API.
@immutable
class ProfilePhoto {
  const ProfilePhoto({
    required this.id,
    required this.source,
    required this.sortOrder,
  });

  final String id;
  final String source;
  final int sortOrder;

  @override
  bool operator ==(Object other) =>
      other is ProfilePhoto &&
      other.id == id &&
      other.source == source &&
      other.sortOrder == sortOrder;

  @override
  int get hashCode => Object.hash(id, source, sortOrder);
}
