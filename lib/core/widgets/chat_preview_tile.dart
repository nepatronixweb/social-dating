import 'package:flutter/material.dart';

import '../../data/models/chat.dart';
import '../utils/media_url.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import '../utils/time_format.dart';
import 'profile_avatar.dart';

/// Conversation list row: avatar, name, time, last message and unread count.
class ChatPreviewTile extends StatelessWidget {
  const ChatPreviewTile({
    super.key,
    required this.preview,
    this.onTap,
    this.onLongPress,
  });

  final ChatPreview preview;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasUnread = preview.hasUnread;
    final time = relativeTime(preview.lastMessageAt);
    final photo = preview.profile.photos;
    final previewText = preview.isTyping ? 'Typing...' : preview.lastMessage;

    return Semantics(
      button: true,
      excludeSemantics: true,
      label: [
        preview.profile.displayName,
        if (preview.muted) 'Muted',
        if (hasUnread) '${preview.unreadCount} unread',
        previewText,
        time,
      ].join(', '),
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.listTileMinHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageGutter,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                ProfileAvatar(
                  name: preview.profile.displayName,
                  size: AppSizes.avatarMd,
                  isOnline: preview.profile.isOnline,
                  showRing: hasUnread,
                  image: profileImageProvider(photo.firstOrNull),
                ),
                AppSpacing.gapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              preview.profile.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleMedium,
                            ),
                          ),
                          AppSpacing.gapSm,
                          if (preview.muted) ...[
                            Icon(
                              AppIcons.mute,
                              size: AppSizes.iconSm,
                              color: context.palette.textMuted,
                            ),
                            AppSpacing.gapXs,
                          ],
                          Text(
                            time,
                            style: context.text.bodySmall?.copyWith(
                              color: hasUnread
                                  ? colors.primary
                                  : context.palette.textMuted,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.gapXs,
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              previewText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium?.copyWith(
                                color: preview.isTyping
                                    ? colors.primary
                                    : hasUnread
                                    ? colors.onSurface
                                    : context.palette.textMuted,
                                fontWeight: hasUnread || preview.isTyping
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                fontStyle: preview.isTyping
                                    ? FontStyle.italic
                                    : FontStyle.normal,
                              ),
                            ),
                          ),
                          if (hasUnread) ...[
                            AppSpacing.gapSm,
                            _UnreadBadge(count: preview.unreadCount),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.colors.primary,
        borderRadius: AppRadii.borderPill,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: context.text.labelSmall?.copyWith(
          color: context.colors.onPrimary,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
