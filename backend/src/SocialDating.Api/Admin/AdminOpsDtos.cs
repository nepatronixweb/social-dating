namespace SocialDating.Api.Admin;

public sealed record AdminOpsOverviewResponse(
    int TotalAccounts,
    int AccountsToday,
    int ActiveToday,
    int MatchesToday,
    int SwipesToday,
    int MessagesToday,
    int PaidActionsToday,
    int OpenReports,
    int OpenWithdrawals,
    int PendingRefunds,
    int HiddenPhotos,
    int HiddenMessages,
    int AdminWalletPoints,
    int PremiumSpendPointsToday,
    string NepalDayKey,
    IReadOnlyList<string> Alerts,
    OpsKillSwitchSnapshot Kills
);

public sealed record OpsKillSwitchSnapshot(
    bool KillWithdrawals,
    bool KillPremiumCharges,
    bool KillReferrals,
    bool KillDiscovery,
    bool KillChatMessaging
);

public sealed record AdminMarketplaceHealthResponse(
    string NepalDayKey,
    int DiscoverableMale,
    int DiscoverableFemale,
    int DiscoverableLgbtq,
    int DiscoverableOther,
    int DiscoverableTotal,
    double FemaleShare,
    int SwipesToday,
    int LikesToday,
    int MatchesToday,
    int IncompleteMaleProfiles,
    string SupplyNote,
    IReadOnlyList<string> Alerts,
    IReadOnlyList<CitySupplyRow> Cities
);

public sealed record AdminRuntimeConfigResponse(
    int PremiumActionPoints,
    int ExtraSwipePoints,
    int DailyFreePointsMale,
    int FreeDailySwipesMale,
    int MinWithdrawalPoints,
    bool KillWithdrawals,
    bool KillPremiumCharges,
    bool KillReferrals,
    bool KillDiscovery,
    bool KillChatMessaging,
    bool MaintenanceMode,
    int MinClientBuild,
    bool BannerEnabled,
    string? BannerTitle,
    string? BannerBody,
    string ChatKeywordList,
    DateTimeOffset UpdatedAt,
    string? UpdatedByEmail
);

public sealed record UpdateRuntimeConfigRequest(
    int? PremiumActionPoints,
    int? ExtraSwipePoints,
    int? DailyFreePointsMale,
    int? FreeDailySwipesMale,
    int? MinWithdrawalPoints,
    bool? KillWithdrawals,
    bool? KillPremiumCharges,
    bool? KillReferrals,
    bool? KillDiscovery,
    bool? KillChatMessaging,
    bool? MaintenanceMode,
    int? MinClientBuild,
    bool? BannerEnabled,
    string? BannerTitle,
    string? BannerBody,
    string? ChatKeywordList
);

public sealed record AdminConfigHistoryResponse(IReadOnlyList<AdminConfigRevisionItem> Items);

public sealed record AdminConfigRevisionItem(
    string Id,
    string SnapshotJson,
    string? ChangedByEmail,
    DateTimeOffset CreatedAt
);

public sealed record AdminPhotoQueueResponse(IReadOnlyList<AdminPhotoQueueItem> Items);

public sealed record AdminPhotoQueueItem(
    string Id,
    string AccountId,
    string? AccountName,
    string Url,
    string Kind,
    bool Hidden,
    string ReviewStatus,
    string? ReviewReason,
    DateTimeOffset CreatedAt
);

public sealed record AdminMessageQueueResponse(IReadOnlyList<AdminMessageQueueItem> Items);

public sealed record AdminMessageQueueItem(
    string Id,
    string MatchId,
    string SenderAccountId,
    string? SenderName,
    string Body,
    bool Hidden,
    DateTimeOffset CreatedAt
);

public sealed record ModerationHideRequest(bool Hidden, string? Note);
