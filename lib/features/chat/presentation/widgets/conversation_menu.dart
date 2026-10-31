import 'package:flutter/material.dart';

import '../../../../core/theme/app_icons.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/menu_tile.dart';

enum ConversationMenuAction { mute, unmute, hide, report, unmatch, block }

/// Mute, hide, report, unmatch and block for the open conversation.
Future<ConversationMenuAction?> showConversationMenu(
  BuildContext context, {
  required bool muted,
  required bool hasMatch,
}) {
  return showAppBottomSheet<ConversationMenuAction>(
    context,
    title: 'Conversation',
    builder: (sheetContext) => Column(
      children: [
        MenuTile(
          icon: muted ? AppIcons.unmute : AppIcons.mute,
          title: muted ? 'Unmute' : 'Mute',
          subtitle: muted
              ? 'Show unread counts again'
              : 'Hide unread counts for this chat',
          onTap: () => Navigator.of(sheetContext).pop(
            muted ? ConversationMenuAction.unmute : ConversationMenuAction.mute,
          ),
        ),
        MenuTile(
          icon: AppIcons.visibilityOff,
          title: 'Hide conversation',
          subtitle: 'Remove it from this list. You stay matched.',
          onTap: () =>
              Navigator.of(sheetContext).pop(ConversationMenuAction.hide),
        ),
        MenuTile(
          icon: AppIcons.report,
          title: 'Report',
          subtitle: 'Open the safety centre',
          onTap: () =>
              Navigator.of(sheetContext).pop(ConversationMenuAction.report),
        ),
        if (hasMatch) ...[
          MenuTile(
            icon: AppIcons.close,
            title: 'Unmatch',
            destructive: true,
            onTap: () =>
                Navigator.of(sheetContext).pop(ConversationMenuAction.unmatch),
          ),
          MenuTile(
            icon: AppIcons.block,
            title: 'Block',
            destructive: true,
            onTap: () =>
                Navigator.of(sheetContext).pop(ConversationMenuAction.block),
          ),
        ],
      ],
    ),
  );
}
