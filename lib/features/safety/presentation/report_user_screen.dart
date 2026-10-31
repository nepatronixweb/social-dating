import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/message_rules.dart';
import '../../../core/constants/settings_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/repositories/repository_providers.dart';

class ReportUserScreen extends ConsumerStatefulWidget {
  const ReportUserScreen({super.key, this.subjectName});

  final String? subjectName;

  @override
  ConsumerState<ReportUserScreen> createState() => _ReportUserScreenState();
}

class _ReportUserScreenState extends ConsumerState<ReportUserScreen> {
  String? _category;
  bool _showError = false;
  bool _submitting = false;
  String? _attachment;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final path = await showAppBottomSheet<String>(
      context,
      title: 'Sample photos',
      builder: (sheetContext) => Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: [
          for (final asset in MessageRules.sampleAttachmentAssets)
            Semantics(
              button: true,
              label: 'Sample photo',
              child: InkWell(
                onTap: () => Navigator.of(sheetContext).pop(asset),
                child: ClipRRect(
                  borderRadius: AppRadii.borderMd,
                  child: Image.asset(
                    asset,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => SizedBox(
                      width: 88,
                      height: 88,
                      child: ColoredBox(
                        color: Theme.of(
                          sheetContext,
                        ).colorScheme.surfaceContainerHighest,
                        child: const Icon(AppIcons.image),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
    if (path != null && mounted) setState(() => _attachment = path);
  }

  Future<void> _submit() async {
    if (_category == null) {
      setState(() => _showError = true);
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .submitReport(
            category: _category!,
            details: _details.text,
            attachmentAsset: _attachment,
            subjectName: widget.subjectName,
          );
      if (!mounted) return;
      context.go(AppRoutes.reportSubmitted);
    } catch (error) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.subjectName;

    return AppPage(
      appBar: const AppTopBar(title: 'Report a person'),
      bottomBar: Padding(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        child: ConstrainedContent(
          child: AppButton(
            label: 'Submit report',
            isLoading: _submitting,
            onPressed: _submitting ? null : _submit,
          ),
        ),
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: ConstrainedContent(
          child: SizedBox(
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ScreenHeader(
                  title: name == null ? 'What happened?' : 'Report $name',
                  subtitle:
                      'Choose a category. Details and a sample photo are optional.',
                ),
                Padding(
                  padding: AppSpacing.pagePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _showError
                            ? 'Choose a reason to continue.'
                            : 'Category',
                        style: context.text.bodyMedium?.copyWith(
                          color: _showError
                              ? context.colors.error
                              : context.palette.textMuted,
                        ),
                      ),
                      AppSpacing.gapMd,
                      for (final category in SettingsRules.reportCategories)
                        MenuTile(
                          icon: _category == category
                              ? AppIcons.check
                              : AppIcons.report,
                          title: category,
                          onTap: () => setState(() {
                            _category = category;
                            _showError = false;
                          }),
                        ),
                      AppSpacing.gapLg,
                      AppTextField(
                        controller: _details,
                        label: 'Details (optional)',
                        maxLines: 4,
                        maxLength: 500,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      AppSpacing.gapLg,
                      AppButton(
                        label: _attachment == null
                            ? 'Sample photo'
                            : 'Change photo',
                        icon: AppIcons.attach,
                        variant: AppButtonVariant.outlined,
                        onPressed: _pickAttachment,
                      ),
                      if (_attachment != null) ...[
                        AppSpacing.gapMd,
                        ClipRRect(
                          borderRadius: AppRadii.borderMd,
                          child: Image.asset(
                            _attachment!,
                            height: 120,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => SizedBox(
                              height: 120,
                              child: Center(
                                child: Icon(
                                  AppIcons.image,
                                  color: context.palette.textMuted,
                                ),
                              ),
                            ),
                          ),
                        ),
                        AppSpacing.gapSm,
                        Text(
                          'Sample photo on this device. Nothing is uploaded.',
                          style: context.text.bodySmall,
                        ),
                      ],
                      AppSpacing.gapXl,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
