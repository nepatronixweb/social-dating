import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/money.dart';
import '../../../../core/utils/theme_context.dart';
import '../../../../data/models/referral_info.dart';

class AllocationLines extends StatelessWidget {
  const AllocationLines({super.key, required this.allocation});

  final ReferralAllocation allocation;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Line(
          label: 'Qualifying purchase',
          value: formatNpr(allocation.purchasePaisa),
          strong: true,
        ),
        _Line(
          label: 'Company allocation',
          value: formatNpr(allocation.companyPaisa),
        ),
        _Line(
          label: 'Buyer reward equivalent',
          value: formatNpr(allocation.buyerRewardEquivalentPaisa),
        ),
        _Line(
          label: 'Direct referrer commission',
          value: formatNpr(allocation.referrerCommissionPaisa),
          strong: true,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = strong ? context.text.titleMedium : context.text.bodyMedium;
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: AppSpacing.md,
          children: [
            Text(label, style: style),
            Text(value, style: style),
          ],
        ),
      ),
    );
  }
}
