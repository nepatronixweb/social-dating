import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/matching.dart';
import '../../../data/repositories/repository_providers.dart';
import '../providers/matches_providers.dart';

/// Match preferences and the daily match preference.
///
/// The daily preference is what the person would LIKE to see. It is never a
/// guaranteed number of matches, and the screen says so. Eligibility is decided
/// by the repository (the service, later); this screen only reflects it.
class MatchPreferencesScreen extends ConsumerStatefulWidget {
  const MatchPreferencesScreen({super.key});

  @override
  ConsumerState<MatchPreferencesScreen> createState() =>
      _MatchPreferencesScreenState();
}

class _MatchPreferencesScreenState
    extends ConsumerState<MatchPreferencesScreen> {
  MatchPreferences? _baseline;
  MatchPreferences? _draft;
  bool _saving = false;
  String? _error;
  bool _saved = false;

  bool get _dirty => _draft != null && _draft != _baseline;

  void _edit(MatchPreferences next) {
    setState(() {
      _draft = next;
      _saved = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final draft = _draft;
    if (draft == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _saved = false;
    });
    try {
      final result = await ref
          .read(matchingRepositoryProvider)
          .savePreferences(draft);
      if (!mounted) return;
      setState(() {
        _saving = false;
        _baseline = result;
        _draft = result;
        _saved = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = AppFailure.from(error).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(matchPreferencesProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Match preferences'),
      bottomBar: preferences.hasValue
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter,
                vertical: AppSpacing.md,
              ),
              child: AppButton(
                label: 'Save preferences',
                isLoading: _saving,
                onPressed: _dirty ? _save : null,
              ),
            )
          : null,
      body: AsyncValueView<MatchPreferences>(
        value: preferences,
        keepDataWhileReloading: true,
        loading: const SkeletonList(itemCount: 4),
        onRetry: () => ref.invalidate(matchPreferencesProvider),
        data: (loaded) {
          _baseline ??= loaded;
          _draft ??= loaded;
          return _PreferencesForm(
            value: _draft!,
            enabled: !_saving,
            error: _error,
            saved: _saved,
            onChanged: _edit,
          );
        },
      ),
    );
  }
}

class _PreferencesForm extends StatelessWidget {
  const _PreferencesForm({
    required this.value,
    required this.enabled,
    required this.error,
    required this.saved,
    required this.onChanged,
  });

  final MatchPreferences value;
  final bool enabled;
  final String? error;
  final bool saved;
  final ValueChanged<MatchPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final palette = context.palette;

    // The outcome of saving sits above the scrolling form, so it is always in
    // view no matter how far down the person changed something.
    final outcome = <Widget>[
      if (error != null)
        InlineMessage(
          tone: InlineMessageTone.error,
          title: 'Could not save',
          message: error!,
        ),
      if (saved)
        const InlineMessage(
          tone: InlineMessageTone.success,
          title: 'Preferences saved',
          message:
              'Your match preferences have been saved.',
        ),
    ];

    final form = ListView(
      padding: AppSpacing.pagePadding.copyWith(
        top: AppSpacing.sm,
        bottom: AppSpacing.xl,
      ),
      children: [
        Semantics(
          header: true,
          child: Text('Daily match preference', style: text.titleLarge),
        ),
        AppSpacing.gapSm,
        if (value.canSetDailyPreference) ...[
          Text(
            'Choose how many new matches you would like to see each day.',
            style: text.bodyMedium?.copyWith(color: palette.textMuted),
          ),
          AppSpacing.gapMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final option in MatchPreferences.dailyPreferenceOptions)
                ChoiceChip(
                  label: Text('$option per day'),
                  selected: value.dailyMatchPreference == option,
                  onSelected: enabled
                      ? (_) => onChanged(
                          value.copyWith(dailyMatchPreference: option),
                        )
                      : null,
                ),
            ],
          ),
          AppSpacing.gapMd,
          const InlineMessage(
            title: 'A preference, not a promise',
            message:
                'This is the most you would like to receive. You may see '
                'fewer, and no number of matches is guaranteed.',
          ),
          AppSpacing.gapMd,
          _TodayCard(preferences: value),
        ] else
          const InlineMessage(
            title: 'Not available for this account',
            message:
                'Daily match preferences are only offered to eligible '
                'accounts. Your other match settings are below.',
          ),
        AppSpacing.gapXl,
        Semantics(
          header: true,
          child: Text('Match settings', style: text.titleLarge),
        ),
        AppSpacing.gapSm,
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pause new matches'),
          subtitle: const Text(
            'Stop new matches for now. Your current matches stay.',
          ),
          value: value.pauseNewMatches,
          onChanged: enabled
              ? (v) => onChanged(value.copyWith(pauseNewMatches: v))
              : null,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show when I\'m active'),
          subtitle: const Text(
            'Let your matches see "Active now" and when you were last '
            'active.',
          ),
          value: value.showActiveStatus,
          onChanged: enabled
              ? (v) => onChanged(value.copyWith(showActiveStatus: v))
              : null,
        ),
      ],
    );

    if (outcome.isEmpty) return form;
    return Column(
      children: [
        Padding(
          padding: AppSpacing.pagePadding.copyWith(top: AppSpacing.sm),
          child: Column(children: outcome),
        ),
        Expanded(child: form),
      ],
    );
  }
}

/// Shows today's mock count next to the preference, so the two are clearly
/// different things: one is what you asked for, the other is what happened.
class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.preferences});

  final MatchPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.borderLg,
        border: Border.all(color: palette.outlineSoft),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today (sample data)', style: text.titleMedium),
            AppSpacing.gapSm,
            Text(
              'New matches today: ${preferences.newMatchesToday}',
              style: text.bodyMedium,
            ),
            Text(
              'Your preference: up to ${preferences.dailyMatchPreference} '
              'per day',
              style: text.bodyMedium?.copyWith(color: palette.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
