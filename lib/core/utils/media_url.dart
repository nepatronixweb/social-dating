import 'package:flutter/widgets.dart';

import '../config/integration_config.dart';

/// Turns a media path from the API into an absolute URI using [origin].
///
/// Relative paths (`/v1/media/...`) keep the host out of feature code.
/// Absolute URLs from the server are left unchanged. The origin defaults to
/// the dart-define host and is never compiled in as a fallback.
Uri resolveMediaUrl(String raw, {String? origin}) {
  final parsed = Uri.parse(raw);
  if (parsed.hasScheme) return parsed;
  final base = origin ?? IntegrationConfig.apiBaseUrl;
  if (base.isEmpty) return parsed;
  return Uri.parse(base).resolveUri(parsed);
}

/// [AssetImage] for mock `assets/` paths, [NetworkImage] for signed media.
ImageProvider? profileImageProvider(String? source, {String? origin}) {
  if (source == null || source.isEmpty) return null;
  if (source.startsWith('assets/')) return AssetImage(source);
  final uri = resolveMediaUrl(source, origin: origin);
  if (!uri.hasScheme) return null;
  return NetworkImage('$uri');
}
