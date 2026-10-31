import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/wallet_rules.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/money.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/theme_context.dart';
import '../../../core/widgets/app_page.dart';
import '../../../core/widgets/app_section.dart';
import '../../../core/widgets/app_top_bar.dart';
import '../../../core/widgets/inline_message.dart';
import '../../../core/widgets/menu_tile.dart';
import '../../../core/widgets/screen_header.dart';
import 'widgets/wallet_amount_line.dart';

class WelcomeBonusScreen extends StatelessWidget {
  const WelcomeBonusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppPage(
      appBar: const AppTopBar(title: 'Welcome bonus'),
      body: SingleChildScrollView(
        child: ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                title: '1,000 promotional points',
                subtitle: 'Granted once. Not cash and not withdrawable.',
              ),
              Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    WalletAmountLine(
                      label: 'Welcome bonus',
                      value: formatPoints(WalletRules.welcomeBonusPoints),
                      strong: true,
                    ),
                    WalletAmountLine(
                      label: 'Stated NPR equivalent',
                      value: formatNpr(
                        walletPaisaFromPoints(WalletRules.welcomeBonusPoints),
                      ),
                    ),
                    WalletAmountLine(
                      label: 'Withdrawable',
                      value: WalletRules.welcomeBonusWithdrawable
                          ? 'Yes'
                          : 'No',
                    ),
                    AppSpacing.gapMd,
                    Text(
                      WalletRules.welcomeBonusExplainer,
                      style: context.text.bodyMedium?.copyWith(
                        color: context.palette.textMuted,
                      ),
                    ),
                    AppSpacing.gapLg,
                    const InlineMessage(
                      tone: InlineMessageTone.info,
                      icon: AppIcons.info,
                      title: 'Equivalent is not cash',
                      message: WalletRules.equivalentNotCash,
                    ),
                  ],
                ),
              ),
              AppSpacing.gapLg,
              AppSection(
                title: 'Also',
                child: Column(
                  children: [
                    MenuTile(
                      icon: AppIcons.history,
                      title: 'See wallet activity',
                      onTap: () => context.push(AppRoutes.walletActivity),
                    ),
                    MenuTile(
                      icon: AppIcons.help,
                      title: 'Payout help',
                      onTap: () => context.push(AppRoutes.walletHelp),
                    ),
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
