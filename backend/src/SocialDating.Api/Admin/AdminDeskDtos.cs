namespace SocialDating.Api.Admin;

public sealed record AttentionQueueResponse(
    int OpenReports,
    int OverdueReports,
    int OpenAppeals,
    int OpenKeywordHits,
    int OpenWithdrawals,
    int PendingRefunds,
    int PendingPhotos,
    int ActiveKills,
    int FraudSignalCount,
    IReadOnlyList<AttentionItem> Items
);

public sealed record AttentionItem(
    string Kind,
    string Severity,
    string Title,
    string Detail,
    string Href,
    DateTimeOffset? At
);

public sealed record PayoutRunSummaryResponse(
    string NepalDayKey,
    int Count,
    int TotalPoints,
    int TotalFeePoints,
    int TotalNetPoints,
    IReadOnlyList<AdminWithdrawalItem> Items
);

public sealed record MarkPayoutRunRequest(
    IReadOnlyList<string> Ids,
    int? ExpectedTotalPoints,
    string? Note
);

public sealed record MarkPayoutRunResponse(
    int Marked,
    int TotalPoints,
    IReadOnlyList<string> SkippedIds,
    string Message
);

public sealed record RevenueSnapshotResponse(
    string NepalDayKey,
    int TotalSpendPoints,
    int AdminReceivePoints,
    IReadOnlyList<RevenueKindRow> ByKind
);

public sealed record RevenueKindRow(string Kind, int Count, int Points);
