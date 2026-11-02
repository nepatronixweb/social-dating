namespace SocialDating.Api.Admin;

public sealed record AdminUserTimelineResponse(IReadOnlyList<AdminTimelineItem> Items);

public sealed record AdminTimelineItem(
    string Id,
    string Kind,
    string Title,
    string Detail,
    string? ActorEmail,
    string? RelatedId,
    DateTimeOffset At
);

public sealed record AddCaseNoteRequest(string Body);

public sealed record AdminFraudDeskResponse(IReadOnlyList<AdminFraudSignal> Items);

public sealed record AdminFraudSignal(
    string Id,
    string Kind,
    string Severity,
    string Title,
    string Detail,
    string? AccountId,
    string? AccountName,
    int Score,
    DateTimeOffset DetectedAt
);

public sealed record ShadowBanRequest(string? Reason);

public sealed record ReviewPhotoRequest(string Status, string? Reason, string? Note);
