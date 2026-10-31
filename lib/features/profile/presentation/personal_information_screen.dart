import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/menu_tile.dart';
import '../personal_info/personal_info_widgets.dart';
import '../personal_info/personal_profile_completion.dart';
import '../providers/personal_profile_provider.dart';

/// Hub for every Personal Information section and completion progress.
class PersonalInformationScreen extends ConsumerWidget {
  const PersonalInformationScreen({super.key});

  IconData _iconFor(PersonalProfileSection section) => switch (section) {
    PersonalProfileSection.basic => AppIcons.account,
    PersonalProfileSection.appearance => AppIcons.camera,
    PersonalProfileSection.lifestyle => AppIcons.bedtime,
    PersonalProfileSection.education => AppIcons.work,
    PersonalProfileSection.dating => AppIcons.heart,
    PersonalProfileSection.personality => AppIcons.star,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = ref.watch(personalProfileCompletionProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Personal Information'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileCompletionCard(completion: completion),
                AppSpacing.gapXl,
                AppSection(
                  title: 'Profile',
                  child: Column(
                    children: [
                      for (final section in PersonalProfileSection.values)
                        MenuTile(
                          icon: _iconFor(section),
                          title: section.title,
                          subtitle:
                              '${completion.sectionPercent(section)}% · '
                              'weight ${section.weight}%',
                          onTap: () => context.push(
                            AppRoutes.personalInfoSection(section.name),
                          ),
                        ),
                    ],
                  ),
                ),
                AppSpacing.gapMd,
                Text(
                  'Safety tools stay available even with an incomplete '
                  'profile. Sensitive fields such as income stay optional.',
                  style: context.text.bodySmall?.copyWith(
                    color: context.palette.textMuted,
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
