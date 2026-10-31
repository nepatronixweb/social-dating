import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../data/models/safety_report.dart';
import '../../../data/repositories/repository_providers.dart';

class ReportSubmittedScreen extends ConsumerWidget {
  const ReportSubmittedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(lastSafetyReportProvider);

    return AppPage(
      appBar: const AppTopBar(title: 'Report saved'),
      bottomBar: Padding(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        child: ConstrainedContent(
          child: AppButton(
            label: 'Back to safety',
            onPressed: () => context.go(AppRoutes.safety),
          ),
        ),
      ),
      body: AsyncValueView<SafetyReport?>(
        value: report,
        onRetry: () => ref.invalidate(lastSafetyReportProvider),
        isEmpty: (value) => value == null,
        empty: const EmptyState(
          icon: AppIcons.report,
          title: 'No report on this device',
          message: 'Submit a report from Safety to see it here.',
        ),
        data: (value) {
          final item = value!;
          return SingleChildScrollView(
            child: ConstrainedContent(
              child: Padding(
                padding: AppSpacing.pagePadding.copyWith(
                  top: AppSpacing.xl,
                  bottom: AppSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InlineMessage(
                      tone: InlineMessageTone.success,
                      icon: AppIcons.check,
                      title: 'Report saved',
                      message:
                          'We received your report. You can return to Safety '
                          'at any time.',
                    ),
                    AppSpacing.gapXl,
                    Text('Report id', style: context.text.titleMedium),
                    AppSpacing.gapXs,
                    Text(item.id, style: context.text.bodyLarge),
                    AppSpacing.gapLg,
                    Text('Category', style: context.text.titleMedium),
                    AppSpacing.gapXs,
                    Text(item.category, style: context.text.bodyLarge),
                    if (item.subjectName != null) ...[
                      AppSpacing.gapLg,
                      Text('About', style: context.text.titleMedium),
                      AppSpacing.gapXs,
                      Text(item.subjectName!, style: context.text.bodyLarge),
                    ],
                    if (item.details.isNotEmpty) ...[
                      AppSpacing.gapLg,
                      Text('Details', style: context.text.titleMedium),
                      AppSpacing.gapXs,
                      Text(item.details, style: context.text.bodyLarge),
                    ],
                    AppSpacing.gapLg,
                    Text(
                      item.attachmentAsset == null
                          ? 'No sample photo attached.'
                          : 'A sample photo was attached on this device. '
                                'Nothing was uploaded.',
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                    AppSpacing.gapXl,
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

final lastSafetyReportProvider = FutureProvider.autoDispose<SafetyReport?>(
  (ref) => ref.watch(settingsRepositoryProvider).lastReport(),
  retry: (_, _) => null,
);
