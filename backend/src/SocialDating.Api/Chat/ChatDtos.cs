using SocialDating.Api.Discovery;

namespace SocialDating.Api.Chat;

public sealed record ConversationListResponse(IReadOnlyList<ConversationResponse> Items);

public sealed record ConversationResponse(
    string Id,
    PublicProfileResponse Profile,
    string LastMessage,
    DateTimeOffset LastMessageAt,
    int UnreadCount,
    bool Muted,
    bool IsTyping
);

public sealed record MessageListResponse(IReadOnlyList<MessageResponse> Items);

public sealed record MessageResponse(
    string Id,
    string Text,
    bool IsMine,
    DateTimeOffset SentAt,
    string Delivery,
    int ChargedPaisa,
    int EligibleWordCount,
    string? ImageUrl = null
);

public sealed record SendMessageRequest(
    string Text,
    bool ConfirmedPaid,
    string? RetryOfId = null,
    string? ImageId = null
);

public sealed record SendOutcomeResponse(
    MessageResponse? Message,
    string? Rejection,
    MessageQuoteResponse? Quote,
    int ChargedPaisa,
    int BalancePaisa
);

public sealed record MessageQuoteResponse(
    int EligibleWords,
    int CharacterCount,
    int CostPaisa,
    bool SenderPays
);

public sealed record MuteRequest(bool Muted);
