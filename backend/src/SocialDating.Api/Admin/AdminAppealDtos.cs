namespace SocialDating.Api.Admin;

public sealed record AdminAppealListResponse(IReadOnlyList<AdminAppealItem> Items);

public sealed record AdminAppealItem(
    string Id,
    string AccountId,
    string? AccountName,
    string Kind,
    string Body,
    string Status,
    string FiledBy,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt,
    DateTimeOffset? SlaDueAt,
    string SlaState,
    double AgeHours
);

public sealed record CreateAppealRequest(string? Kind, string Body);

public sealed record ResolveAppealRequest(string Decision, string? Note);

public sealed record ClientAppConfigResponse(
    bool MaintenanceMode,
    int MinClientBuild,
    bool BannerEnabled,
    string? BannerTitle,
    string? BannerBody,
    DateTimeOffset UpdatedAt
);
