import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config/integration_config.dart';
import '../core/errors/app_error_handler.dart';
import '../data/services/service_providers.dart';
import 'app.dart';

/// App entry sequence. Only local work happens here (error handlers and
/// reading SharedPreferences from disk): no network calls at startup.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppErrorHandler.install();
  IntegrationConfig.assertSafeDataSource();

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SocialDatingApp(),
    ),
  );
}
