namespace SocialDating.Api.Wallet;

public sealed record PointBalanceResponse(
    int PromotionalPoints,
    int EarnedPoints,
    int PendingWithdrawalPoints
);

public sealed record WalletTransactionListResponse(
    IReadOnlyList<WalletTransactionResponse> Items
);

public sealed record WalletTransactionResponse(
    string Id,
    string Title,
    int Points,
    DateTimeOffset OccurredAt,
    string Bucket,
    string Kind,
    string Detail
);

public sealed record WithdrawalEligibilityResponse(
    bool EligibleAccount,
    int EarnedAvailable,
    int MinimumPoints,
    int FeePoints,
    bool CanSubmit,
    string Explanation,
    bool PayoutsEnabled,
    bool IsLive
);

public sealed record WithdrawalListResponse(IReadOnlyList<WithdrawalRequestResponse> Items);

public sealed record WithdrawalRequestResponse(
    string Id,
    int Points,
    int FeePoints,
    int NetPoints,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ResolvedAt,
    bool PayoutsEnabled,
    bool IsLive
);

public sealed record SubmitWithdrawalRequest(int Points, bool Confirmed);
