import 'package:flutter/foundation.dart';

import '../../core/constants/swipe_rules.dart';
import 'profile.dart';

/// Left is a pass, right is a like. Both count towards the same quota.
enum SwipeDirection { left, right }

/// What the next swipe would be, given the current quota.
enum SwipeKind {
  /// One of the first swipes allowed before the profile is complete.
  preview,

  /// Within the free daily allowance (or the account has no limit).
  free,

  /// Beyond the free allowance and affordable: needs confirmation.
  paid,

  /// Beyond the free allowance and the mock balance is too low.
  insufficient,

  /// The preview swipes are used up and the profile is still incomplete.
  needsProfile,
}

@immutable
class SwipeAvailability {
  const SwipeAvailability(this.kind, {this.costPaisa = 0});

  final SwipeKind kind;

  /// Cost of the next swipe in paisa. Zero unless it is paid.
  final int costPaisa;

  /// Whether a swipe can go ahead without asking first.
  bool get isFree => kind == SwipeKind.preview || kind == SwipeKind.free;
}

/// A snapshot of the signed-in person's swipe allowance.
///
/// MOCK BEHAVIOUR: this class is the single place the counting and pricing
/// rules live, shared by the UI (to decide what to show) and the mock
/// repository (to enforce it). Client-side next-swipe cost is a display
/// preview only. A server must replace both; the UI must then only display
/// what the server reports.
@immutable
class SwipeQuota {
  const SwipeQuota({
    required this.profileComplete,
    required this.previewUsed,
    required this.dailyUsed,
    required this.freeDailyLimit,
    required this.balancePaisa,
    required this.dayKey,
    required this.resetsAt,
    this.pricePaisa = SwipeRules.extraSwipePricePaisa,
  });

  final bool profileComplete;

  /// Swipes made before the profile was complete.
  final int previewUsed;

  /// Left + right swipes made today (Nepal time) after the profile was
  /// complete, including paid ones.
  final int dailyUsed;

  /// Free swipes per Nepal day, or `null` when the account has no limit.
  final int? freeDailyLimit;

  /// Mock wallet balance in paisa.
  final int balancePaisa;
  final int pricePaisa;

  /// The Nepal calendar day this snapshot belongs to (`YYYY-MM-DD`).
  final String dayKey;

  /// When the daily counter next resets (a UTC instant: Nepal midnight).
  final DateTime resetsAt;

  int get previewRemaining =>
      (SwipeRules.previewSwipes - previewUsed).clamp(0, 1 << 30);

  /// Free swipes left today, or `null` when there is no limit.
  int? get freeRemaining {
    final limit = freeDailyLimit;
    if (limit == null) return null;
    return (limit - dailyUsed).clamp(0, 1 << 30);
  }

  bool get hasDailyLimit => freeDailyLimit != null;

  SwipeAvailability get next {
    if (!profileComplete) {
      return previewRemaining > 0
          ? const SwipeAvailability(SwipeKind.preview)
          : const SwipeAvailability(SwipeKind.needsProfile);
    }
    final remaining = freeRemaining;
    if (remaining == null || remaining > 0) {
      return const SwipeAvailability(SwipeKind.free);
    }
    return balancePaisa >= pricePaisa
        ? SwipeAvailability(SwipeKind.paid, costPaisa: pricePaisa)
        : SwipeAvailability(SwipeKind.insufficient, costPaisa: pricePaisa);
  }

  /// The quota after one allowed swipe. Blocked states return `this`.
  SwipeQuota afterSwipe() {
    final availability = next;
    switch (availability.kind) {
      case SwipeKind.preview:
        return copyWith(previewUsed: previewUsed + 1);
      case SwipeKind.free:
        return copyWith(dailyUsed: dailyUsed + 1);
      case SwipeKind.paid:
        return copyWith(
          dailyUsed: dailyUsed + 1,
          balancePaisa: balancePaisa - availability.costPaisa,
        );
      case SwipeKind.insufficient:
      case SwipeKind.needsProfile:
        return this;
    }
  }

  SwipeQuota copyWith({
    bool? profileComplete,
    int? previewUsed,
    int? dailyUsed,
    int? balancePaisa,
  }) => SwipeQuota(
    profileComplete: profileComplete ?? this.profileComplete,
    previewUsed: previewUsed ?? this.previewUsed,
    dailyUsed: dailyUsed ?? this.dailyUsed,
    freeDailyLimit: freeDailyLimit,
    balancePaisa: balancePaisa ?? this.balancePaisa,
    pricePaisa: pricePaisa,
    dayKey: dayKey,
    resetsAt: resetsAt,
  );

  @override
  bool operator ==(Object other) =>
      other is SwipeQuota &&
      other.profileComplete == profileComplete &&
      other.previewUsed == previewUsed &&
      other.dailyUsed == dailyUsed &&
      other.freeDailyLimit == freeDailyLimit &&
      other.balancePaisa == balancePaisa &&
      other.pricePaisa == pricePaisa &&
      other.dayKey == dayKey &&
      other.resetsAt == resetsAt;

  @override
  int get hashCode => Object.hash(
    profileComplete,
    previewUsed,
    dailyUsed,
    freeDailyLimit,
    balancePaisa,
    pricePaisa,
    dayKey,
    resetsAt,
  );
}

/// Why a swipe was not recorded.
enum SwipeRejection { paymentRequired, insufficientFunds, profileIncomplete }

/// Result of asking the repository to record a swipe.
@immutable
class SwipeOutcome {
  const SwipeOutcome.recorded({
    required this.quota,
    this.matchedProfile,
    this.chargedPaisa = 0,
  }) : rejection = null;

  const SwipeOutcome.rejected({required this.quota, required this.rejection})
    : matchedProfile = null,
      chargedPaisa = 0;

  /// The quota after this call, as the repository sees it.
  final SwipeQuota quota;

  /// Set when a right swipe produced a mutual match.
  final Profile? matchedProfile;
  final int chargedPaisa;
  final SwipeRejection? rejection;

  bool get recorded => rejection == null;
}

/// What the repository gives back after an undo.
@immutable
class UndoOutcome {
  const UndoOutcome({required this.profile, required this.quota});

  final Profile profile;
  final SwipeQuota quota;
}
