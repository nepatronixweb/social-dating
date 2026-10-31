import 'package:flutter/material.dart';

import '../../data/models/chat.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/media_url.dart';
import '../utils/theme_context.dart';
import '../utils/time_format.dart';

/// A single chat message bubble. Your messages are brand-coloured and
/// right-aligned; theirs are muted and left-aligned. Outgoing delivery
/// (sending, sent, failed) is shown under your own bubbles.
class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mine = message.isMine;
    final failed = message.isFailed;
    final background = failed
        ? colors.errorContainer
        : mine
        ? colors.primary
        : context.palette.surfaceMuted;
    final foreground = failed
        ? colors.onErrorContainer
        : mine
        ? colors.onPrimary
        : colors.onSurface;

    const big = Radius.circular(AppRadii.lg);
    const small = Radius.circular(AppRadii.xs);

    return Semantics(
      label: [
        mine ? 'You' : 'Them',
        if (message.text.isNotEmpty) message.text,
        if (message.hasImage) 'Photo',
        relativeTime(message.sentAt),
        if (mine && message.isSending) 'Sending',
        if (mine && message.delivery == MessageDelivery.sent) 'Sent',
        if (failed) 'Failed',
      ].join(', '),
      excludeSemantics: true,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width * 0.78,
          ),
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.only(
                    topLeft: big,
                    topRight: big,
                    bottomLeft: mine ? big : small,
                    bottomRight: mine ? small : big,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.hasImage) ...[
                        ClipRRect(
                          borderRadius: AppRadii.borderMd,
                          child: _ChatImage(
                            source: message.imageAsset!,
                            height: 160,
                            width: 220,
                            iconColor: foreground,
                          ),
                        ),
                        if (message.text.isNotEmpty) AppSpacing.gapSm,
                      ],
                      if (message.text.isNotEmpty)
                        Text(
                          message.text,
                          style: context.text.bodyMedium?.copyWith(
                            color: foreground,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (mine) ...[
                AppSpacing.gapXs,
                _DeliveryStatus(message: message, onRetry: onRetry),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DeliveryStatus extends StatelessWidget {
  const _DeliveryStatus({required this.message, this.onRetry});

  final ChatMessage message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = context.palette.textMuted;
    switch (message.delivery) {
      case MessageDelivery.sending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: AppSizes.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2, color: muted),
            ),
            AppSpacing.gapXs,
            Text(
              'Sending',
              style: context.text.labelSmall?.copyWith(color: muted),
            ),
          ],
        );
      case MessageDelivery.sent:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.check, size: AppSizes.iconSm, color: muted),
            AppSpacing.gapXs,
            Text(
              'Sent',
              style: context.text.labelSmall?.copyWith(color: muted),
            ),
          ],
        );
      case MessageDelivery.failed:
        return TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(AppIcons.refresh, size: AppSizes.iconSm),
          label: const Text('Failed · Retry'),
          style: TextButton.styleFrom(
            foregroundColor: context.colors.error,
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        );
    }
  }
}

class _ChatImage extends StatelessWidget {
  const _ChatImage({
    required this.source,
    required this.height,
    required this.width,
    required this.iconColor,
  });

  final String source;
  final double height;
  final double width;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final image = profileImageProvider(source);
    final fallback = SizedBox(
      height: height > 100 ? 80 : height,
      width: width > 140 ? 120 : width,
      child: Center(child: Icon(AppIcons.image, color: iconColor)),
    );
    if (image == null) return fallback;
    return Image(
      image: image,
      height: height,
      width: width,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
