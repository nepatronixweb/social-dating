import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/integration_config.dart';
import '../../../core/constants/app_constants.dart';
import '../../../data/api/app_paths.dart';
import '../../../data/models/client_app_config.dart';
import '../../../data/services/service_providers.dart';

/// Fetches public client ops config when networking is enabled.
final clientAppConfigProvider = FutureProvider<ClientAppConfig>((ref) async {
  if (!IntegrationConfig.networkEnabled) {
    return const ClientAppConfig();
  }
  final dio = ref.watch(apiClientProvider).dio;
  final response = await dio.get<dynamic>(AppPaths.clientConfig);
  return ClientAppConfig.fromJson(response.data) ?? const ClientAppConfig();
});

/// True when the running build is below the remote minimum.
bool clientBuildBlocked(ClientAppConfig config) {
  if (config.minClientBuild <= 0) return false;
  return AppConstants.buildNumber < config.minClientBuild;
}
