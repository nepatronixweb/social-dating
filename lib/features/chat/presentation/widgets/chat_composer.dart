import 'package:flutter/material.dart';

import '../../../../core/constants/message_rules.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radii.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/media_url.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/inline_message.dart';

/// Keyboard-aware composer: draft field, counters, mock cost preview, attach
/// and send. The send button stays locked while a send is in flight.
class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.offline,
    required this.quote,
    required this.onSend,
    required this.onAttach,
    this.imageAsset,
    this.onClearImage,
    this.sendError,
    this.attachTooltip = 'Attach sample photo',
  });

  final TextEditingController controller;
  final bool sending;
  final bool offline;
  final MessageQuote quote;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final String? imageAsset;
  final VoidCallback? onClearImage;
  final String? sendError;
  final String attachTooltip;

  bool get _canSend {
    if (sending || offline || quote.tooLong) return false;
    return controller.text.trim().isNotEmpty || imageAsset != null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final words = quote.eligibleWords;
    final wordLabel = words == 1 ? '1 word' : '$words words';

    return Material(
      key: const Key('chat-composer'),
      color: colors.surface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (offline)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpacing.sm),
                child: InlineMessage(
                  tone: InlineMessageTone.warning,
                  icon: AppIcons.wifiOff,
                  title: "You're offline",
                  message: 'Messages cannot be sent until you are back.',
                ),
              ),
            if (sendError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InlineMessage(
                  tone: InlineMessageTone.error,
                  title: 'Message not sent',
                  message: sendError!,
                  bringIntoView: true,
                ),
              ),
            if (imageAsset != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      ClipRRect(
                        borderRadius: AppRadii.borderMd,
                        child: Builder(
                          builder: (context) {
                            final image = profileImageProvider(imageAsset);
                            final fallback = SizedBox(
                              height: 72,
                              width: 72,
                              child: ColoredBox(
                                color: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainerHighest,
                                child: const Icon(AppIcons.image),
                              ),
                            );
                            if (image == null) return fallback;
                            return Image(
                              image: image,
                              height: 72,
                              width: 72,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => fallback,
                            );
                          },
                        ),
                      ),
                      Positioned(
                        top: -8,
                        right: -8,
                        child: IconButton.filled(
                          tooltip: 'Remove photo',
                          onPressed: sending ? null : onClearImage,
                          icon: const Icon(
                            AppIcons.close,
                            size: AppSizes.iconSm,
                          ),
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(32),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: colors.surface,
                            foregroundColor: colors.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: attachTooltip,
                  onPressed: (sending || offline) ? null : onAttach,
                  icon: const Icon(AppIcons.attach),
                ),
                Expanded(
                  child: TextField(
                    controller: controller,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !sending && !offline,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (_canSend) onSend();
                    },
                    decoration: const InputDecoration(hintText: 'Message'),
                  ),
                ),
                AppSpacing.gapSm,
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _canSend ? onSend : null,
                  icon: sending
                      ? SizedBox.square(
                          dimension: AppSizes.iconMd,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: colors.onPrimary,
                          ),
                        )
                      : const Icon(AppIcons.send),
                  style: IconButton.styleFrom(
                    minimumSize: const Size.square(AppSpacing.minTouchTarget),
                    backgroundColor: colors.primary,
                    foregroundColor: colors.onPrimary,
                  ),
                ),
              ],
            ),
            AppSpacing.gapXs,
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${quote.characterCount}/${MessageRules.maxCharacters} · $wordLabel',
                  style: context.text.labelSmall?.copyWith(
                    color: quote.tooLong
                        ? colors.error
                        : context.palette.textMuted,
                  ),
                ),
                if (quote.isPaid)
                  Text(
                    'Est. ${formatNpr(quote.costPaisa)} · ${formatPoints(quote.costPoints)}',
                    style: context.text.labelSmall?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (quote.senderPays &&
                    !quote.isPaid &&
                    quote.characterCount > 0)
                  Text(
                    'No eligible words · no charge',
                    style: context.text.labelSmall?.copyWith(
                      color: context.palette.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
