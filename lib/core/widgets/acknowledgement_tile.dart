import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';

/// A checkbox row with a large tap target, used for agreeing to terms and for
/// the age confirmation. The whole row toggles; [trailing] (for example a
/// "Read" link) stays separately tappable.
class AcknowledgementTile extends StatelessWidget {
  const AcknowledgementTile({
    super.key,
    required this.value,
    required this.onChanged,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final colors = context.colors;
    final palette = context.palette;

    return Semantics(
      container: true,
      checked: value,
      enabled: enabled,
      label: subtitle == null ? title : '$title. $subtitle',
      onTap: enabled ? () => onChanged!(!value) : null,
      excludeSemantics: trailing == null,
      child: Material(
        color: palette.surfaceMuted.withValues(alpha: value ? 0.85 : 0.55),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.borderLg,
          side: BorderSide(
            color: value
                ? colors.primary
                : colors.primary.withValues(alpha: 0.32),
            width: value ? 1.8 : 1.4,
          ),
        ),
        child: InkWell(
          borderRadius: AppRadii.borderLg,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Checkbox(
                    value: value,
                    onChanged: enabled ? (v) => onChanged!(v ?? false) : null,
                    side: WidgetStateBorderSide.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return BorderSide(
                        color: selected
                            ? colors.primary
                            : colors.primary.withValues(alpha: 0.55),
                        width: 1.6,
                      );
                    }),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadii.xs),
                    ),
                  ),
                ),
                SizedBox(
                  width: 1,
                  height: AppSizes.iconXl,
                  child: ColoredBox(
                    color: colors.primary.withValues(alpha: 0.35),
                  ),
                ),
                AppSpacing.gapMd,
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: context.text.bodyLarge),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            style: context.text.bodySmall?.copyWith(
                              color: palette.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
