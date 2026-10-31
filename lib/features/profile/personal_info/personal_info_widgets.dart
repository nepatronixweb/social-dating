import 'package:flutter/material.dart';

import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/interest_chip.dart';
import 'personal_profile_completion.dart';

/// Overall completion card shown on the Personal Information hub.
class ProfileCompletionCard extends StatelessWidget {
  const ProfileCompletionCard({super.key, required this.completion});

  final PersonalProfileCompletion completion;

  @override
  Widget build(BuildContext context) {
    final percent = completion.overallPercent;
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: AppRadii.borderLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('$percent%', style: context.text.headlineMedium),
              AppSpacing.gapMd,
              Expanded(
                child: Text(
                  completion.progressLabel,
                  style: context.text.titleMedium,
                ),
              ),
              if (completion.isComplete)
                Text(
                  'Complete',
                  style: context.text.labelLarge?.copyWith(
                    color: colors.primary,
                  ),
                ),
            ],
          ),
          AppSpacing.gapMd,
          ClipRRect(
            borderRadius: AppRadii.borderPill,
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 8,
              backgroundColor: context.palette.outlineSoft,
            ),
          ),
          AppSpacing.gapSm,
          Text(
            percent < 40
                ? 'Add more details so people can get to know you.'
                : percent < 70
                ? 'You can browse with limited matching.'
                : percent < 100
                ? 'Full matching unlocks as you near a complete profile.'
                : 'You earned the complete profile badge.',
            style: context.text.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class OptionChipGroup extends StatelessWidget {
  const OptionChipGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selectedId,
    required this.onSelected,
    this.optional = false,
  });

  final String label;
  final List<({String id, String label})> options;
  final String? selectedId;
  final ValueChanged<String> onSelected;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          optional ? '$label (optional)' : label,
          style: context.text.titleSmall,
        ),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              InterestChip(
                label: option.label,
                selected: selectedId == option.id,
                onTap: () => onSelected(option.id),
              ),
          ],
        ),
      ],
    );
  }
}

class MultiOptionChipGroup extends StatelessWidget {
  const MultiOptionChipGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.helper,
  });

  final String label;
  final List<({String id, String label})> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.text.titleSmall),
        if (helper != null) ...[
          AppSpacing.gapXs,
          Text(
            helper!,
            style: context.text.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              InterestChip(
                label: option.label,
                selected: selected.contains(option.id),
                onTap: () => onToggle(option.id),
              ),
          ],
        ),
      ],
    );
  }
}

class InterestLabelChipGroup extends StatelessWidget {
  const InterestLabelChipGroup({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.helper,
  });

  final String label;
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.text.titleSmall),
        if (helper != null) ...[
          AppSpacing.gapXs,
          Text(
            helper!,
            style: context.text.bodySmall?.copyWith(
              color: context.palette.textMuted,
            ),
          ),
        ],
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final option in options)
              InterestChip(
                label: option,
                selected: selected.contains(option),
                onTap: () => onToggle(option),
              ),
          ],
        ),
      ],
    );
  }
}
