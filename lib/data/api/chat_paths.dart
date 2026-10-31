/// Relative paths confirmed by `backend/CONTRACT.md`.
abstract final class ChatApiPaths {
  static const list = '/v1/chats';
  static String messages(String conversationId) =>
      '/v1/chats/$conversationId/messages';
  static String read(String conversationId) => '/v1/chats/$conversationId/read';
  static String mute(String conversationId) => '/v1/chats/$conversationId/mute';
  static String hide(String conversationId) => '/v1/chats/$conversationId/hide';
  static String photos(String conversationId) =>
      '/v1/chats/$conversationId/photos';
  static const hub = '/v1/hubs/chat';
}
