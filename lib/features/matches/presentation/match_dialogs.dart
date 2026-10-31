import 'package:flutter/widgets.dart';

import '../../../core/widgets/confirmation_dialog.dart';
import '../../../data/models/profile.dart';

String _first(Profile profile) => profile.displayName.split(' ').first;

/// Asks before ending a match. Resolves to true only on explicit confirmation.
Future<bool> confirmUnmatch(BuildContext context, Profile profile) {
  return showConfirmationDialog(
    context,
    title: 'Unmatch with ${_first(profile)}?',
    message:
        'You will stop seeing each other and your conversation will close. '
        'You cannot undo this from the app.',
    confirmLabel: 'Unmatch',
    cancelLabel: 'Keep match',
    isDestructive: true,
  );
}

/// Asks before blocking someone. Resolves to true only on explicit
/// confirmation.
Future<bool> confirmBlock(BuildContext context, Profile profile) {
  return showConfirmationDialog(
    context,
    title: 'Block ${_first(profile)}?',
    message:
        'They will be removed from your matches, likes and chats, and will '
        'not appear in discovery. Blocking cannot be undone from the app in '
        'this version.',
    confirmLabel: 'Block',
    cancelLabel: 'Cancel',
    isDestructive: true,
  );
}
