/// Compact relative time for lists ("Now", "5m", "3h", "Yesterday", "4d").
String relativeTime(DateTime then, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(then);
  if (diff.inMinutes < 1) return 'Now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inHours < 48) return 'Yesterday';
  return '${diff.inDays}d';
}

/// "Liked 25m ago", "Matched yesterday", "Unmatched just now".
String timestampLabel(String verb, DateTime then, {DateTime? now}) {
  return switch (relativeTime(then, now: now)) {
    'Now' => '$verb just now',
    'Yesterday' => '$verb yesterday',
    final t => '$verb $t ago',
  };
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Day label for a chat transcript ("Today", "Yesterday", "12 Oct 2026").
String chatDayLabel(DateTime then, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final day = DateTime(then.year, then.month, then.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${day.day} ${_months[day.month - 1]} ${day.year}';
}

/// Recently-active text for a match ("Active now", "Active 3h ago"). Returns
/// null when the person does not share activity. Mock data only for now.
String? activityLabel(
  DateTime? lastActiveAt, {
  DateTime? now,
  Duration activeNow = const Duration(minutes: 10),
}) {
  if (lastActiveAt == null) return null;
  final current = now ?? DateTime.now();
  if (current.difference(lastActiveAt) <= activeNow) return 'Active now';
  return timestampLabel('Active', lastActiveAt, now: current);
}
