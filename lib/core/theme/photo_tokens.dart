import 'package:flutter/material.dart';

/// Colours for content drawn over photos. A photo is the same in light and dark
/// themes, so these do not change with the theme.
abstract final class PhotoTokens {
  /// Text and icons over a photo.
  static const Color foreground = Color(0xFFFFFFFF);

  /// The shade behind controls and scrims over a photo.
  static const Color shade = Color(0xFF000000);

  /// Accent for secondary swipe actions (super like, message).
  static const Color actionBlue = Color(0xFF4DA3FF);
}
