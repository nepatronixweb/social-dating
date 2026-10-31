namespace SocialDating.Api.Chat;

public sealed record ChatPush(
    string Type,
    string ConversationId,
    MessageResponse? Message = null,
    bool? Typing = null
);
