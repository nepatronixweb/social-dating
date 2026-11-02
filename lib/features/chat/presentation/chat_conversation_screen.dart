import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/message_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/clock_provider.dart';
import '../../../core/utils/media_url.dart';
import '../../../core/utils/connectivity_provider.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/chat_bubble.dart';
import '../../../core/widgets/chat_date_separator.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/profile_avatar.dart';
import '../../../core/widgets/skeleton_layouts.dart';
import '../../../core/widgets/typing_indicator.dart';
import '../../../data/models/chat.dart';
import '../../../data/models/match.dart';
import '../../../data/models/profile.dart';
import '../../../data/repositories/repository_contracts.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';
import '../../matches/presentation/match_dialogs.dart';
import '../../matches/providers/matches_providers.dart';
import '../../wallet/providers/wallet_providers.dart';
import '../providers/chat_providers.dart';
import 'widgets/chat_composer.dart';
import 'widgets/conversation_menu.dart';
import 'widgets/insufficient_message_balance_dialog.dart';

/// A conversation. It exists only while its match does: unmatching or
/// blocking closes it. Word-fee previews are not charges; paid sends stay
/// refused until a wallet exists.
class ChatConversationScreen extends ConsumerStatefulWidget {
  const ChatConversationScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatConversationScreen> createState() =>
      _ChatConversationScreenState();
}

class _ChatConversationScreenState
    extends ConsumerState<ChatConversationScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  bool _showJump = false;
  bool _markedRead = false;
  bool _toldTyping = false;
  String? _imageAsset;
  String? _imageId;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDraftChanged);
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  @override
  void deactivate() {
    if (_toldTyping) {
      _toldTyping = false;
      ref
          .read(chatHubControllerProvider)
          .setTyping(widget.chatId, typing: false);
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onDraftChanged)
      ..dispose();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onDraftChanged() {
    setState(() {});
    _setTyping(_controller.text.trim().isNotEmpty);
  }

  void _setTyping(bool typing) {
    if (_toldTyping == typing) return;
    _toldTyping = typing;
    ref
        .read(chatHubControllerProvider)
        .setTyping(widget.chatId, typing: typing);
  }

  void _onScroll() {
    final show = _scroll.hasClients && _scroll.offset > 120;
    if (show != _showJump) setState(() => _showJump = show);
  }

  void _jumpToLatest() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: AppMotion.resolve(context, AppMotion.fast),
      curve: AppMotion.standard,
    );
  }

  Future<void> _markRead() async {
    if (_markedRead) return;
    _markedRead = true;
    try {
      await ref.read(chatRepositoryProvider).markRead(widget.chatId);
      if (mounted) ref.read(matchingRevisionProvider.notifier).bump();
    } catch (_) {
      _markedRead = false;
    }
  }

  Future<void> _send({ChatMessage? retry, bool? confirmedPaid}) async {
    if (_sending) return;
    final offline = ref.read(isOfflineProvider);
    if (offline) {
      setState(
        () => _sendError =
            'You\'re offline. Messages cannot be sent until you are back.',
      );
      return;
    }

    final text = retry?.text ?? _controller.text.trim();
    final image = retry?.imageAsset ?? _imageId ?? _imageAsset;
    if (text.isEmpty && image == null) return;

    _sending = true;
    setState(() => _sendError = null);

    final repo = ref.read(chatRepositoryProvider);
    final quote = repo.quote(text);
    if (confirmedPaid != true) {
      if (quote.tooLong) {
        setState(() {
          _sending = false;
          _sendError =
              'Keep it under ${MessageRules.maxCharacters} characters.';
        });
        return;
      }

      if (quote.isPaid) {
        if (repo.mockBalancePaisa < quote.costPaisa) {
          setState(() => _sending = false);
          final openWallet = await showInsufficientMessageBalanceDialog(
            context,
            quote: quote,
            balancePaisa: repo.mockBalancePaisa,
          );
          if (openWallet && mounted) context.push(AppRoutes.wallet);
          return;
        }
        // Word fee is deducted on send without a confirmation sheet.
      }
    }

    final revision = ref.read(matchingRevisionProvider.notifier);
    try {
      final outcome = await repo.sendMessage(
        widget.chatId,
        text,
        confirmedPaid: confirmedPaid ?? quote.isPaid,
        imageAsset: retry == null ? image : null,
        retryOfId: retry?.id,
      );
      if (!mounted) return;
      if (!outcome.recorded) {
        setState(() => _sending = false);
        await _handleRejection(outcome);
        return;
      }
      setState(() {
        _sending = false;
        if (retry == null) {
          _controller.clear();
          _imageAsset = null;
          _imageId = null;
        }
      });
      revision.bump();
      ref.read(walletRevisionProvider.notifier).bump();
      _jumpToLatest();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _sendError = AppFailure.from(error).message;
        if (retry == null) {
          _controller.clear();
          _imageAsset = null;
          _imageId = null;
        }
      });
      revision.bump();
      showAppSnackBar(
        context,
        'Message not sent. ${AppFailure.from(error).message}',
        type: AppSnackType.error,
      );
      if (AppFailure.from(error) is NotFoundFailure) {
        // Closed while sending: list and this screen refresh together.
      }
    }
  }

  Future<void> _handleRejection(SendOutcome outcome) async {
    switch (outcome.rejection) {
      case MessageRejection.insufficientFunds:
        final quote = outcome.quote;
        if (quote == null) return;
        final openWallet = await showInsufficientMessageBalanceDialog(
          context,
          quote: quote,
          balancePaisa: outcome.balancePaisa,
        );
        if (openWallet && mounted) context.push(AppRoutes.wallet);
      case MessageRejection.paymentRequired:
        final quote = outcome.quote;
        if (quote == null || !quote.isPaid) {
          setState(
            () => _sendError = 'Could not send this paid message.',
          );
          return;
        }
        if (mounted) await _send(confirmedPaid: true);
      case MessageRejection.tooLong:
        setState(
          () => _sendError =
              'Keep it under ${MessageRules.maxCharacters} characters.',
        );
      case MessageRejection.empty:
      case null:
        break;
    }
  }

  Future<void> _attach() async {
    final repo = ref.read(chatRepositoryProvider);
    if (repo.attachFromDevice) {
      await _attachFromDevice(repo);
      return;
    }
    final path = await showAppBottomSheet<String>(
      context,
      title: 'Sample photos',
      builder: (sheetContext) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final asset in MessageRules.sampleAttachmentAssets)
            Semantics(
              button: true,
              label: 'Sample photo',
              child: InkWell(
                onTap: () => Navigator.of(sheetContext).pop(asset),
                child: ClipRRect(
                  borderRadius: AppRadii.borderMd,
                  child: Image.asset(
                    asset,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => SizedBox(
                      width: 88,
                      height: 88,
                      child: ColoredBox(
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(AppIcons.image),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (path != null && mounted) {
      setState(() {
        _imageAsset = path;
        _imageId = null;
      });
    }
  }

  Future<void> _attachFromDevice(ChatRepository repo) async {
    if (_sending) return;
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    setState(() => _sending = true);
    try {
      final bytes = await picked.readAsBytes();
      final photo = await repo.uploadChatPhoto(
        widget.chatId,
        bytes: bytes,
        filename: picked.name,
        contentType: picked.mimeType,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _imageId = photo.id;
        _imageAsset = photo.source;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _openMenu({required Match? match, required bool muted}) async {
    final action = await showConversationMenu(
      context,
      muted: muted,
      hasMatch: match != null,
    );
    if (action == null || !mounted) return;
    final repo = ref.read(chatRepositoryProvider);
    final revision = ref.read(matchingRevisionProvider.notifier);
    switch (action) {
      case ConversationMenuAction.mute:
      case ConversationMenuAction.unmute:
        await repo.setMuted(
          widget.chatId,
          muted: action == ConversationMenuAction.mute,
        );
        revision.bump();
        if (!mounted) return;
        showAppSnackBar(
          context,
          action == ConversationMenuAction.mute
              ? 'Conversation muted.'
              : 'Conversation unmuted.',
        );
      case ConversationMenuAction.hide:
        final confirmed = await showConfirmationDialog(
          context,
          title: 'Hide this conversation?',
          message:
              'It will leave the Messages list. You will still be matched.',
          confirmLabel: 'Hide',
          cancelLabel: 'Keep',
        );
        if (!confirmed || !mounted) return;
        await repo.hideConversation(widget.chatId);
        revision.bump();
        if (!mounted) return;
        showAppSnackBar(context, 'Conversation hidden.');
        context.go(AppRoutes.chat);
      case ConversationMenuAction.report:
        context.push(
          AppRoutes.reportUser(
            name: match?.profile.displayName,
            accountId: match?.profile.id,
          ),
        );
      case ConversationMenuAction.unmatch:
        if (match == null) return;
        if (!await confirmUnmatch(context, match.profile) || !mounted) return;
        try {
          await ref.read(matchingRepositoryProvider).unmatch(match.id);
          revision.bump();
          if (!mounted) return;
          showAppSnackBar(
            context,
            'You unmatched ${match.profile.displayName.split(' ').first}.',
          );
          context.go(AppRoutes.chat);
        } catch (error) {
          if (!mounted) return;
          showAppSnackBar(
            context,
            AppFailure.from(error).message,
            type: AppSnackType.error,
          );
        }
      case ConversationMenuAction.block:
        if (match == null) return;
        if (!await confirmBlock(context, match.profile) || !mounted) return;
        try {
          await ref.read(matchingRepositoryProvider).block(match.profile.id);
          revision.bump();
          if (!mounted) return;
          showAppSnackBar(
            context,
            '${match.profile.displayName.split(' ').first} is blocked.',
          );
          context.go(AppRoutes.chat);
        } catch (error) {
          if (!mounted) return;
          showAppSnackBar(
            context,
            AppFailure.from(error).message,
            type: AppSnackType.error,
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final match = ref
        .watch(matchesProvider)
        .value
        ?.where((m) => m.chatId == widget.chatId)
        .firstOrNull;
    final previews = ref.watch(chatPreviewsProvider).value;
    final preview = previews?.where((p) => p.id == widget.chatId).firstOrNull;
    final profile = match?.profile ?? preview?.profile;
    final title = profile?.displayName;
    final muted = preview?.muted ?? false;
    final liveTyping = ref.watch(
      chatTypingProvider.select((ids) => ids.contains(widget.chatId)),
    );
    final typing = liveTyping || (preview?.isTyping ?? false);
    final offline = ref.watch(isOfflineProvider);
    final quote = ref.read(chatRepositoryProvider).quote(_controller.text);
    final viewerGender = ref.watch(sessionProvider.select((s) => s.gender));
    final peerPoints = profile?.spendablePoints;
    final showPeerPoints =
        viewerGender != null &&
        viewerGender.canWithdrawAndSetDailyPreference &&
        profile?.gender == ProfileGender.male &&
        peerPoints != null;

    final error = messages.error;
    final failure = error is NotFoundFailure ? error : null;
    final closed = failure != null;
    final photos = profile?.photos ?? const <String>[];

    return AppPage(
      appBar: AppTopBar(
        title: title ?? 'Chat',
        titleWidget: title == null
            ? null
            : _HeaderTitle(
                name: title,
                image: profileImageProvider(photos.firstOrNull),
                pointsLabel: showPeerPoints
                    ? formatPointsDecimal(peerPoints)
                    : null,
                onTap: match == null
                    ? null
                    : () => context.push(AppRoutes.matchDetail(match.id)),
              ),
        actions: [
          if (match != null)
            IconButton(
              tooltip: 'Match details',
              icon: const Icon(AppIcons.profile),
              onPressed: () => context.push(AppRoutes.matchDetail(match.id)),
            ),
          IconButton(
            tooltip: 'Conversation options',
            icon: const Icon(AppIcons.more),
            onPressed: closed
                ? null
                : () => _openMenu(match: match, muted: muted),
          ),
        ],
      ),
      floatingActionButton: _showJump && !closed
          ? FloatingActionButton.small(
              tooltip: 'Jump to latest',
              onPressed: _jumpToLatest,
              child: const Icon(AppIcons.arrowDown),
            )
          : null,
      bottomBar: closed
          ? null
          : ChatComposer(
              controller: _controller,
              sending: _sending,
              offline: offline,
              quote: quote,
              imageAsset: _imageAsset,
              sendError: _sendError,
              attachTooltip: ref.read(chatRepositoryProvider).attachFromDevice
                  ? 'Attach photo'
                  : 'Attach sample photo',
              onSend: _send,
              onAttach: _attach,
              onClearImage: () => setState(() {
                _imageAsset = null;
                _imageId = null;
              }),
            ),
      body: closed
          ? EmptyState(
              icon: AppIcons.chat,
              title: 'Conversation closed',
              message: failure.message,
              actionLabel: 'Back to chats',
              onAction: () => context.go(AppRoutes.chat),
            )
          : AsyncValueView<List<ChatMessage>>(
              value: messages,
              keepDataWhileReloading: true,
              loading: const SkeletonList(itemCount: 4),
              onRetry: () =>
                  ref.invalidate(chatMessagesProvider(widget.chatId)),
              isEmpty: (list) => list.isEmpty && !typing,
              empty: const EmptyState(
                icon: AppIcons.chat,
                title: 'Say hello',
                message: 'Start the conversation with something thoughtful.',
              ),
              data: (history) {
                final rows = _rows(history, typing: typing);
                return ConstrainedContent(
                  child: ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: AppSpacing.pagePadding.copyWith(
                      top: AppSpacing.lg,
                      bottom: AppSpacing.lg,
                    ),
                    itemCount: rows.length,
                    itemBuilder: (context, i) => rows[i].build(
                      context,
                      now: ref.watch(clockProvider)(),
                      onRetry: (message) => _send(retry: message),
                    ),
                  ),
                );
              },
            ),
    );
  }

  List<_TranscriptRow> _rows(
    List<ChatMessage> chronological, {
    required bool typing,
  }) {
    final rows = <_TranscriptRow>[];
    DateTime? lastDay;
    for (final message in chronological) {
      final day = DateTime(
        message.sentAt.year,
        message.sentAt.month,
        message.sentAt.day,
      );
      if (lastDay != day) {
        rows.add(_TranscriptRow.day(day));
        lastDay = day;
      }
      rows.add(_TranscriptRow.message(message));
    }
    if (typing) rows.add(const _TranscriptRow.typing());
    return rows.reversed.toList();
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({
    required this.name,
    this.image,
    this.pointsLabel,
    this.onTap,
  });

  final String name;
  final ImageProvider? image;
  final String? pointsLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final points = pointsLabel;
    return Semantics(
      button: onTap != null,
      label: points == null
          ? 'Open profile for $name'
          : 'Open profile for $name, $points',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.avatarXs),
        child: Row(
          children: [
            ProfileAvatar(name: name, image: image, size: AppSizes.avatarXs),
            AppSpacing.gapSm,
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  if (points != null)
                    Text(
                      points,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TranscriptRow {
  const _TranscriptRow.message(this.message) : day = null, typing = false;

  const _TranscriptRow.day(this.day) : message = null, typing = false;

  const _TranscriptRow.typing() : message = null, day = null, typing = true;

  final ChatMessage? message;
  final DateTime? day;
  final bool typing;

  Widget build(
    BuildContext context, {
    required DateTime now,
    required void Function(ChatMessage) onRetry,
  }) {
    if (typing) {
      return const Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.sm),
        child: TypingIndicator(),
      );
    }
    if (day != null) {
      return ChatDateSeparator(at: day!, now: now);
    }
    final item = message!;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: ChatBubble(
        message: item,
        onRetry: item.isFailed ? () => onRetry(item) : null,
      ),
    );
  }
}
