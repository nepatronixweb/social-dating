import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/chat_preview_tile.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/chat.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../matches/providers/matches_providers.dart';
import '../../notifications/presentation/notification_bell.dart';
import '../providers/chat_providers.dart';

/// Chat tab: conversation previews with search, unread badges and hide.
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<ChatPreview> _filter(List<ChatPreview> list) {
    final query = _search.text.trim().toLowerCase();
    if (query.isEmpty) return list;
    return [
      for (final preview in list)
        if (preview.profile.displayName.toLowerCase().contains(query) ||
            preview.lastMessage.toLowerCase().contains(query))
          preview,
    ];
  }

  Future<void> _hide(ChatPreview preview) async {
    final name = preview.profile.displayName.split(' ').first;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Hide this conversation?',
      message: '$name will leave this list. You will still be matched.',
      confirmLabel: 'Hide',
      cancelLabel: 'Keep',
    );
    if (!confirmed || !mounted) return;
    try {
      await ref.read(chatRepositoryProvider).hideConversation(preview.id);
      if (!mounted) return;
      ref.read(matchingRevisionProvider.notifier).bump();
      showAppSnackBar(context, 'Conversation hidden.');
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        'Could not hide this conversation. Try again.',
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final previews = ref.watch(chatPreviewsProvider);
    final typing = ref.watch(chatTypingProvider);

    return AppPage(
      appBar: const AppTopBar(showBrand: true, actions: [NotificationBell()]),
      body: Column(
        children: [
          const ScreenHeader(title: 'Messages'),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageGutter,
              0,
              AppSpacing.pageGutter,
              AppSpacing.md,
            ),
            child: AppTextField(
              label: 'Search conversations',
              controller: _search,
              prefixIcon: AppIcons.search,
              textInputAction: TextInputAction.search,
              hideCounter: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: AsyncValueView<List<ChatPreview>>(
              value: previews,
              loading: const SkeletonList(),
              onRetry: () => ref.invalidate(chatPreviewsProvider),
              isEmpty: (list) => list.isEmpty,
              empty: const EmptyState(
                icon: AppIcons.chat,
                title: 'No conversations yet',
                message: 'Match with someone and say hello.',
              ),
              data: (list) {
                final visible = _filter(applyLiveTyping(list, typing));
                if (visible.isEmpty) {
                  return const EmptyState(
                    icon: AppIcons.search,
                    title: 'No conversations match',
                    message: 'Try a different name or message.',
                  );
                }
                return ListView.separated(
                  itemCount: visible.length,
                  separatorBuilder: (context, _) => Divider(
                    indent:
                        AppSpacing.pageGutter +
                        AppSizes.avatarMd +
                        AppSpacing.lg,
                    endIndent: AppSpacing.pageGutter,
                  ),
                  itemBuilder: (context, i) => ChatPreviewTile(
                    preview: visible[i],
                    onTap: () =>
                        context.push(AppRoutes.chatConversation(visible[i].id)),
                    onLongPress: () => _hide(visible[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
