namespace SocialDating.Api.Subscription;

public sealed record SubscriptionPlanResponse(
    string Id,
    string Name,
    int PricePaisa,
    string PeriodLabel,
    IReadOnlyList<string> Features,
    bool IsPopular,
    string? SavingsLabel,
    bool IsRecurring,
    string PriceLabel
);

public sealed record ActiveSubscriptionResponse(
    SubscriptionPlanResponse Plan,
    DateTimeOffset StartedAt,
    DateTimeOffset? RenewsAt,
    DateTimeOffset? CancelledAt,
    bool ReferralLinked,
    bool Complimentary
);

public sealed record SubscriptionOverviewResponse(
    bool NeedsPaidSubscription,
    bool Complimentary,
    bool HasPremiumAccess,
    bool PaymentsEnabled,
    bool IsLive,
    ActiveSubscriptionResponse? Active
);

public sealed record SubscriptionPlanListResponse(IReadOnlyList<SubscriptionPlanResponse> Items);

public sealed record PurchaseListResponse(IReadOnlyList<object> Items);

public sealed record SubmitCheckoutRequest(
    string PlanId,
    bool ReferralLinked,
    string MethodId,
    bool Confirmed,
    int? AmountPaisa
);
