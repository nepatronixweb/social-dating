namespace SocialDating.Api.Admin;

public sealed record UserComplianceExportResponse(
    string ExportedAt,
    string AccountId,
    UserComplianceAccount Account,
    UserComplianceWallet Wallet,
    UserComplianceCounts Counts,
    IReadOnlyList<UserCompliancePhoto> Photos,
    IReadOnlyList<UserComplianceReport> ReportsAbout,
    IReadOnlyList<UserComplianceReport> ReportsFiled,
    IReadOnlyList<UserComplianceLedgerRow> RecentLedger
);

public sealed record UserComplianceAccount(
    string? PhoneE164,
    string? DisplayName,
    string? Bio,
    string? City,
    string? Gender,
    string? ReferralCode,
    DateOnly? BirthDate,
    bool? AgeEligible,
    DateTimeOffset CreatedAt,
    DateTimeOffset UpdatedAt,
    DateTimeOffset? DeletedAt,
    DateTimeOffset? SuspendedAt,
    DateTimeOffset? ShadowBannedAt,
    string Status
);

public sealed record UserComplianceWallet(
    int SpendablePoints,
    int PromotionalPoints,
    int EarnedPoints,
    int PendingWithdrawalPoints
);

public sealed record UserComplianceCounts(
    int Photos,
    int ActiveMatches,
    int MessagesSent,
    int Swipes,
    int RefreshTokensActive,
    int OpenWithdrawals
);

public sealed record UserCompliancePhoto(
    string Id,
    string Kind,
    string ReviewStatus,
    bool Hidden,
    DateTimeOffset CreatedAt
);

public sealed record UserComplianceReport(
    string Id,
    string Reason,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt
);

public sealed record UserComplianceLedgerRow(
    string Id,
    int Points,
    string Bucket,
    string Kind,
    string Title,
    DateTimeOffset OccurredAt
);

public sealed record EraseUserRequest(string? Reason, bool Confirm);

public sealed record EraseUserResponse(
    string AccountId,
    string Message,
    DateTimeOffset ErasedAt
);
