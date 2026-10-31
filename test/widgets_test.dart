import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_dating/core/errors/app_failure.dart';
import 'package:social_dating/core/theme/app_theme.dart';
import 'package:social_dating/core/widgets/app_bottom_sheet.dart';
import 'package:social_dating/core/widgets/app_button.dart';
import 'package:social_dating/core/widgets/app_text_field.dart';
import 'package:social_dating/core/widgets/async_value_view.dart';
import 'package:social_dating/core/widgets/confirmation_dialog.dart';
import 'package:social_dating/core/widgets/empty_state.dart';
import 'package:social_dating/core/widgets/error_state.dart';
import 'package:social_dating/core/widgets/image_card.dart';
import 'package:social_dating/core/widgets/loading_indicator.dart';
import 'package:social_dating/core/widgets/profile_avatar.dart';
import 'package:social_dating/core/widgets/section_header.dart';

import 'helpers/pump_app.dart';

void main() {
  group('AppButton', () {
    testWidgets('invokes onPressed when tapped', (tester) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        AppButton(label: 'Go', onPressed: () => taps++),
      );
      await tester.tap(find.text('Go'));
      expect(taps, 1);
    });

    testWidgets('does nothing when disabled', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const AppButton(label: 'Go', onPressed: null),
      );
      await tester.tap(find.text('Go'), warnIfMissed: false);
      expect(
        tester.getSemantics(find.byType(AppButton)).flagsCollection.isEnabled,
        isFalse,
      );
    });

    testWidgets('ignores taps while loading and shows a spinner', (
      tester,
    ) async {
      var taps = 0;
      await pumpWidgetInTheme(
        tester,
        AppButton(label: 'Go', isLoading: true, onPressed: () => taps++),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton), warnIfMissed: false);
      expect(taps, 0);
    });

    testWidgets('meets the 48dp minimum touch target', (tester) async {
      await pumpWidgetInTheme(
        tester,
        AppButton(label: 'Go', expand: false, onPressed: () {}),
      );
      final size = tester.getSize(find.byType(AppButton));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(size.width, greaterThanOrEqualTo(48));
    });

    testWidgets('renders every variant in light and dark', (tester) async {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        await pumpWidgetInTheme(
          tester,
          Column(
            children: [
              for (final v in AppButtonVariant.values)
                AppButton(label: v.name, variant: v, onPressed: () {}),
            ],
          ),
          theme: theme,
        );
        for (final v in AppButtonVariant.values) {
          expect(find.text(v.name), findsOneWidget);
        }
      }
    });
  });

  group('AppTextField', () {
    testWidgets('shows label and accepts input', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpWidgetInTheme(
        tester,
        AppTextField(label: 'Email', controller: controller),
      );
      expect(find.text('Email'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'a@b.co');
      expect(controller.text, 'a@b.co');
    });

    testWidgets('password field toggles visibility', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const AppTextField(label: 'Password', obscureText: true),
      );
      TextField field() => tester.widget<TextField>(find.byType(TextField));
      expect(field().obscureText, isTrue);

      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(field().obscureText, isFalse);
      expect(find.byTooltip('Hide password'), findsOneWidget);
    });

    testWidgets('displays error text', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const AppTextField(label: 'Name', errorText: 'Required'),
      );
      expect(find.text('Required'), findsOneWidget);
    });
  });

  group('ProfileAvatar', () {
    test('computes initials', () {
      expect(ProfileAvatar.initialsOf('Avery Sample'), 'AS');
      expect(ProfileAvatar.initialsOf('  riley  '), 'R');
      expect(ProfileAvatar.initialsOf('Jo Ann Smith'), 'JS');
      expect(ProfileAvatar.initialsOf(''), '?');
    });

    testWidgets('shows initials, and badges are announced', (tester) async {
      await pumpWidgetInTheme(
        tester,
        const ProfileAvatar(
          name: 'Avery Sample',
          isOnline: true,
          isVerified: true,
        ),
      );
      expect(find.text('AS'), findsOneWidget);
      expect(
        find.bySemanticsLabel('Avery Sample, verified, online'),
        findsOneWidget,
      );
    });
  });

  group('ImageCard', () {
    testWidgets('renders text, handles tap, works without an image', (
      tester,
    ) async {
      var tapped = false;
      await pumpWidgetInTheme(
        tester,
        SizedBox(
          width: 200,
          child: ImageCard(
            title: 'Avery, 28',
            subtitle: 'Mockville',
            onTap: () => tapped = true,
          ),
        ),
      );
      expect(find.text('Avery, 28'), findsOneWidget);
      expect(find.text('Mockville'), findsOneWidget);
      await tester.tap(find.byType(ImageCard));
      expect(tapped, isTrue);
    });
  });

  group('state widgets', () {
    testWidgets('AppLoadingIndicator shows spinner and message', (
      tester,
    ) async {
      await pumpWidgetInTheme(
        tester,
        const AppLoadingIndicator(message: 'Loading people'),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading people'), findsOneWidget);
    });

    testWidgets('EmptyState shows copy and action', (tester) async {
      var pressed = false;
      await pumpWidgetInTheme(
        tester,
        EmptyState(
          title: 'No matches',
          message: 'Keep swiping.',
          actionLabel: 'Discover',
          onAction: () => pressed = true,
        ),
      );
      expect(find.text('No matches'), findsOneWidget);
      await tester.tap(find.text('Discover'));
      expect(pressed, isTrue);
    });

    testWidgets('ErrorState retry callback fires', (tester) async {
      var retried = 0;
      await pumpWidgetInTheme(tester, ErrorState(onRetry: () => retried++));
      await tester.tap(find.text('Try again'));
      expect(retried, 1);
    });

    testWidgets('ErrorState hides retry when no callback is given', (
      tester,
    ) async {
      await pumpWidgetInTheme(tester, const ErrorState());
      expect(find.text('Try again'), findsNothing);
    });

    testWidgets('ErrorState.fromError uses safe user messages', (tester) async {
      await pumpWidgetInTheme(
        tester,
        ErrorState.fromError(StateError('secret internal detail')),
      );
      expect(find.textContaining('secret'), findsNothing);
      expect(find.text('Something went wrong'), findsOneWidget);
    });

    testWidgets('state widgets survive a tiny viewport at 2x text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(240, 300);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await pumpWidgetInTheme(tester, ErrorState(onRetry: () {}));
      expect(tester.takeException(), isNull);
    });
  });

  group('AsyncValueView', () {
    Widget view(AsyncValue<List<int>> v) => AsyncValueView<List<int>>(
      value: v,
      isEmpty: (d) => d.isEmpty,
      onRetry: () {},
      data: (d) => Text('count ${d.length}'),
    );

    testWidgets('loading', (tester) async {
      await pumpWidgetInTheme(tester, view(const AsyncLoading()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('data', (tester) async {
      await pumpWidgetInTheme(tester, view(const AsyncData([1, 2])));
      expect(find.text('count 2'), findsOneWidget);
    });

    testWidgets('empty', (tester) async {
      await pumpWidgetInTheme(tester, view(const AsyncData([])));
      expect(find.text('Nothing here yet'), findsOneWidget);
    });

    testWidgets('error', (tester) async {
      await pumpWidgetInTheme(
        tester,
        view(AsyncError(const NetworkFailure(), StackTrace.empty)),
      );
      expect(find.text('You\'re offline'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('dialogs and sheets', () {
    Future<void> openDialog(WidgetTester tester, void Function(bool) onResult) {
      return pumpWidgetInTheme(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await showConfirmationDialog(
                context,
                title: 'Delete?',
                message: 'This cannot be undone.',
                confirmLabel: 'Delete',
                isDestructive: true,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
    }

    testWidgets('confirm resolves true', (tester) async {
      bool? result;
      await openDialog(tester, (r) => result = r);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Delete?'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('cancel resolves false', (tester) async {
      bool? result;
      await openDialog(tester, (r) => result = r);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('dismissing by tapping the barrier resolves false', (
      tester,
    ) async {
      bool? result;
      await openDialog(tester, (r) => result = r);
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(2, 2));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets(
      'bottom sheet shows title and content, and lifts above keyboard',
      (tester) async {
        await pumpWidgetInTheme(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showAppBottomSheet<void>(
                context,
                title: 'Filters',
                builder: (_) => const AppTextField(label: 'Search'),
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('Filters'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);

        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final bottom = tester.getBottomLeft(find.byType(AppTextField)).dy;
        final screenBottom = tester.view.physicalSize.height;
        expect(bottom, lessThanOrEqualTo(screenBottom - 300));
      },
    );
  });

  group('SectionHeader', () {
    testWidgets('shows title and action', (tester) async {
      var pressed = false;
      await pumpWidgetInTheme(
        tester,
        SectionHeader(
          title: 'New matches',
          actionLabel: 'See all',
          onAction: () => pressed = true,
        ),
      );
      expect(find.text('New matches'), findsOneWidget);
      await tester.tap(find.text('See all'));
      expect(pressed, isTrue);
    });
  });

  group('AppFailure.from', () {
    DioException dio(DioExceptionType type, {int? status}) => DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: type,
      response: status == null
          ? null
          : Response(
              requestOptions: RequestOptions(path: '/x'),
              statusCode: status,
            ),
    );

    test('maps Dio errors to user-safe failures', () {
      expect(
        AppFailure.from(dio(DioExceptionType.connectionTimeout)),
        isA<NetworkFailure>(),
      );
      expect(
        AppFailure.from(dio(DioExceptionType.badResponse, status: 401)),
        isA<UnauthorizedFailure>(),
      );
      expect(
        AppFailure.from(dio(DioExceptionType.badResponse, status: 500)),
        isA<ServerFailure>(),
      );
      expect(AppFailure.from(Exception('boom')), isA<UnknownFailure>());
    });
  });
}
