namespace SocialDating.Api.Admin;

public sealed record AdminKeywordHitListResponse(IReadOnlyList<AdminKeywordHitItem> Items);

public sealed record AdminKeywordHitItem(
    string Id,
    string MessageId,
    string MatchId,
    string SenderAccountId,
    string? SenderName,
    string Keyword,
    string MessageBody,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt
);

public sealed record ResolveKeywordHitRequest(string Decision, string? Note);

public sealed record StaffWatchListResponse(IReadOnlyList<StaffWatchItem> Items);

public sealed record StaffWatchItem(
    string Id,
    string AccountId,
    string? AccountName,
    string? Status,
    string Note,
    DateTimeOffset CreatedAt
);

public sealed record AddWatchRequest(string? Note);

public sealed record CasePacketResponse(
    string AccountId,
    string? DisplayName,
    string Status,
    bool OnMyWatchlist,
    int OpenReportsAbout,
    int OpenAppeals,
    int OpenKeywordHits,
    int ActiveMatches,
    int MessagesSent7d,
    IReadOnlyList<CasePacketLine> RecentReports,
    IReadOnlyList<CasePacketLine> RecentAppeals,
    IReadOnlyList<CasePacketLine> RecentKeywordHits,
    IReadOnlyList<CasePacketLine> RecentNotes
);

public sealed record CasePacketLine(
    string Id,
    string Kind,
    string Title,
    string Detail,
    DateTimeOffset At
);
