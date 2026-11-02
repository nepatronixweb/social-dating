namespace SocialDating.Api.Admin;

public sealed record AdminPromoCodeListResponse(IReadOnlyList<AdminPromoCodeItem> Items);

public sealed record AdminPromoCodeItem(
    string Id,
    string Code,
    int Points,
    string Bucket,
    int MaxRedemptions,
    int RedemptionCount,
    DateTimeOffset? ExpiresAt,
    bool Active,
    string? CreatedByEmail,
    DateTimeOffset CreatedAt
);

public sealed record CreatePromoCodeRequest(
    string Code,
    int Points,
    string? Bucket,
    int? MaxRedemptions,
    DateTimeOffset? ExpiresAt
);

public sealed record SetPromoActiveRequest(bool Active);

public sealed record RedeemPromoRequest(string Code);

public sealed record RedeemPromoResponse(int Points, string Bucket, int SpendablePoints);

public sealed record BroadcastRequest(
    string Title,
    string Body,
    string? Gender,
    string? City,
    bool IncompleteOnly
);

public sealed record BroadcastResponse(int Recipients, string Message);

public sealed record CitySupplyRow(
    string City,
    int Total,
    int Male,
    int Female,
    int Lgbtq,
    int Other
);
