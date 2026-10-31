import 'package:flutter/material.dart';

import '../../data/models/match.dart';
import '../utils/media_url.dart';
import '../utils/time_format.dart';
import 'app_pill.dart';
import 'image_card.dart';

/// A match as a portrait card: photo, name, "Matched 2h ago", and a "New" pill
/// for matches the user hasn't opened yet.
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    this.onTap,
    this.placeholderSeed = 0,
    this.now,
    this.activity,
  });

  final Match match;

  /// Reference time for the labels (defaults to the device clock).
  final DateTime? now;

  /// Optional recently-active line, for example "Active now".
  final String? activity;
  final VoidCallback? onTap;
  final int placeholderSeed;

  static String matchedLabel(DateTime matchedAt, {DateTime? now}) =>
      timestampLabel('Matched', matchedAt, now: now);

  @override
  Widget build(BuildContext context) {
    return ImageCard(
      title: match.profile.displayName,
      subtitle: [matchedLabel(match.matchedAt, now: now), ?activity].join('\n'),
      image: profileImageProvider(match.profile.photos.firstOrNull),
      placeholderSeed: placeholderSeed,
      onTap: onTap,
      semanticLabel:
          '${match.profile.displayName}, ${matchedLabel(match.matchedAt, now: now)}'
          '${activity == null ? '' : ', $activity'}'
          '${match.isNew ? ', new match' : ''}',
      badge: match.isNew
          ? const AppPill(label: 'New', tone: AppPillTone.onImage)
          : null,
    );
  }
}
