import 'package:flutter/material.dart';

import '../../data/models/country.dart';
import '../theme/app_icons.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../utils/theme_context.dart';
import 'app_bottom_sheet.dart';
import 'app_text_field.dart';

/// The compact "NP +977" control that sits at the start of the phone field.
/// Tapping it opens the country list. The country is shown as its ISO code
/// (never a flag emoji) so it renders the same on every device.
class CountrySelectorButton extends StatelessWidget {
  const CountrySelectorButton({
    super.key,
    required this.country,
    required this.onChanged,
    this.enabled = true,
  });

  final Country country;
  final ValueChanged<Country> onChanged;
  final bool enabled;

  Future<void> _open(BuildContext context) async {
    final picked = await showCountryPicker(context, selected: country);
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Country: ${country.name}, ${country.dialCode}. Change country',
      excludeSemantics: true,
      onTap: enabled ? () => _open(context) : null,
      child: InkWell(
        borderRadius: AppRadii.borderPill,
        onTap: enabled ? () => _open(context) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSpacing.minTouchTarget,
            minWidth: AppSpacing.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              right: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palette.pageBackground.withValues(
                      alpha: 0.55,
                    ),
                    borderRadius: AppRadii.borderMd,
                    border: Border.all(color: context.palette.outlineSoft),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.sm,
                      AppSpacing.xs,
                      AppSpacing.xs,
                      AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(country.isoCode, style: context.text.labelMedium),
                        Icon(
                          AppIcons.expandMore,
                          size: AppSizes.iconSm,
                          color: colors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.gapSm,
                Text(
                  country.dialCode,
                  style: context.text.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AppSpacing.gapSm,
                SizedBox(
                  width: 1,
                  height: AppSizes.iconLg,
                  child: ColoredBox(color: context.palette.outlineSoft),
                ),
                AppSpacing.gapMd,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the searchable country list. Resolves to the chosen country, or
/// `null` if dismissed.
Future<Country?> showCountryPicker(
  BuildContext context, {
  required Country selected,
  List<Country> countries = Country.all,
}) {
  return showAppBottomSheet<Country>(
    context,
    title: 'Select country',
    builder: (_) => _CountryList(selected: selected, countries: countries),
  );
}

class _CountryList extends StatefulWidget {
  const _CountryList({required this.selected, required this.countries});

  final Country selected;
  final List<Country> countries;

  @override
  State<_CountryList> createState() => _CountryListState();
}

class _CountryListState extends State<_CountryList> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Country> get _matches {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.countries;
    return widget.countries
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.isoCode.toLowerCase() == q ||
              c.dialCode.contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Search country',
          controller: _query,
          prefixIcon: AppIcons.search,
          textInputAction: TextInputAction.search,
          onChanged: (_) => setState(() {}),
        ),
        AppSpacing.gapMd,
        SizedBox(
          height: 300,
          child: matches.isEmpty
              ? Center(
                  child: Text(
                    'No countries match "${_query.text.trim()}".',
                    style: context.text.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: matches.length,
                  itemBuilder: (context, i) {
                    final country = matches[i];
                    final isSelected = country == widget.selected;
                    return Semantics(
                      button: true,
                      selected: isSelected,
                      excludeSemantics: true,
                      label: '${country.name}, ${country.dialCode}',
                      onTap: () => Navigator.of(context).pop(country),
                      child: InkWell(
                        borderRadius: AppRadii.borderMd,
                        onTap: () => Navigator.of(context).pop(country),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppSizes.menuTileMinHeight,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: AppSizes.avatarSm - 4,
                                  child: Text(
                                    country.isoCode,
                                    style: context.text.labelMedium?.copyWith(
                                      color: context.palette.textMuted,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    country.name,
                                    style: context.text.bodyLarge,
                                  ),
                                ),
                                Text(
                                  country.dialCode,
                                  style: context.text.bodyMedium,
                                ),
                                SizedBox(
                                  width: AppSizes.iconLg + AppSpacing.sm,
                                  child: isSelected
                                      ? Icon(
                                          AppIcons.check,
                                          size: AppSizes.iconMd,
                                          color: context.colors.primary,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
