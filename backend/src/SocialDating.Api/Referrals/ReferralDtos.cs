namespace SocialDating.Api.Referrals;

public sealed record ReferralAllocationResponse(
    int PurchasePaisa,
    int CompanyPaisa,
    int BuyerRewardEquivalentPaisa,
    int ReferrerCommissionPaisa
);

public sealed record ReferralInfoResponse(
    string Code,
    string InviteLink,
    string ShareMessage,
    int InvitesSent,
    int FriendsJoined,
    int QualifyingPurchases,
    int PendingCommissionPaisa,
    int ApprovedCommissionPaisa,
    int PaidCommissionPaisa,
    int ReversedCommissionPaisa,
    int CreditsEarned,
    bool PayoutsEnabled,
    bool IsLive,
    ReferralAllocationResponse Allocation
);

public sealed record ReferralInviteListResponse(IReadOnlyList<ReferralInviteResponse> Items);

public sealed record ReferralInviteResponse(
    string Id,
    string DisplayName,
    string Status,
    DateTimeOffset CreatedAt,
    string Detail
);

public sealed record ReferralCommissionListResponse(
    IReadOnlyList<ReferralCommissionResponse> Items
);

public sealed record ReferralCommissionResponse(
    string Id,
    string InviteId,
    string PersonName,
    int AmountPaisa,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt,
    string Detail
);

public sealed record ClaimReferralRequest(string Code);
