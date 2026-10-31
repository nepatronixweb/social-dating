import 'package:flutter/material.dart';

/// Restrained, warm-tinted shadows. In dark mode shadows are nearly invisible,
/// so depth comes from surface colour instead and these return empty lists.
abstract final class AppElevation {
  static List<BoxShadow> none(Brightness b) => const [];

  static List<BoxShadow> low(Brightness b) => b == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0F1B1620),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ];

  static List<BoxShadow> medium(Brightness b) => b == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x141B1620),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ];

  static List<BoxShadow> high(Brightness b) => b == Brightness.dark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x1F1B1620),
            blurRadius: 36,
            offset: Offset(0, 16),
          ),
        ];
}
