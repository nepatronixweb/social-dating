import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/chat.dart';
import '../../../data/realtime/chat_hub_client.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../../data/services/service_providers.dart';
import '../../auth/providers/session_provider.dart';
import '../../matches/providers/matches_providers.dart';

class ChatTyping extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void set(String conversationId, {required bool typing}) {
    if (typing) {
      if (state.contains(conversationId)) return;
      state = {...state, conversationId};
    } else {
      if (!state.contains(conversationId)) return;
      state = {...state}..remove(conversationId);
    }
  }
}

final chatTypingProvider = NotifierProvider<ChatTyping, Set<String>>(
  ChatTyping.new,
);

/// Starts the live chat hub in API mode. Mock builds never open a socket.
final chatHubControllerProvider = Provider<ChatHubClient>((ref) {
  final client = ChatHubClient.fromConfig(
    readAccessToken: () => ref.read(tokenStorageProvider).readAccessToken(),
    onEvent: (event) {
      switch (event.type) {
        case 'typing':
          ref
              .read(chatTypingProvider.notifier)
              .set(event.conversationId, typing: event.typing ?? false);
        case 'message':
        case 'read':
        case 'closed':
          ref.read(matchingRevisionProvider.notifier).bump();
          ref
              .read(chatTypingProvider.notifier)
              .set(event.conversationId, typing: false);
      }
    },
  );
  ref.listen(sessionProvider, (_, next) {
    if (next.isLoggedIn) {
      client.start();
    } else {
      client.stop();
    }
  });
  if (ref.read(sessionProvider).isLoggedIn) {
    client.start();
  }
  ref.onDispose(client.stop);
  return client;
});

/// Not auto-disposed: the bottom navigation badge reads it from every tab.
final chatPreviewsProvider = FutureProvider<List<ChatPreview>>((ref) {
  ref.watch(matchingRevisionProvider);
  return ref.watch(chatRepositoryProvider).fetchPreviews();
}, retry: (_, _) => null);

final chatMessagesProvider = FutureProvider.autoDispose
    .family<List<ChatMessage>, String>((ref, chatId) {
      ref.watch(matchingRevisionProvider);
      return ref.watch(chatRepositoryProvider).fetchMessages(chatId);
    }, retry: (_, _) => null);

List<ChatPreview> applyLiveTyping(List<ChatPreview> list, Set<String> typing) {
  if (typing.isEmpty) return list;
  return [
    for (final preview in list)
      preview.copyWith(
        isTyping: preview.isTyping || typing.contains(preview.id),
      ),
  ];
}

/// Total unread messages (0 while loading or on failure).
///
/// A plain function, used with `chatPreviewsProvider.select` in widgets. It is
/// deliberately not a provider: a provider derived from another provider that
/// refreshes while its screen is covered re-schedules itself during build when
/// the screen is uncovered again.
int unreadCountOf(AsyncValue<List<ChatPreview>> previews) => previews.maybeWhen(
  data: (list) => list.fold(0, (sum, c) => sum + c.unreadCount),
  orElse: () => 0,
);
