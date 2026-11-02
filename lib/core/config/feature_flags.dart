import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local configuration flags. Nothing here is fetched from a server.
///
/// Set at build time, for example:
/// `flutter run --dart-define=UNDO_SWIPE=true`
class FeatureFlags {
  const FeatureFlags({this.undoSwipe = true});

  /// Enables undoing the last swipe. On by default. Unsubscribed males pay
  /// 100 points for a rewind.
  final bool undoSwipe;

  FeatureFlags copyWith({bool? undoSwipe}) =>
      FeatureFlags(undoSwipe: undoSwipe ?? this.undoSwipe);
}

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags(
    undoSwipe: bool.fromEnvironment('UNDO_SWIPE', defaultValue: true),
  ),
);
