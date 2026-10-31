import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/wallet_rules.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/async_value_view.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../core/widgets/screen_header.dart';
import '../../../data/models/wallet.dart';
import '../../../data/repositories/repository_providers.dart';
import '../providers/wallet_providers.dart';
import '../wallet_copy.dart';
import 'widgets/wallet_amount_line.dart';

class WithdrawalRequestScreen extends ConsumerStatefulWidget {
  const WithdrawalRequestScreen({super.key});

  @override
  ConsumerState<WithdrawalRequestScreen> createState() =>
      _WithdrawalRequestScreenState();
}

class _WithdrawalRequestScreenState
    extends ConsumerState<WithdrawalRequestScreen> {
  late final TextEditingController _amount;
  bool _understood = false;
  bool _busy = false;
  bool _seeded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int? get _points {
    final parsed = int.tryParse(_amount.text.trim());
    return parsed;
  }

  void _seedAmount(int available) {
    if (_seeded || _amount.text.isNotEmpty) return;
    _seeded = true;
    _amount.text = '$available';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _submit(WithdrawalEligibility eligibility) async {
    if (_busy) return;
    final points = _points;
    if (points == null) {
      setState(() => _error = 'Enter a whole number of earned points.');
      return;
    }
    final live = eligibility.isLive;
    final confirmed = await showConfirmationDialog(
      context,
      title: 'Record this request?',
      message: withdrawalRequestNote(isLive: live),
      confirmLabel: 'Record request',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final request = await ref
          .read(walletRepositoryProvider)
          .submitWithdrawal(points: points, confirmed: true);
      ref.read(walletRevisionProvider.notifier).bump();
      if (!mounted) return;
      context.go(AppRoutes.walletWithdrawal(request.id));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = AppFailure.from(error).message;
      });
      showAppSnackBar(
        context,
        AppFailure.from(error).message,
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(walletEligibilityProvider, (previous, next) {
      final available = next.asData?.value.earnedAvailable;
      if (available == null) return;
      _seedAmount(available);
    });
    final value = ref.watch(walletEligibilityProvider);
    final eligibility = value.asData?.value;
    final showForm =
        eligibility != null &&
        eligibility.eligibleAccount &&
        !eligibility.belowMinimum;

    return AppPage(
      appBar: const AppTopBar(title: 'Request'),
      bottomBar: showForm
          ? Padding(
              padding: AppSpacing.pagePadding.copyWith(
                top: AppSpacing.md,
                bottom: AppSpacing.lg,
              ),
              child: ConstrainedContent(
                child: AppButton(
                  label: 'Record request',
                  isLoading: _busy,
                  onPressed: _understood && !_busy
                      ? () => _submit(eligibility)
                      : null,
                ),
              ),
            )
          : null,
      body: AsyncValueView<WithdrawalEligibility>(
        value: value,
        loading: const AppLoadingIndicator(),
        onRetry: () => ref.invalidate(walletEligibilityProvider),
        data: (current) {
          return _RequestBody(
            eligibility: current,
            amount: _amount,
            understood: _understood,
            busy: _busy,
            error: _error,
            points: _points,
            onUnderstood: (next) => setState(() => _understood = next ?? false),
            onChanged: () => setState(() => _error = null),
          );
        },
      ),
    );
  }
}

class _RequestBody extends StatelessWidget {
  const _RequestBody({
    required this.eligibility,
    required this.amount,
    required this.understood,
    required this.busy,
    required this.error,
    required this.points,
    required this.onUnderstood,
    required this.onChanged,
  });

  final WithdrawalEligibility eligibility;
  final TextEditingController amount;
  final bool understood;
  final bool busy;
  final String? error;
  final int? points;
  final ValueChanged<bool?> onUnderstood;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final live = eligibility.isLive;
    final fee = eligibility.feePoints;
    final net = points == null ? 0 : points! - fee;

    if (!eligibility.eligibleAccount) {
      return EmptyState(
        icon: AppIcons.lock,
        title: 'Request interface unavailable',
        message:
            'Withdrawal requests are available to female, LGBTQ+ and other '
            'accounts. Promotional points never count.',
      );
    }

    if (eligibility.belowMinimum) {
      final shortfall = eligibility.minimumPoints - eligibility.earnedAvailable;
      return EmptyState(
        icon: AppIcons.wallet,
        title: 'Insufficient earned points',
        message:
            'You need ${formatPoints(shortfall < 0 ? 0 : shortfall)} more '
            'earned points to reach the '
            '${formatPoints(eligibility.minimumPoints)} threshold '
            '(${formatNpr(walletPaisaFromPoints(eligibility.minimumPoints))} equivalent). '
            'Promotional points cannot be withdrawn.',
      );
    }

    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: ConstrainedContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ScreenHeader(
              title: 'Review earned points',
              subtitle:
                  'Saved on the account ledger. Not submitted and not paid.',
            ),
            Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WalletAmountLine(
                    label: 'Available earned',
                    value: formatPoints(eligibility.earnedAvailable),
                    strong: true,
                  ),
                  WalletAmountLine(
                    label: 'Configured minimum',
                    value: formatPoints(eligibility.minimumPoints),
                  ),
                  AppTextField(
                    label: 'Earned points to record',
                    controller: amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    errorText: error,
                    helper:
                        'Promotional points cannot be entered. Stated '
                        'equivalent is not cash.',
                    onChanged: (_) => onChanged(),
                  ),
                  AppSpacing.gapLg,
                  WalletAmountLine(
                    label: 'Configured fee',
                    value: formatPoints(fee),
                  ),
                  if (WalletRules.extraFees.isEmpty)
                    InlineMessage(
                      tone: InlineMessageTone.info,
                      icon: AppIcons.info,
                      title: 'No extra fees configured',
                      message:
                          'Payout fees and tax appear only when a provider '
                          'or WalletRules supplies them. This configuration '
                          'adds none.',
                    ),
                  AppSpacing.gapMd,
                  WalletAmountLine(
                    label: 'Net points',
                    value: formatPoints(net < 0 ? 0 : net),
                    strong: true,
                  ),
                  WalletAmountLine(
                    label: 'Stated NPR equivalent',
                    value: formatNpr(walletPaisaFromPoints(net < 0 ? 0 : net)),
                  ),
                  AppSpacing.gapMd,
                  Text(withdrawalProcessingNote(isLive: live)),
                  AppSpacing.gapLg,
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: understood,
                    onChanged: busy ? null : onUnderstood,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'I understand this request will not be sent to a '
                      'bank or payout provider, and it will not be paid.',
                    ),
                  ),
                  AppSpacing.gapXl,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
