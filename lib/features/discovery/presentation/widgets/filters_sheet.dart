import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/interest_chip.dart';
import '../../../../data/models/discovery_filters.dart';

/// Opens the filters sheet. Resolves to the chosen filters, or `null` when it
/// was dismissed without applying.
Future<DiscoveryFilters?> showDiscoveryFiltersSheet(
  BuildContext context, {
  required DiscoveryFilters current,
}) {
  return showAppBottomSheet<DiscoveryFilters>(
    context,
    title: 'Discovery preferences',
    builder: (sheetContext) => DiscoveryFiltersSheet(initial: current),
  );
}

String _distanceLabel(int? km) =>
    km == null ? 'Any distance' : 'Within about $km km';

class DiscoveryFiltersSheet extends StatefulWidget {
  const DiscoveryFiltersSheet({super.key, required this.initial});

  final DiscoveryFilters initial;

  @override
  State<DiscoveryFiltersSheet> createState() => _DiscoveryFiltersSheetState();
}

class _DiscoveryFiltersSheetState extends State<DiscoveryFiltersSheet> {
  late DiscoveryFilters _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final muted = text.bodySmall?.copyWith(color: context.palette.textMuted);
    final distance = _draft.maxDistanceKm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Age: ${_draft.minAge} to ${_draft.maxAge}',
          style: text.titleSmall,
        ),
        RangeSlider(
          min: DiscoveryFilters.minimumAge.toDouble(),
          max: DiscoveryFilters.maximumAge.toDouble(),
          divisions: DiscoveryFilters.maximumAge - DiscoveryFilters.minimumAge,
          values: RangeValues(
            _draft.minAge.toDouble(),
            _draft.maxAge.toDouble(),
          ),
          labels: RangeLabels('${_draft.minAge}', '${_draft.maxAge}'),
          semanticFormatterCallback: (value) => '${value.round()} years',
          onChanged: (values) => setState(
            () => _draft = _draft.copyWith(
              minAge: values.start.round(),
              maxAge: values.end.round(),
            ),
          ),
        ),
        AppSpacing.gapMd,
        Text('Distance: ${_distanceLabel(distance)}', style: text.titleSmall),
        Slider(
          min: DiscoveryFilters.minDistanceKm.toDouble(),
          max: DiscoveryFilters.distanceCeilingKm.toDouble(),
          divisions:
              (DiscoveryFilters.distanceCeilingKm -
                  DiscoveryFilters.minDistanceKm) ~/
              5,
          value: (distance ?? DiscoveryFilters.distanceCeilingKm).toDouble(),
          label: _distanceLabel(distance),
          semanticFormatterCallback: (value) =>
              value.round() >= DiscoveryFilters.distanceCeilingKm
              ? 'Any distance'
              : '${value.round()} kilometres',
          onChanged: (value) {
            final km = value.round();
            setState(
              () => _draft = km >= DiscoveryFilters.distanceCeilingKm
                  ? _draft.copyWith(clearDistance: true)
                  : _draft.copyWith(maxDistanceKm: km),
            );
          },
        ),
        Text(
          'Distances are approximate. Exact locations are never shown.',
          style: muted,
        ),
        AppSpacing.gapMd,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Verified profiles only'),
          value: _draft.verifiedOnly,
          onChanged: (value) =>
              setState(() => _draft = _draft.copyWith(verifiedOnly: value)),
        ),
        AppSpacing.gapMd,
        Text('Shared interests', style: text.titleSmall),
        AppSpacing.gapXs,
        Text('Show people who share at least one.', style: muted),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          children: [
            for (final interest in AppConstants.interestOptions)
              InterestChip(
                label: interest,
                selected: _draft.interests.contains(interest),
                onTap: () {
                  final next = {..._draft.interests};
                  if (!next.add(interest)) next.remove(interest);
                  setState(() => _draft = _draft.copyWith(interests: next));
                },
              ),
          ],
        ),
        AppSpacing.gapXl,
        AppButton(
          label: 'Show results',
          onPressed: () => Navigator.of(context).pop(_draft),
        ),
        AppSpacing.gapSm,
        AppButton(
          label: 'Reset to defaults',
          variant: AppButtonVariant.text,
          onPressed: _draft.isDefault
              ? null
              : () => setState(() => _draft = DiscoveryFilters.defaults),
        ),
      ],
    );
  }
}
