// ============================================================================
// MOCK DATA ONLY: in-memory referral codes, invites and commissions
//
// Sharing, attribution and NPR 10 direct commissions are simulated on this
// device. NOTHING is attributed, charged or paid. A commission is pending
// until this mock records a confirmed qualifying purchase. Statuses are
// pending, approved, reversed or paid — paid is a mock label, not a bank
// payout. Nothing outside `mock_*` files and the approved seam may import
// this file (test/mock_isolation_test.dart).
// ============================================================================

import '../../core/constants/referral_rules.dart';
import '../../core/errors/app_failure.dart';
import '../models/referral_info.dart';
import 'mock_profile_repository.dart';
import 'repository_contracts.dart';

class MockReferralRepository implements ReferralRepository {
  MockReferralRepository({
    MockScenario Function()? scenario,
    this.latency = const Duration(milliseconds: 600),
    DateTime Function()? now,
  }) : _scenario = scenario ?? (() => MockScenario.populated),
       _now = now ?? DateTime.now {
    reset();
  }

  final MockScenario Function() _scenario;
  final Duration latency;
  final DateTime Function() _now;

  final List<ReferralInvite> _invites = [];
  final List<ReferralCommission> _commissions = [];

  void reset() {
    final now = _now();
    _invites
      ..clear()
      ..addAll([
        ReferralInvite(
          id: 'mock-ref-jordan',
          displayName: 'Jordan Sample',
          status: ReferralInviteStatus.invited,
          createdAt: now.subtract(const Duration(days: 12)),
          detail:
              'Invite recorded. No qualifying purchase is attached, so there '
              'is no commission.',
        ),
        ReferralInvite(
          id: 'mock-ref-riley',
          displayName: 'Riley Dummy',
          status: ReferralInviteStatus.joined,
          createdAt: now.subtract(const Duration(days: 8)),
          detail:
              'This person joined with your code. The NPR 10 commission '
              'stays pending until a qualifying purchase is confirmed.',
        ),
        ReferralInvite(
          id: 'mock-ref-casey',
          displayName: 'Casey Fake',
          status: ReferralInviteStatus.purchased,
          createdAt: now.subtract(const Duration(days: 5)),
          detail:
              'An NPR 100 referral-linked purchase is recorded as confirmed. '
              'The direct commission is approved.',
        ),
        ReferralInvite(
          id: 'mock-ref-quinn',
          displayName: 'Quinn Example',
          status: ReferralInviteStatus.refunded,
          createdAt: now.subtract(const Duration(days: 3)),
          detail:
              'A qualifying purchase was later refunded. The commission is '
              'reversed and is not earnings.',
        ),
        ReferralInvite(
          id: 'mock-ref-avery',
          displayName: 'Avery Sample',
          status: ReferralInviteStatus.purchased,
          createdAt: now.subtract(const Duration(days: 1)),
          detail:
              'A qualifying purchase is confirmed. The commission is labelled '
              'paid.',
        ),
      ]);
    _commissions
      ..clear()
      ..addAll([
        ReferralCommission(
          id: 'mock-cm-riley',
          inviteId: 'mock-ref-riley',
          personName: 'Riley Dummy',
          amountPaisa: ReferralRules.referrerCommissionPaisa,
          status: CommissionStatus.pending,
          createdAt: now.subtract(const Duration(days: 8)),
          detail: ReferralRules.pendingUntilConfirmed,
        ),
        ReferralCommission(
          id: 'mock-cm-casey',
          inviteId: 'mock-ref-casey',
          personName: 'Casey Fake',
          amountPaisa: ReferralRules.referrerCommissionPaisa,
          status: CommissionStatus.approved,
          createdAt: now.subtract(const Duration(days: 5)),
          resolvedAt: now.subtract(const Duration(days: 4)),
          detail:
              'Approved after a confirmed qualifying purchase.',
        ),
        ReferralCommission(
          id: 'mock-cm-quinn',
          inviteId: 'mock-ref-quinn',
          personName: 'Quinn Example',
          amountPaisa: ReferralRules.referrerCommissionPaisa,
          status: CommissionStatus.reversed,
          createdAt: now.subtract(const Duration(days: 3)),
          resolvedAt: now.subtract(const Duration(days: 2)),
          detail: ReferralRules.reversalNote,
        ),
        ReferralCommission(
          id: 'mock-cm-avery',
          inviteId: 'mock-ref-avery',
          personName: 'Avery Sample',
          amountPaisa: ReferralRules.referrerCommissionPaisa,
          status: CommissionStatus.paid,
          createdAt: now.subtract(const Duration(days: 1)),
          resolvedAt: now.subtract(const Duration(hours: 6)),
          detail:
              'This commission is marked paid.',
        ),
      ]);
  }

  Future<T> _fetch<T>(T Function() data, T empty) => simulateMockCall(
    scenario: _scenario(),
    latency: latency,
    data: data,
    empty: empty,
  );

  ReferralInfo _overview() {
    final joined = _invites
        .where((item) => item.status != ReferralInviteStatus.invited)
        .length;
    final purchases = _invites
        .where(
          (item) =>
              item.status == ReferralInviteStatus.purchased ||
              item.status == ReferralInviteStatus.refunded,
        )
        .length;
    return ReferralInfo(
      code: ReferralRules.mockCode,
      invitesSent: _invites.length,
      friendsJoined: joined,
      qualifyingPurchases: purchases,
      pendingCommissionPaisa: commissionTotal(
        _commissions,
        CommissionStatus.pending,
      ),
      approvedCommissionPaisa: commissionTotal(
        _commissions,
        CommissionStatus.approved,
      ),
      paidCommissionPaisa: commissionTotal(_commissions, CommissionStatus.paid),
      reversedCommissionPaisa: commissionTotal(
        _commissions,
        CommissionStatus.reversed,
      ),
      creditsEarned:
          (commissionTotal(_commissions, CommissionStatus.approved) +
              commissionTotal(_commissions, CommissionStatus.paid)) ~/
          10,
    );
  }

  @override
  ReferralAllocation get allocation => ReferralAllocation.qualifyingNpr100();

  @override
  Future<void> claimCode(String code) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    throw const ValidationFailure(
      'That invite code could not be applied.',
    );
  }

  @override
  Future<ReferralInfo> fetchReferralInfo() =>
      _fetch(_overview, const ReferralInfo(code: ReferralRules.mockCode));

  @override
  Future<List<ReferralInvite>> fetchInvites() => _fetch(() {
    final items = [..._invites]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }, const []);

  @override
  Future<List<ReferralCommission>> fetchCommissions() => _fetch(() {
    final items = [..._commissions]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }, const []);

  @override
  Future<ReferralCommission?> fetchCommission(String id) => _fetch(() {
    for (final item in _commissions) {
      if (item.id == id) return item;
    }
    return null;
  }, null);

  @override
  Future<ReferralCommission> confirmQualifyingPurchase(String inviteId) async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    if (_scenario() == MockScenario.failure) {
      throw const NetworkFailure();
    }
    final inviteIndex = _invites.indexWhere((item) => item.id == inviteId);
    if (inviteIndex < 0) {
      throw const NotFoundFailure('That invite is no longer here.');
    }
    final commissionIndex = _commissions.indexWhere(
      (item) => item.inviteId == inviteId,
    );
    if (commissionIndex < 0) {
      throw const ValidationFailure(
        'This invite has no commission to confirm.',
      );
    }
    final current = _commissions[commissionIndex];
    if (current.status != CommissionStatus.pending) {
      throw const ValidationFailure(
        'Only a pending commission can be confirmed.',
      );
    }
    final updated = current.copyWith(
      status: CommissionStatus.approved,
      resolvedAt: _now(),
      detail:
          'Approved after a confirmed qualifying purchase.',
    );
    _commissions[commissionIndex] = updated;
    _invites[inviteIndex] = ReferralInvite(
      id: _invites[inviteIndex].id,
      displayName: _invites[inviteIndex].displayName,
      status: ReferralInviteStatus.purchased,
      createdAt: _invites[inviteIndex].createdAt,
      detail:
          'An NPR 100 referral-linked purchase is recorded as confirmed.',
    );
    return updated;
  }
}
