import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';

import 'empty_state.dart';
import 'error_state.dart';
import 'loading_indicator.dart';

/// Renders an [AsyncValue] with consistent loading, failure and empty states.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
    this.isEmpty,
    this.empty,
    this.loading,
    this.keepDataWhileReloading = false,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// Decides whether loaded data should show the [empty] state.
  final bool Function(T data)? isEmpty;
  final Widget? empty;
  final Widget? loading;

  /// When true, a reload (for example after invalidating a provider following
  /// an edit) keeps showing the previous data instead of a loading state.
  final bool keepDataWhileReloading;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: false,
      skipLoadingOnReload: keepDataWhileReloading,
      loading: () => loading ?? const AppLoadingIndicator(),
      error: (error, _) => ErrorState.fromError(error, onRetry: onRetry),
      data: (d) {
        if (isEmpty?.call(d) ?? false) {
          return empty ??
              const EmptyState(
                title: 'Nothing here yet',
                message: 'Check back soon.',
              );
        }
        return data(d);
      },
    );
  }
}
