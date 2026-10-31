namespace SocialDating.Api.Inbox;

public sealed record NotificationListResponse(IReadOnlyList<NotificationResponse> Items);

public sealed record NotificationResponse(
    string Id,
    string Type,
    string Title,
    string Body,
    DateTimeOffset CreatedAt,
    bool IsRead
);
