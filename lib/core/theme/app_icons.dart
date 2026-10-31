import 'package:flutter/material.dart';

/// Central icon vocabulary.
///
/// Convention: **all icons come from here**, which maps to Material's rounded
/// set so the visual weight is identical on Android and iOS. Never reference
/// `Icons.*` (or emoji) elsewhere; `test/design_conventions_test.dart`
/// enforces it.
abstract final class AppIcons {
  // Navigation / tabs
  static const IconData discover = Icons.explore_rounded;
  static const IconData likes = Icons.favorite_rounded;
  static const IconData matches = Icons.people_alt_rounded;
  static const IconData chat = Icons.chat_bubble_rounded;
  static const IconData profile = Icons.person_rounded;

  // Bottom navigation: outlined when idle, filled when selected.
  // Discover uses [BrandMark], not a Material icon.
  static const IconData matchesOutline = Icons.people_outline_rounded;
  static const IconData chatOutline = Icons.chat_bubble_outline_rounded;
  static const IconData profileOutline = Icons.person_outline_rounded;

  // Actions
  static const IconData heart = Icons.favorite_rounded;
  static const IconData heartOutline = Icons.favorite_border_rounded;
  static const IconData pass = Icons.close_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData forward = Icons.arrow_forward_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData add = Icons.add_rounded;
  static const IconData check = Icons.check_rounded;
  static const IconData send = Icons.send_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData refresh = Icons.refresh_rounded;
  static const IconData copy = Icons.content_copy_rounded;
  static const IconData share = Icons.ios_share_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData camera = Icons.photo_camera_rounded;
  static const IconData logout = Icons.logout_rounded;
  static const IconData delete = Icons.delete_outline_rounded;
  static const IconData filter = Icons.tune_rounded;
  static const IconData undo = Icons.undo_rounded;
  static const IconData history = Icons.history_rounded;
  static const IconData arrowUp = Icons.arrow_upward_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData arrowDown = Icons.keyboard_arrow_down_rounded;
  static const IconData mute = Icons.volume_off_rounded;
  static const IconData unmute = Icons.volume_up_rounded;
  static const IconData attach = Icons.add_photo_alternate_rounded;
  static const IconData image = Icons.image_rounded;
  static const IconData dragHandle = Icons.drag_handle_rounded;

  // Status
  static const IconData verified = Icons.verified_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData success = Icons.check_circle_rounded;
  static const IconData wifiOff = Icons.wifi_off_rounded;
  static const IconData inbox = Icons.inbox_rounded;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;

  // Features
  static const IconData notifications = Icons.notifications_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData shield = Icons.shield_rounded;
  static const IconData safety = Icons.health_and_safety_rounded;
  static const IconData account = Icons.manage_accounts_rounded;
  static const IconData wallet = Icons.account_balance_wallet_rounded;
  static const IconData creditCard = Icons.credit_card_rounded;
  static const IconData receipt = Icons.receipt_long_rounded;
  static const IconData help = Icons.help_outline_rounded;
  static const IconData premium = Icons.workspace_premium_rounded;
  static const IconData referral = Icons.card_giftcard_rounded;
  static const IconData block = Icons.block_rounded;
  static const IconData report = Icons.flag_rounded;
  static const IconData palette = Icons.palette_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData mail = Icons.mail_rounded;
  static const IconData phone = Icons.phone_iphone_rounded;
  static const IconData location = Icons.location_on_rounded;
  static const IconData work = Icons.work_outline_rounded;
  static const IconData bolt = Icons.bolt_rounded;
  static const IconData star = Icons.star_rounded;
  static const IconData code = Icons.pin_rounded;
  static const IconData calendar = Icons.calendar_month_rounded;
  static const IconData expandMore = Icons.expand_more_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData document = Icons.description_outlined;
  static const IconData sessionExpired = Icons.lock_clock_rounded;
  static const IconData accessibility = Icons.accessibility_new_rounded;
  static const IconData bedtime = Icons.bedtime_rounded;
  static const IconData textSize = Icons.text_fields_rounded;
  static const IconData markRead = Icons.done_all_rounded;

  // Interests. Unknown interests fall back to a generic tag icon.
  static const IconData interestFallback = Icons.local_offer_rounded;
  static const Map<String, IconData> _interestIcons = {
    'coffee': Icons.coffee_rounded,
    'hiking': Icons.hiking_rounded,
    'film': Icons.movie_rounded,
    'movies': Icons.movie_rounded,
    'yoga': Icons.self_improvement_rounded,
    'travel': Icons.flight_rounded,
    'books': Icons.menu_book_rounded,
    'reading': Icons.menu_book_rounded,
    'music': Icons.music_note_rounded,
    'art': Icons.brush_rounded,
    'cooking': Icons.restaurant_rounded,
    'vinyl': Icons.album_rounded,
    'climbing': Icons.landscape_rounded,
    'cycling': Icons.pedal_bike_rounded,
    'food': Icons.restaurant_rounded,
    'running': Icons.directions_run_rounded,
    'photography': Icons.photo_camera_rounded,
    'dogs': Icons.pets_rounded,
    'cats': Icons.pets_rounded,
    'gaming': Icons.sports_esports_rounded,
    'fitness': Icons.fitness_center_rounded,
    'dancing': Icons.nightlife_rounded,
    'nature': Icons.park_rounded,
  };

  /// The icon for an interest label (case-insensitive).
  static IconData forInterest(String interest) =>
      _interestIcons[interest.trim().toLowerCase()] ?? interestFallback;
}
