import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_dropdown_field.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/date_of_birth_input.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/menu_tile.dart';
import '../personal_info/personal_info_widgets.dart';
import '../personal_info/personal_profile.dart';
import '../personal_info/personal_profile_completion.dart';
import '../personal_info/personal_profile_options.dart';
import '../providers/personal_profile_provider.dart';

/// Editor for one Personal Information section.
class PersonalInfoSectionScreen extends ConsumerStatefulWidget {
  const PersonalInfoSectionScreen({super.key, required this.section});

  final PersonalProfileSection section;

  @override
  ConsumerState<PersonalInfoSectionScreen> createState() =>
      _PersonalInfoSectionScreenState();
}

class _PersonalInfoSectionScreenState
    extends ConsumerState<PersonalInfoSectionScreen> {
  late PersonalProfile _draft;
  bool _saving = false;
  bool _heightInCm = true;
  final _name = TextEditingController();
  final _college = TextEditingController();
  final _company = TextEditingController();
  final _jobTitle = TextEditingController();
  final _height = TextEditingController();
  final _promptAnswers = List<TextEditingController>.generate(
    PersonalProfileOptions.promptSlots,
    (_) => TextEditingController(),
  );
  final _promptKeys = List<String?>.filled(
    PersonalProfileOptions.promptSlots,
    null,
  );

  @override
  void initState() {
    super.initState();
    _draft = ref.read(personalProfileViewProvider);
    _syncControllers();
  }

  void _syncControllers() {
    _name.text = _draft.fullName ?? '';
    _college.text = _draft.college ?? '';
    _company.text = _draft.company ?? '';
    _jobTitle.text = _draft.jobTitle ?? '';
    if (_draft.heightCm != null) {
      _height.text = _heightInCm
          ? '${_draft.heightCm}'
          : _cmToFeetInches(_draft.heightCm!);
    }
    final prompts = _draft.prompts;
    for (var i = 0; i < PersonalProfileOptions.promptSlots; i++) {
      if (i < prompts.length) {
        _promptKeys[i] = prompts[i].promptKey;
        _promptAnswers[i].text = prompts[i].answer;
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _college.dispose();
    _company.dispose();
    _jobTitle.dispose();
    _height.dispose();
    for (final c in _promptAnswers) {
      c.dispose();
    }
    super.dispose();
  }

  void _edit(PersonalProfile next) => setState(() => _draft = next);

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final heightCm = _parseHeightCm();
      final prompts = <ProfilePromptAnswer>[
        for (var i = 0; i < PersonalProfileOptions.promptSlots; i++)
          if (_promptKeys[i] != null &&
              _promptAnswers[i].text.trim().isNotEmpty)
            ProfilePromptAnswer(
              promptKey: _promptKeys[i]!,
              answer: _promptAnswers[i].text.trim(),
            ),
      ];
      final next = _draft.copyWith(
        fullName: _name.text.trim().isEmpty ? null : _name.text.trim(),
        college: _college.text.trim().isEmpty ? null : _college.text.trim(),
        company: _company.text.trim().isEmpty ? null : _company.text.trim(),
        jobTitle: _jobTitle.text.trim().isEmpty ? null : _jobTitle.text.trim(),
        heightCm: heightCm,
        clearHeight: heightCm == null && _height.text.trim().isEmpty,
        prompts: prompts,
      );
      await ref.read(personalProfileProvider.notifier).save((_) => next);
      if (!mounted) return;
      showAppSnackBar(context, 'Saved');
      context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int? _parseHeightCm() {
    final raw = _height.text.trim();
    if (raw.isEmpty) return null;
    if (_heightInCm) return int.tryParse(raw);
    final match = RegExp(r"^\s*(\d+)\s*'?\s*(\d+)?").firstMatch(raw);
    if (match == null) return int.tryParse(raw);
    final feet = int.tryParse(match.group(1) ?? '') ?? 0;
    final inches = int.tryParse(match.group(2) ?? '0') ?? 0;
    return ((feet * 12 + inches) * 2.54).round();
  }

  String _cmToFeetInches(int cm) {
    final totalInches = (cm / 2.54).round();
    final feet = totalInches ~/ 12;
    final inches = totalInches % 12;
    return "$feet'$inches\"";
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: AppTopBar(title: widget.section.title),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pageGutter,
          AppSpacing.sm,
          AppSpacing.pageGutter,
          AppSpacing.lg,
        ),
        child: AppButton(
          label: 'Save',
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageGutter,
              vertical: AppSpacing.lg,
            ),
            child: switch (widget.section) {
              PersonalProfileSection.basic => _BasicForm(
                draft: _draft,
                name: _name,
                onChanged: _edit,
              ),
              PersonalProfileSection.appearance => _AppearanceForm(
                draft: _draft,
                height: _height,
                heightInCm: _heightInCm,
                onUnitChanged: (cm) => setState(() {
                  final parsed = _parseHeightCm();
                  _heightInCm = cm;
                  if (parsed != null) {
                    _height.text = cm
                        ? '$parsed'
                        : _cmToFeetInches(parsed);
                  }
                }),
                onChanged: _edit,
              ),
              PersonalProfileSection.lifestyle => _LifestyleForm(
                draft: _draft,
                onChanged: _edit,
              ),
              PersonalProfileSection.education => _EducationForm(
                draft: _draft,
                college: _college,
                company: _company,
                jobTitle: _jobTitle,
                onChanged: _edit,
              ),
              PersonalProfileSection.dating => _DatingForm(
                draft: _draft,
                onChanged: _edit,
              ),
              PersonalProfileSection.personality => _PersonalityForm(
                draft: _draft,
                promptKeys: _promptKeys,
                promptAnswers: _promptAnswers,
                onPromptKey: (index, key) =>
                    setState(() => _promptKeys[index] = key),
                onChanged: _edit,
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _BasicForm extends ConsumerWidget {
  const _BasicForm({
    required this.draft,
    required this.name,
    required this.onChanged,
  });

  final PersonalProfile draft;
  final TextEditingController name;
  final ValueChanged<PersonalProfile> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(clockProvider)();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          label: 'Full name',
          controller: name,
          textCapitalization: TextCapitalization.words,
        ),
        AppSpacing.gapLg,
        Text('Date of birth', style: context.text.titleSmall),
        AppSpacing.gapSm,
        if (draft.birthDate != null)
          Text(
            '${draft.birthDate!.year}-'
            '${draft.birthDate!.month.toString().padLeft(2, '0')}-'
            '${draft.birthDate!.day.toString().padLeft(2, '0')}',
            style: context.text.bodyMedium,
          ),
        AppSpacing.gapSm,
        DateOfBirthInput(
          today: today,
          onChanged: (parse) {
            if (parse.isValid && parse.date != null) {
              onChanged(draft.copyWith(birthDate: parse.date));
            }
          },
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Gender',
          options: PersonalProfileOptions.genders,
          selectedId: draft.gender,
          onSelected: (id) => onChanged(draft.copyWith(gender: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Interested in',
          options: PersonalProfileOptions.interestedIn,
          selectedId: draft.interestedIn,
          onSelected: (id) => onChanged(draft.copyWith(interestedIn: id)),
        ),
        AppSpacing.gapLg,
        MenuTile(
          icon: AppIcons.camera,
          title: 'Profile photos',
          subtitle: draft.photoCount >= 2
              ? '${draft.photoCount} photos'
              : 'Upload 2–6 photos',
          onTap: () => context.push(AppRoutes.profilePhotos),
        ),
        AppSpacing.gapLg,
        AppDropdownField<String>(
          label: 'Current city',
          items: PersonalProfileOptions.nepalCities,
          itemLabel: (city) => city,
          value: draft.city,
          hint: 'Select city',
          onChanged: (city) => onChanged(draft.copyWith(city: city)),
        ),
        AppSpacing.gapLg,
        MenuTile(
          icon: AppIcons.phone,
          title: draft.phoneLabel ?? 'Phone number',
          subtitle: 'OTP verified',
          onTap: () => context.push(AppRoutes.changePhone),
        ),
      ],
    );
  }
}

class _AppearanceForm extends StatelessWidget {
  const _AppearanceForm({
    required this.draft,
    required this.height,
    required this.heightInCm,
    required this.onUnitChanged,
    required this.onChanged,
  });

  final PersonalProfile draft;
  final TextEditingController height;
  final bool heightInCm;
  final ValueChanged<bool> onUnitChanged;
  final ValueChanged<PersonalProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MenuTile(
          icon: AppIcons.camera,
          title: 'Photos',
          subtitle: 'Manage your album (2–6 photos)',
          onTap: () => context.push(AppRoutes.profilePhotos),
        ),
        AppSpacing.gapLg,
        Row(
          children: [
            Expanded(
              child: AppTextField(
                label: heightInCm ? 'Height (cm)' : 'Height (ft/in)',
                controller: height,
                keyboardType: TextInputType.text,
                hint: heightInCm ? '170' : "5'7\"",
              ),
            ),
            AppSpacing.gapMd,
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('cm')),
                ButtonSegment(value: false, label: Text('ft')),
              ],
              selected: {heightInCm},
              onSelectionChanged: (set) => onUnitChanged(set.first),
            ),
          ],
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Body type',
          optional: true,
          options: PersonalProfileOptions.bodyTypes,
          selectedId: draft.bodyType,
          onSelected: (id) => onChanged(draft.copyWith(bodyType: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Hair color',
          optional: true,
          options: PersonalProfileOptions.hairColors,
          selectedId: draft.hairColor,
          onSelected: (id) => onChanged(draft.copyWith(hairColor: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Eye color',
          optional: true,
          options: PersonalProfileOptions.eyeColors,
          selectedId: draft.eyeColor,
          onSelected: (id) => onChanged(draft.copyWith(eyeColor: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Fitness lifestyle',
          options: PersonalProfileOptions.fitnessLifestyles,
          selectedId: draft.fitnessLifestyle,
          onSelected: (id) => onChanged(draft.copyWith(fitnessLifestyle: id)),
        ),
      ],
    );
  }
}

class _LifestyleForm extends StatelessWidget {
  const _LifestyleForm({required this.draft, required this.onChanged});

  final PersonalProfile draft;
  final ValueChanged<PersonalProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionChipGroup(
          label: 'Do you drink?',
          options: PersonalProfileOptions.drink,
          selectedId: draft.drink,
          onSelected: (id) => onChanged(draft.copyWith(drink: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Do you smoke?',
          options: PersonalProfileOptions.smoke,
          selectedId: draft.smoke,
          onSelected: (id) => onChanged(draft.copyWith(smoke: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Do you exercise?',
          options: PersonalProfileOptions.exercise,
          selectedId: draft.exercise,
          onSelected: (id) => onChanged(draft.copyWith(exercise: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Food preference',
          options: PersonalProfileOptions.food,
          selectedId: draft.foodPreference,
          onSelected: (id) => onChanged(draft.copyWith(foodPreference: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Pets',
          options: PersonalProfileOptions.pets,
          selectedId: draft.pets,
          onSelected: (id) => onChanged(draft.copyWith(pets: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Sleep schedule',
          options: PersonalProfileOptions.sleep,
          selectedId: draft.sleepSchedule,
          onSelected: (id) => onChanged(draft.copyWith(sleepSchedule: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Social lifestyle',
          options: PersonalProfileOptions.social,
          selectedId: draft.socialLifestyle,
          onSelected: (id) => onChanged(draft.copyWith(socialLifestyle: id)),
        ),
      ],
    );
  }
}

class _EducationForm extends StatelessWidget {
  const _EducationForm({
    required this.draft,
    required this.college,
    required this.company,
    required this.jobTitle,
    required this.onChanged,
  });

  final PersonalProfile draft;
  final TextEditingController college;
  final TextEditingController company;
  final TextEditingController jobTitle;
  final ValueChanged<PersonalProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionChipGroup(
          label: 'Education level',
          options: PersonalProfileOptions.education,
          selectedId: draft.educationLevel,
          onSelected: (id) => onChanged(draft.copyWith(educationLevel: id)),
        ),
        AppSpacing.gapLg,
        AppTextField(
          label: 'College / University',
          controller: college,
          textCapitalization: TextCapitalization.words,
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Profession',
          options: PersonalProfileOptions.professions,
          selectedId: draft.profession,
          onSelected: (id) => onChanged(draft.copyWith(profession: id)),
        ),
        AppSpacing.gapLg,
        AppTextField(
          label: 'Company (optional)',
          controller: company,
          textCapitalization: TextCapitalization.words,
        ),
        AppSpacing.gapLg,
        AppTextField(
          label: 'Job title (optional)',
          controller: jobTitle,
          textCapitalization: TextCapitalization.words,
        ),
        AppSpacing.gapLg,
        MultiOptionChipGroup(
          label: 'Languages spoken',
          options: PersonalProfileOptions.languages,
          selected: draft.languages.toSet(),
          onToggle: (id) {
            final next = {...draft.languages};
            if (!next.remove(id)) next.add(id);
            onChanged(draft.copyWith(languages: next.toList()));
          },
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Income range',
          optional: true,
          options: PersonalProfileOptions.income,
          selectedId: draft.incomeRange,
          onSelected: (id) => onChanged(draft.copyWith(incomeRange: id)),
        ),
      ],
    );
  }
}

class _DatingForm extends StatelessWidget {
  const _DatingForm({required this.draft, required this.onChanged});

  final PersonalProfile draft;
  final ValueChanged<PersonalProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionChipGroup(
          label: 'What are you looking for?',
          options: PersonalProfileOptions.lookingFor,
          selectedId: draft.lookingFor,
          onSelected: (id) => onChanged(draft.copyWith(lookingFor: id)),
        ),
        AppSpacing.gapLg,
        Builder(
          builder: (context) {
            final minAge = draft.preferredAgeMin ?? 18;
            final maxAge = draft.preferredAgeMax ?? 35;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Preferred age range: $minAge–$maxAge',
                  style: context.text.titleSmall,
                ),
                RangeSlider(
                  values: RangeValues(minAge.toDouble(), maxAge.toDouble()),
                  min: 18,
                  max: 100,
                  divisions: 82,
                  labels: RangeLabels('$minAge', '$maxAge'),
                  onChanged: (values) => onChanged(
                    draft.copyWith(
                      preferredAgeMin: values.start.round(),
                      preferredAgeMax: values.end.round(),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        AppSpacing.gapLg,
        Text('Preferred distance', style: context.text.titleSmall),
        AppSpacing.gapSm,
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final km in PersonalProfileOptions.distancesKm)
              InterestChip(
                label: '$km km',
                selected: draft.preferredDistanceKm == km,
                onTap: () =>
                    onChanged(draft.copyWith(preferredDistanceKm: km)),
              ),
          ],
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Preferred location',
          options: PersonalProfileOptions.preferredLocations,
          selectedId: draft.preferredLocation,
          onSelected: (id) => onChanged(draft.copyWith(preferredLocation: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Children preference',
          options: PersonalProfileOptions.children,
          selectedId: draft.childrenPreference,
          onSelected: (id) =>
              onChanged(draft.copyWith(childrenPreference: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Relationship status',
          options: PersonalProfileOptions.relationshipStatus,
          selectedId: draft.relationshipStatus,
          onSelected: (id) =>
              onChanged(draft.copyWith(relationshipStatus: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'How often do you want to meet?',
          options: PersonalProfileOptions.meetFrequency,
          selectedId: draft.meetFrequency,
          onSelected: (id) => onChanged(draft.copyWith(meetFrequency: id)),
        ),
      ],
    );
  }
}

class _PersonalityForm extends StatelessWidget {
  const _PersonalityForm({
    required this.draft,
    required this.promptKeys,
    required this.promptAnswers,
    required this.onPromptKey,
    required this.onChanged,
  });

  final PersonalProfile draft;
  final List<String?> promptKeys;
  final List<TextEditingController> promptAnswers;
  final void Function(int index, String key) onPromptKey;
  final ValueChanged<PersonalProfile> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InterestLabelChipGroup(
          label: 'Interests',
          helper: 'Select at least ${PersonalProfileOptions.minInterests}',
          options: PersonalProfileOptions.interests,
          selected: draft.interests.toSet(),
          onToggle: (label) {
            final next = {...draft.interests};
            if (!next.remove(label)) next.add(label);
            onChanged(draft.copyWith(interests: next.toList()));
          },
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Your personality',
          options: PersonalProfileOptions.personality,
          selectedId: draft.personality,
          onSelected: (id) => onChanged(draft.copyWith(personality: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Perfect weekend',
          options: PersonalProfileOptions.perfectWeekend,
          selectedId: draft.perfectWeekend,
          onSelected: (id) => onChanged(draft.copyWith(perfectWeekend: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Love language',
          options: PersonalProfileOptions.loveLanguage,
          selectedId: draft.loveLanguage,
          onSelected: (id) => onChanged(draft.copyWith(loveLanguage: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Communication style',
          options: PersonalProfileOptions.communication,
          selectedId: draft.communicationStyle,
          onSelected: (id) =>
              onChanged(draft.copyWith(communicationStyle: id)),
        ),
        AppSpacing.gapLg,
        OptionChipGroup(
          label: 'Ideal first date',
          options: PersonalProfileOptions.firstDate,
          selectedId: draft.idealFirstDate,
          onSelected: (id) => onChanged(draft.copyWith(idealFirstDate: id)),
        ),
        AppSpacing.gapXl,
        Text(
          'Profile prompts (answer ${PersonalProfileOptions.promptSlots})',
          style: context.text.titleSmall,
        ),
        AppSpacing.gapMd,
        for (var i = 0; i < PersonalProfileOptions.promptSlots; i++) ...[
          AppDropdownField<String>(
            label: 'Prompt ${i + 1}',
            items: [
              for (final choice in PersonalProfileOptions.promptChoices)
                choice.id,
            ],
            itemLabel: (id) =>
                PersonalProfileOptions.labelOf(
                  PersonalProfileOptions.promptChoices,
                  id,
                ) ??
                id,
            value: promptKeys[i],
            hint: 'Choose a prompt',
            onChanged: (id) => onPromptKey(i, id),
          ),
          AppSpacing.gapSm,
          AppTextField(
            label: 'Your answer',
            controller: promptAnswers[i],
            maxLines: 3,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
          ),
          AppSpacing.gapLg,
        ],
      ],
    );
  }
}
