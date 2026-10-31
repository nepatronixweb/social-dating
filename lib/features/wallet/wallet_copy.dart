import '../../core/constants/wallet_rules.dart';
import '../../core/utils/money.dart';
import '../../data/models/wallet.dart';

String signedPoints(int credits) {
  final body = formatPoints(credits.abs());
  return credits >= 0 ? '+$body' : '-$body';
}

String walletFilterLabel(WalletActivityFilter filter) => switch (filter) {
  WalletActivityFilter.all => 'All',
  WalletActivityFilter.promotional => 'Promotional',
  WalletActivityFilter.earned => 'Earned',
  WalletActivityFilter.added => 'Added',
  WalletActivityFilter.spent => 'Spent',
};

String pointBucketLabel(PointBucket bucket) => switch (bucket) {
  PointBucket.promotional => 'Promotional',
  PointBucket.earned => 'Earned',
};

String activityKindLabel(WalletActivityKind kind, {bool isLive = false}) =>
    switch (kind) {
      WalletActivityKind.welcomeBonus => 'Welcome bonus',
      WalletActivityKind.subscriptionReward => 'Subscription reward',
      WalletActivityKind.messageReceived => 'Eligible messaging',
      WalletActivityKind.swipeSpend => 'Paid swipe',
      WalletActivityKind.messageSpend => 'Paid message',
      WalletActivityKind.withdrawalHold => 'Withdrawal hold',
      WalletActivityKind.withdrawalRelease => 'Withdrawal released',
      WalletActivityKind.other => 'Activity',
    };

String withdrawalStatusLabel(WithdrawalStatus status, {bool isLive = false}) =>
    switch (status) {
      WithdrawalStatus.recorded => 'Recorded',
      WithdrawalStatus.cancelled => 'Cancelled',
      WithdrawalStatus.declined => 'Declined',
    };

String withdrawalStatusDetail(WithdrawalStatus status, {bool isLive = false}) =>
    switch (status) {
      WithdrawalStatus.recorded =>
        'This request is saved on the account ledger. It was not '
            'submitted to a bank or payout provider, and it has not been '
            'paid.',
      WithdrawalStatus.cancelled =>
        'The hold was released. Nothing was sent to a bank.',
      WithdrawalStatus.declined =>
        'This request was declined. Nothing was sent to a bank or payout '
            'provider.',
    };

String withdrawalDisclosureTitle({required bool isLive}) =>
    WalletRules.liveLabel;

String withdrawalDisclosure({required bool isLive}) =>
    WalletRules.liveDisclosure;

String withdrawalRequestNote({required bool isLive}) =>
    WalletRules.liveRequestNote;

String withdrawalProcessingNote({required bool isLive}) =>
    WalletRules.processingTimeNoteLive;
