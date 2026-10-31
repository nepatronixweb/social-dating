import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/utils/time_format.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/interest_chip.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../data/models/app_notification.dart';
import '../../../data/repositories/repository_providers.dart';
import '../providers/notifications_providers.dart';

/// Notification list. Unread items are bold with a dot; tapping marks them
/// read. Mock keeps sample rows; API reads `/v1/notifications`.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _unreadOnly = false;

  Future<void> _markRead(String id) async {
    await ref.read(notificationRepositoryProvider).markRead(id);
    ref.read(notificationRevisionProvider.notifier).bump();
  }

  Future<void> _markAllRead() async {
    await ref.read(notificationRepositoryProvider).markAllRead();
    ref.read(notificationRevisionProvider.notifier).bump();
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);
    final unread = ref.watch(unreadNotificationCountProvider);

    return AppPage(
      appBar: AppTopBar(
        title: 'Notifications',
        actions: [
          if (unread > 0)
            IconButton(
              tooltip: 'Mark all read',
              icon: const Icon(AppIcons.markRead),
              onPressed: _markAllRead,
            ),
          IconButton(
            tooltip: 'Notification preferences',
            icon: const Icon(AppIcons.settings),
            onPressed: () => context.push(AppRoutes.notificationPreferences),
          ),
        ],
      ),
      body: AsyncValueView<List<AppNotification>>(
        value: notifications,
        loading: const SkeletonList(),
        onRetry: () => ref.invalidate(notificationsProvider),
        isEmpty: (list) => list.isEmpty,
        empty: const EmptyState(
          icon: AppIcons.notifications,
          title: 'Nothing new',
          message: 'Matches, messages and updates will appear here.',
        ),
        data: (list) {
          final visible = _unreadOnly
              ? list.where((n) => !n.isRead).toList()
              : list;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.pageGutter,
                  AppSpacing.md,
                  AppSpacing.pageGutter,
                  AppSpacing.sm,
                ),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    InterestChip(
                      label: 'All',
                      selected: !_unreadOnly,
                      onTap: () => setState(() => _unreadOnly = false),
                    ),
                    InterestChip(
                      label: 'Unread',
                      selected: _unreadOnly,
                      onTap: () => setState(() => _unreadOnly = true),
                    ),
                  ],
                ),
              ),
              if (visible.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: AppIcons.notifications,
                    title: 'No unread notifications',
                    message: 'You are up to date.',
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const Divider(
                      indent: AppSpacing.pageGutter,
                      endIndent: AppSpacing.pageGutter,
                    ),
                    itemBuilder: (context, i) => _NotificationTile(
                      item: visible[i],
                      onOpen: () => _markRead(visible[i].id),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onOpen});

  final AppNotification item;
  final VoidCallback onOpen;

  IconData get _icon => switch (item.type) {
    NotificationType.match => AppIcons.matches,
    NotificationType.like => AppIcons.heart,
    NotificationType.message => AppIcons.chat,
    NotificationType.system => AppIcons.info,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label:
          '${item.isRead ? '' : 'Unread. '}${item.title}. ${item.body} '
          '${relativeTime(item.createdAt)}',
      onTap: onOpen,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pageGutter,
            vertical: AppSpacing.lg,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: AppSizes.avatarXs / 2 + AppSpacing.xs,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  _icon,
                  size: AppSizes.iconMd,
                  color: colors.onPrimaryContainer,
                ),
              ),
              AppSpacing.gapLg,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: item.isRead
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    AppSpacing.gapXs,
                    Text(
                      item.body,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                    AppSpacing.gapXs,
                    Text(
                      relativeTime(item.createdAt),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!item.isRead) ...[
                AppSpacing.gapMd,
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
