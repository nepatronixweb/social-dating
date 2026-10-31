import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// Honest labelling for the mock authentication flow: no SMS is sent and
/// nothing is verified. Always rendered with the word "Development" so it can
/// never be mistaken for real verification.
///
/// Pass the repository's `developmentNotice`; renders nothing when it is null
/// (i.e. when a real repository is wired in).
class DevelopmentNoticeBanner extends StatelessWidget {
  const DevelopmentNoticeBanner({super.key, required this.notice});

  final String? notice;

  @override
  Widget build(BuildContext context) {
    final text = notice;
    if (text == null) return const SizedBox.shrink();

    final palette = context.palette;
    final warning = palette.warning;

    return Semantics(
      container: true,
      label: 'Development notice. $text',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: warning.withValues(alpha: 0.08),
          borderRadius: AppRadii.borderLg,
          border: Border.all(color: warning.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: warning.withValues(alpha: 0.7)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs + 1),
                  child: Icon(
                    AppIcons.info,
                    size: AppSizes.iconSm,
                    color: warning,
                  ),
                ),
              ),
              AppSpacing.gapSm,
              SizedBox(
                width: 1,
                height: AppSizes.iconXl,
                child: ColoredBox(color: warning.withValues(alpha: 0.55)),
              ),
              AppSpacing.gapMd,
              Expanded(child: _NoticeBody(text: text)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeBody extends StatelessWidget {
  const _NoticeBody({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final base = context.text.bodySmall?.copyWith(
      color: context.colors.onSurface,
      height: 1.45,
    );
    final match = RegExp(r'\d{6}').firstMatch(text);
    if (match == null) {
      return Text(text, style: base);
    }

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          TextSpan(text: text.substring(0, match.start)),
          TextSpan(
            text: match.group(0),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: context.colors.primary,
            ),
          ),
          TextSpan(text: text.substring(match.end)),
        ],
      ),
    );
  }
}
