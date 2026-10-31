import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Local configuration flags. Nothing here is fetched from a server.
///
/// Set at build time, for example:
/// `flutter run --dart-define=UNDO_SWIPE=true`
class FeatureFlags {
  const FeatureFlags({this.undoSwipe = false});

  /// Enables undoing the last swipe. Off by default: the undo control is shown
  /// disabled. When on it is mock-only, because the server has not defined
  /// whether undo is allowed, whether it is free, or how it affects the daily
  /// count.
  final bool undoSwipe;

  FeatureFlags copyWith({bool? undoSwipe}) =>
      FeatureFlags(undoSwipe: undoSwipe ?? this.undoSwipe);
}

final featureFlagsProvider = Provider<FeatureFlags>(
  (ref) => const FeatureFlags(
    undoSwipe: bool.fromEnvironment('UNDO_SWIPE', defaultValue: false),
  ),
);
