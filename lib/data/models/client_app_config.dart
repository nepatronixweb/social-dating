import 'package:flutter/foundation.dart';

/// Public client ops flags from `/v1/app/client-config`.
@immutable
class ClientAppConfig {
  const ClientAppConfig({
    this.maintenanceMode = false,
    this.minClientBuild = 0,
    this.bannerEnabled = false,
    this.bannerTitle,
    this.bannerBody,
  });

  final bool maintenanceMode;
  final int minClientBuild;
  final bool bannerEnabled;
  final String? bannerTitle;
  final String? bannerBody;

  static ClientAppConfig? fromJson(Object? json) {
    if (json is! Map) return null;
    return ClientAppConfig(
      maintenanceMode: json['maintenanceMode'] == true,
      minClientBuild: (json['minClientBuild'] as num?)?.toInt() ?? 0,
      bannerEnabled: json['bannerEnabled'] == true,
      bannerTitle: json['bannerTitle'] is String
          ? json['bannerTitle'] as String
          : null,
      bannerBody: json['bannerBody'] is String
          ? json['bannerBody'] as String
          : null,
    );
  }
}
