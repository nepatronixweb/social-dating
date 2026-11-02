namespace SocialDating.Api.Admin;

public sealed record LinkedAccountsResponse(
    string AccountId,
    IReadOnlyList<string> DeviceIds,
    IReadOnlyList<string> IpAddresses,
    IReadOnlyList<LinkedAccountItem> Items
);

public sealed record LinkedAccountItem(
    string AccountId,
    string? DisplayName,
    string Status,
    string LinkKind,
    string LinkValue,
    DateTimeOffset LastSeenAt
);

public sealed record AuthBlockListResponse(IReadOnlyList<AuthBlockItem> Items);

public sealed record AuthBlockItem(
    string Id,
    string Kind,
    string Value,
    string Reason,
    bool Active,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ClearedAt
);

public sealed record AddAuthBlockRequest(string Kind, string Value, string? Reason);
