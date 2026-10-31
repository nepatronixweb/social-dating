import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../matches/providers/matches_providers.dart';

class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen> {
  final Set<String> _busy = {};

  Future<void> _unblock(Profile profile) async {
    if (_busy.contains(profile.id)) return;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Unblock ${profile.displayName}?',
      message:
          'They may appear in discovery again if you have not already '
          'swiped them.',
      confirmLabel: 'Unblock',
    );
    if (!confirmed || !mounted) return;
    setState(() => _busy.add(profile.id));
    try {
      await ref.read(matchingRepositoryProvider).unblock(profile.id);
      ref.read(matchingRevisionProvider.notifier).bump();
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _busy.remove(profile.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked = ref.watch(blockedUsersProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Blocked users'),
      body: AsyncValueView<List<Profile>>(
        value: blocked,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(blockedUsersProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.block,
          title: 'No blocked users',
          message: 'People you block will appear here.',
        ),
        data: (list) => ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(
            indent: AppSpacing.pageGutter,
            endIndent: AppSpacing.pageGutter,
          ),
          itemBuilder: (context, i) {
            final person = list[i];
            final busy = _busy.contains(person.id);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pageGutter,
              ),
              leading: ProfileAvatar(
                name: person.displayName,
                size: 44,
                image: profileImageProvider(person.photos.firstOrNull),
              ),
              title: Text(person.displayName),
              subtitle: Text(person.city, style: context.text.bodySmall),
              trailing: TextButton(
                onPressed: busy ? null : () => _unblock(person),
                child: const Text('Unblock'),
              ),
            );
          },
        ),
      ),
    );
  }
}
