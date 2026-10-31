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
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../auth/providers/session_provider.dart';

/// Account management: change phone, sign out and delete account.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final phone = session.phoneLabel;

    return AppPage(
      appBar: const AppTopBar(title: 'Account'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSection(
                  title: 'Signed in',
                  child: Column(
                    children: [
                      MenuTile(
                        icon: AppIcons.phone,
                        title: phone ?? 'Phone number',
                        subtitle:
                            'Masked label only. The full number is hidden.',
                      ),
                      MenuTile(
                        icon: AppIcons.edit,
                        title: 'Change phone number',
                        subtitle: 'Update the number on this account',
                        onTap: () => context.push(AppRoutes.changePhone),
                      ),
                    ],
                  ),
                ),
                AppSection(
                  title: 'Session',
                  child: MenuTile(
                    icon: AppIcons.logout,
                    title: 'Sign out',
                    onTap: () async {
                      final confirmed = await showConfirmationDialog(
                        context,
                        title: 'Sign out?',
                        message: 'You can sign back in with your phone number.',
                        confirmLabel: 'Sign out',
                      );
                      if (confirmed) {
                        ref.read(sessionProvider.notifier).signOut();
                      }
                    },
                  ),
                ),
                AppSection(
                  title: 'Danger zone',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MenuTile(
                        icon: AppIcons.delete,
                        title: 'Delete account',
                        destructive: true,
                        onTap: () => context.push(AppRoutes.deleteAccount),
                      ),
                      AppSpacing.gapXs,
                      Text(
                        'Deletion ends this session. Some records may be kept '
                        'under the retention policy.',
                        style: context.text.bodySmall,
                      ),
                    ],
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
