import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radii.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/subscription_plan.dart';
import '../../../data/repositories/repository_providers.dart';
import '../../auth/providers/session_provider.dart';
import '../providers/subscription_providers.dart';
import 'widgets/complimentary_premium.dart';

/// Illustrative payment methods. Confirming starts a pending mock purchase.
class PaymentMethodScreen extends ConsumerStatefulWidget {
  const PaymentMethodScreen({
    super.key,
    required this.planId,
    required this.referralLinked,
    this.amountPaisa,
  });

  final String planId;
  final bool referralLinked;
  final int? amountPaisa;

  @override
  ConsumerState<PaymentMethodScreen> createState() =>
      _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends ConsumerState<PaymentMethodScreen> {
  String? _methodId;
  bool _submitting = false;

  Future<void> _confirm() async {
    if (_submitting) return;
    final methods = ref
        .read(subscriptionRepositoryProvider)
        .illustrativeMethods;
    final method = _methodId ?? methods.first.id;
    _submitting = true;
    setState(() {});
    try {
      final record = await ref
          .read(subscriptionRepositoryProvider)
          .submitCheckout(
            planId: widget.planId,
            referralLinked: widget.referralLinked,
            methodId: method,
            confirmed: true,
            amountPaisa: widget.amountPaisa,
          );
      if (!mounted) return;
      ref.read(subscriptionRevisionProvider.notifier).bump();
      context.go(AppRoutes.subscriptionStatus(record.id));
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (sessionHasComplimentaryPremium(ref.watch(sessionProvider))) {
      return const AppPage(
        appBar: AppTopBar(title: 'Payment method'),
        body: ComplimentaryPremiumNotice(),
      );
    }
    final repo = ref.watch(subscriptionRepositoryProvider);
    final quote = repo.quote(
      planId: widget.planId,
      referralLinked: widget.referralLinked,
      amountPaisa: widget.amountPaisa,
    );
    final methods = repo.illustrativeMethods;
    final selected = _methodId ?? methods.first.id;

    return AppPage(
      appBar: const AppTopBar(title: 'Payment method'),
      bottomBar: Padding(
        padding: AppSpacing.pagePadding.copyWith(
          top: AppSpacing.md,
          bottom: AppSpacing.lg,
        ),
        child: ConstrainedContent(
          child: AppButton(
            label: 'Confirm purchase',
            isLoading: _submitting,
            onPressed: _submitting ? null : _confirm,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                title: 'Amount due ${formatNpr(quote.amountDuePaisa)}',
                subtitle: 'Choose a method, then confirm this purchase.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  children: [
                    AppSpacing.gapLg,
                    for (final method in methods) ...[
                      _MethodTile(
                        method: method,
                        selected: method.id == selected,
                        onTap: _submitting
                            ? null
                            : () => setState(() => _methodId = method.id),
                      ),
                      AppSpacing.gapMd,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.method,
    required this.selected,
    required this.onTap,
  });

  final PaymentMethodOption method;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.borderLg,
        side: BorderSide(
          color: selected
              ? context.colors.primary
              : context.palette.outlineSoft,
          width: selected ? 2 : 1,
        ),
      ),
      child: Semantics(
        button: true,
        selected: selected,
        label: '${method.name}. ${method.subtitle}',
        child: InkWell(
          borderRadius: AppRadii.borderLg,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                Icon(AppIcons.creditCard, color: context.colors.primary),
                AppSpacing.gapLg,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(method.name, style: context.text.titleMedium),
                      Text(
                        method.subtitle,
                        style: context.text.bodySmall?.copyWith(
                          color: context.palette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  selected ? AppIcons.check : AppIcons.forward,
                  color: selected
                      ? context.colors.primary
                      : context.palette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
