import '../../data/models/referral_info.dart';

String inviteStatusLabel(
  ReferralInviteStatus status, {
  bool demonstration = true,
}) {
  return switch (status) {
    ReferralInviteStatus.invited => 'Invited',
    ReferralInviteStatus.joined => 'Joined',
    ReferralInviteStatus.purchased => 'Purchase recorded',
    ReferralInviteStatus.refunded => 'Refunded',
  };
}

String commissionStatusLabel(
  CommissionStatus status, {
  bool demonstration = true,
}) {
  return switch (status) {
    CommissionStatus.pending => 'Pending',
    CommissionStatus.approved => 'Approved',
    CommissionStatus.reversed => 'Reversed',
    CommissionStatus.paid => 'Paid',
  };
}
