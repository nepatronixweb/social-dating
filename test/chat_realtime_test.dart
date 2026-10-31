import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/data/models/chat.dart';
import 'package:social_dating/data/models/profile.dart';
import 'package:social_dating/data/realtime/chat_hub_client.dart';
import 'package:social_dating/features/chat/providers/chat_providers.dart';

void main() {
  test('applyLiveTyping marks matching conversations', () {
    final preview = ChatPreview(
      id: 'c-1',
      profile: const Profile(
        id: 'p-1',
        displayName: 'Asha',
        age: 28,
        city: 'Kathmandu',
      ),
      lastMessage: 'Hi',
      lastMessageAt: DateTime.utc(2026, 10, 29),
    );
    final live = applyLiveTyping([preview], {'c-1'});
    expect(live.single.isTyping, isTrue);
    expect(applyLiveTyping([preview], const {}).single.isTyping, isFalse);
  });

  test('chat hub client stays idle without networking', () {
    final client = ChatHubClient(
      origin: '',
      enabled: false,
      readAccessToken: () async => null,
      onEvent: (_) {},
    );
    expect(client.isConnected, isFalse);
  });
}
