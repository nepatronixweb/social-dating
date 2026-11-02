namespace SocialDating.Api.Admin;

public sealed record StaffLoginRequest(string Email, string Password);

public sealed record StaffLoginResponse(
    string AccessToken,
    DateTimeOffset ExpiresAt,
    StaffProfileResponse Staff
);

public sealed record StaffProfileResponse(
    string Id,
    string Email,
    string DisplayName,
    string Role
);

public sealed record AdminOverviewResponse(
    int TotalAccounts,
    int AccountsToday,
    int OpenReports,
    int OpenWithdrawals,
    int AdminWalletPoints,
    int PremiumSpendPointsToday,
    string NepalDayKey
);

public sealed record AdminUserListResponse(IReadOnlyList<AdminUserSummary> Items);

public sealed record AdminUserSummary(
    string Id,
    string? DisplayName,
    string? Gender,
    string? City,
    string PhoneMasked,
    int SpendablePoints,
    int PromotionalPoints,
    int EarnedPoints,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? DeletedAt,
    DateTimeOffset? SuspendedAt,
    DateTimeOffset? ShadowBannedAt
);

public sealed record AdminUserDetailResponse(
    string Id,
    string? DisplayName,
    string? Gender,
    string? City,
    string? Bio,
    string PhoneMasked,
    string? PhoneE164,
    int SpendablePoints,
    int PromotionalPoints,
    int EarnedPoints,
    int PendingWithdrawalPoints,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? DeletedAt,
    DateTimeOffset? SuspendedAt,
    DateTimeOffset? ShadowBannedAt,
    DateTimeOffset? LastWarnedAt,
    DateTimeOffset? TermsAcceptedAt,
    bool? AgeEligible,
    bool ComplimentaryPremium,
    int PhotoCount,
    IReadOnlyList<string> PhotoUrls,
    int ActiveMatchCount,
    int BlockedByCount,
    int BlockingCount,
    string? SwipeDayKey,
    int PreviewUsed,
    int DailyUsed,
    IReadOnlyList<AdminLedgerItem> RecentLedger
);

public sealed record AdminLedgerListResponse(IReadOnlyList<AdminLedgerItem> Items);

public sealed record AdminLedgerItem(
    string Id,
    string AccountId,
    string? AccountName,
    int Points,
    string Bucket,
    string Kind,
    string Title,
    string Detail,
    DateTimeOffset OccurredAt,
    string? SourceId
);

public sealed record AdminWithdrawalListResponse(IReadOnlyList<AdminWithdrawalItem> Items);

public sealed record AdminWithdrawalItem(
    string Id,
    string AccountId,
    string? AccountName,
    string PhoneMasked,
    string? Gender,
    int Points,
    int FeePoints,
    int NetPoints,
    string Status,
    /// <summary>Human label — paid means ops-marked, not a bank transfer.</summary>
    string StatusLabel,
    int CurrentEarnedPoints,
    int MinWithdrawalPoints,
    bool GenderEligible,
    bool EligibilityLooksOk,
    string EligibilityNote,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt
);

public sealed record ResolveWithdrawalRequest(string Decision, string? Note);

public sealed record AdminReportListResponse(IReadOnlyList<AdminReportItem> Items);

public sealed record AdminReportItem(
    string Id,
    string ReporterAccountId,
    string ReportedAccountId,
    string? ReportedName,
    string Reason,
    string Detail,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt,
    DateTimeOffset? SlaDueAt,
    /// <summary>ok | due_soon | overdue | closed</summary>
    string SlaState,
    double AgeHours,
    string? ClaimedByStaffId,
    string? ClaimedByEmail,
    DateTimeOffset? ClaimedAt
);

/// <summary>
/// Status: investigating | actioned | dismissed.
/// ModerationAction (when actioned): warn | suspend | ban | none.
/// </summary>
public sealed record ResolveReportRequest(string Status, string? Note, string? ModerationAction);

public sealed record AdjustPointsRequest(
    int Points,
    string Bucket,
    string Title,
    string? Detail
);

public sealed record BanUserRequest(string? Reason);

public sealed record ForceLogoutResponse(int RevokedSessions, string Message);

public sealed record BulkReviewPhotosRequest(
    IReadOnlyList<string> Ids,
    string Status,
    string? Reason,
    string? Note
);

public sealed record BulkReviewPhotosResponse(int Updated, IReadOnlyList<string> SkippedIds, string Message);

public sealed record StaffActivityResponse(
    string NepalDayKey,
    int ActionsToday,
    int Actions7d,
    IReadOnlyList<StaffActivityRow> ByStaffToday,
    IReadOnlyList<StaffActivityActionRow> TopActionsToday
);

public sealed record StaffActivityRow(string StaffEmail, string? Role, int Actions);

public sealed record StaffActivityActionRow(string Action, int Count);

public sealed record ComplimentaryPremiumRequest(bool Enabled);

public sealed record ClawbackCommissionRequest(string? Note);

public sealed record StaffMemberResponse(
    string Id,
    string Email,
    string DisplayName,
    string Role,
    DateTimeOffset CreatedAt,
    DateTimeOffset? DisabledAt,
    DateTimeOffset? LastLoginAt
);

public sealed record StaffListResponse(IReadOnlyList<StaffMemberResponse> Items);

public sealed record CreateStaffRequest(
    string Email,
    string DisplayName,
    string Role,
    string TemporaryPassword
);

public sealed record ResetStaffPasswordRequest(string TemporaryPassword);

public sealed record SetStaffRoleRequest(string Role);

public sealed record WarnUserRequest(string? Reason);

public sealed record SuspendUserRequest(string? Reason);

public sealed record RefundChargeRequest(string SourceId, string? Note);

public sealed record RefundChargeResponse(
    bool Ok,
    bool RequiresApproval,
    string? RefundRequestId,
    string Message
);

public sealed record ResolveRefundRequest(string Decision, string? Note);

public sealed record AdminRefundListResponse(IReadOnlyList<AdminRefundItem> Items);

public sealed record AdminRefundItem(
    string Id,
    string AccountId,
    string? AccountName,
    string SourceId,
    int Points,
    string Status,
    string RequestedByEmail,
    string? ResolvedByEmail,
    string Note,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt
);

public sealed record AdminReferralInviteListResponse(IReadOnlyList<AdminReferralInviteItem> Items);

public sealed record AdminReferralInviteItem(
    string Id,
    string ReferrerAccountId,
    string? ReferrerName,
    string InviteeAccountId,
    string? InviteeName,
    string CodeUsed,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? PurchasedAt,
    DateTimeOffset? RefundedAt
);

public sealed record AdminReferralCommissionListResponse(
    IReadOnlyList<AdminReferralCommissionItem> Items
);

public sealed record AdminReferralCommissionItem(
    string Id,
    string InviteId,
    string ReferrerAccountId,
    string? ReferrerName,
    int AmountPaisa,
    string Status,
    string Detail,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt
);

public sealed record AdminDailyGrantListResponse(
    string DayKey,
    int GrantPoints,
    int RecipientCount,
    int TotalPointsGranted,
    IReadOnlyList<AdminDailyGrantItem> Items
);

public sealed record AdminDailyGrantItem(
    string AccountId,
    string? DisplayName,
    string? Gender,
    int Points,
    DateTimeOffset OccurredAt,
    string SourceId
);

public sealed record AdminSubscriptionOverviewResponse(
    int MaleAccounts,
    int ComplimentaryByGender,
    int StaffComplimentaryOverrides,
    int NeedingPaidPath,
    bool PaymentsEnabled,
    string Note
);

public sealed record AdminAuditListResponse(IReadOnlyList<AdminAuditItem> Items);

public sealed record AdminAuditItem(
    string Id,
    string StaffEmail,
    string Action,
    string? TargetType,
    string? TargetId,
    string Detail,
    DateTimeOffset CreatedAt
);
