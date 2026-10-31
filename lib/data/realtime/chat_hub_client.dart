import 'package:signalr_netcore/signalr_client.dart';

import '../../core/config/integration_config.dart';
import '../api/chat_paths.dart';
import '../dto/chat_dtos.dart';

/// Live chat socket. Connects only when API networking is enabled. REST
/// polling stays the source of truth if the hub is down.
class ChatHubClient {
  ChatHubClient({
    required this.origin,
    required this.enabled,
    required this.readAccessToken,
    required this.onEvent,
  });

  final String origin;
  final bool enabled;
  final Future<String?> Function() readAccessToken;
  final void Function(ChatPushDto event) onEvent;

  HubConnection? _connection;
  bool _starting = false;
  bool _stopped = false;

  bool get isConnected => _connection?.state == HubConnectionState.Connected;

  Future<void> start() async {
    if (!enabled || origin.isEmpty || _starting || isConnected) {
      return;
    }
    _stopped = false;
    _starting = true;
    try {
      final url = Uri.parse(origin).resolve(ChatApiPaths.hub).toString();
      final connection = HubConnectionBuilder()
          .withUrl(
            url,
            options: HttpConnectionOptions(
              accessTokenFactory: () async => await readAccessToken() ?? '',
            ),
          )
          .withAutomaticReconnect()
          .build();
      connection.on('event', (args) {
        if (args == null || args.isEmpty) return;
        try {
          onEvent(ChatPushDto.fromJson(args.first));
        } catch (_) {}
      });
      _connection = connection;
      await connection.start();
    } catch (_) {
      _connection = null;
    } finally {
      _starting = false;
    }
  }

  Future<void> setTyping(String conversationId, {required bool typing}) async {
    final connection = _connection;
    if (connection == null ||
        connection.state != HubConnectionState.Connected) {
      return;
    }
    try {
      await connection.invoke('Typing', args: [conversationId, typing]);
    } catch (_) {}
  }

  Future<void> stop() async {
    _stopped = true;
    final connection = _connection;
    _connection = null;
    if (connection == null) return;
    try {
      await connection.stop();
    } catch (_) {}
  }

  factory ChatHubClient.fromConfig({
    required Future<String?> Function() readAccessToken,
    required void Function(ChatPushDto event) onEvent,
  }) => ChatHubClient(
    origin: IntegrationConfig.apiBaseUrl,
    enabled: IntegrationConfig.networkEnabled,
    readAccessToken: readAccessToken,
    onEvent: onEvent,
  );
}
