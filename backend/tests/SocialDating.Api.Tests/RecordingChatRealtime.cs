using SocialDating.Api.Chat;

namespace SocialDating.Api.Tests;

sealed class RecordingChatRealtime : IChatRealtime
{
    public List<string> Events { get; } = [];

    public Task MessageSent(
        Guid conversationId,
        Guid senderId,
        Guid otherId,
        MessageResponse forOther,
        MessageResponse forSender,
        CancellationToken ct
    )
    {
        Events.Add($"message:{conversationId}:{otherId}:{forOther.IsMine}:{forSender.IsMine}");
        return Task.CompletedTask;
    }

    public Task Read(Guid conversationId, Guid readerId, Guid otherId, CancellationToken ct)
    {
        Events.Add($"read:{conversationId}:{otherId}");
        return Task.CompletedTask;
    }

    public Task Typing(Guid conversationId, Guid otherId, bool typing, CancellationToken ct)
    {
        Events.Add($"typing:{conversationId}:{otherId}:{typing}");
        return Task.CompletedTask;
    }

    public Task Closed(Guid conversationId, Guid accountA, Guid accountB, CancellationToken ct)
    {
        Events.Add($"closed:{conversationId}");
        return Task.CompletedTask;
    }
}
