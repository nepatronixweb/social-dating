namespace SocialDating.Api.Discovery;

public sealed record PublicProfileResponse(
    string Id,
    string DisplayName,
    int Age,
    string City,
    string Bio,
    string[] Interests,
    bool IsVerified,
    bool IsOnline,
    int PhotoCount,
    int? DistanceKm,
    string? Occupation,
    string? Gender,
    string? LookingFor,
    string[] PhotoUrls,
    int? SpendablePoints = null
);

public sealed record DiscoveryPageResponse(IReadOnlyList<PublicProfileResponse> Items);

public sealed record SwipeQuotaResponse(
    bool ProfileComplete,
    int PreviewUsed,
    int DailyUsed,
    int? FreeDailyLimit,
    int BalancePaisa,
    int PricePaisa,
    int ActionPricePaisa,
    string DayKey,
    DateTimeOffset ResetsAt
);

public sealed record SwipeRequest(string ProfileId, string Direction, bool ConfirmedPaid);

public sealed record SwipeOutcomeResponse(
    SwipeQuotaResponse Quota,
    PublicProfileResponse? MatchedProfile,
    int ChargedPaisa,
    string? Rejection,
    string? ConversationId = null
);

public sealed record UndoRequest(bool ConfirmedPaid);

public sealed record UndoOutcomeResponse(
    PublicProfileResponse? Profile,
    SwipeQuotaResponse Quota,
    int ChargedPaisa = 0,
    string? Rejection = null
);

public sealed record DiscoveryMessageRequest(string ProfileId, bool ConfirmedPaid);

public sealed record DiscoveryMessageResponse(
    SwipeQuotaResponse Quota,
    string? ConversationId,
    int ChargedPaisa,
    string? Rejection
);

public sealed record MatchListResponse(IReadOnlyList<MatchResponse> Items);

public sealed record MatchResponse(
    string Id,
    PublicProfileResponse Profile,
    DateTimeOffset MatchedAt,
    bool IsNew,
    DateTimeOffset? LastActiveAt,
    string ConversationId
);

public sealed record LikeItemResponse(PublicProfileResponse Profile, DateTimeOffset LikedAt);

public sealed record LikeListResponse(IReadOnlyList<LikeItemResponse> Items);

public sealed record LikeOutcomeResponse(MatchResponse? Match, bool Created);
