import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/connectivity_provider.dart';
import 'brand_atmosphere.dart';
import 'offline_banner.dart';

/// Standard screen scaffold: top bar, offline banner, safe-area body and an
/// optional pinned bottom action. Every screen should be an [AppPage] so the
/// chrome stays consistent.
class AppPage extends ConsumerWidget {
  const AppPage({
    super.key,
    required this.body,
    this.appBar,
    this.bottomBar,
    this.floatingActionButton,
    this.edgeToEdge = false,
    this.atmosphere,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;

  /// Pinned below the body (e.g. a primary action). It lives inside the
  /// keyboard-resized body, so it always rides above the keyboard.
  final Widget? bottomBar;
  final Widget? floatingActionButton;

  /// Lets the body draw under the status bar (a photo-first screen). The body
  /// is then responsible for keeping its own controls below the status bar.
  final bool edgeToEdge;

  /// Branded corner wash behind the whole page (create-account, splash-like
  /// auth). The scaffold is then transparent so the wash shows through.
  final BrandAtmosphereStyle? atmosphere;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    final banner = OfflineBanner(
      visible: offline,
      onRetry: () => ref.read(isOfflineProvider.notifier).setOffline(false),
    );

    final scaffold = Scaffold(
      backgroundColor: atmosphere == null ? null : Colors.transparent,
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      body: Column(
        children: [
          // Edge to edge, the banner has to clear the status bar itself.
          if (edgeToEdge && offline)
            SafeArea(bottom: false, child: banner)
          else
            banner,
          Expanded(
            child: SafeArea(
              top: false,
              bottom: bottomBar == null,
              child: edgeToEdge && offline
                  ? MediaQuery.removePadding(
                      context: context,
                      removeTop: true,
                      child: body,
                    )
                  : body,
            ),
          ),
          if (bottomBar != null) SafeArea(top: false, child: bottomBar!),
        ],
      ),
    );

    if (atmosphere == null) return scaffold;

    return Stack(
      fit: StackFit.expand,
      children: [
        BrandAtmosphere(style: atmosphere!),
        scaffold,
      ],
    );
  }
}
