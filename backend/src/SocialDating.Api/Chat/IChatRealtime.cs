namespace SocialDating.Api.Chat;

public interface IChatRealtime
{
    Task MessageSent(
        Guid conversationId,
        Guid senderId,
        Guid otherId,
        MessageResponse forOther,
        MessageResponse forSender,
        CancellationToken ct
    );

    Task Read(Guid conversationId, Guid readerId, Guid otherId, CancellationToken ct);

    Task Typing(Guid conversationId, Guid otherId, bool typing, CancellationToken ct);

    Task Closed(Guid conversationId, Guid accountA, Guid accountB, CancellationToken ct);
}

public sealed class NullChatRealtime : IChatRealtime
{
    public static readonly NullChatRealtime Instance = new();

    public Task MessageSent(
        Guid conversationId,
        Guid senderId,
        Guid otherId,
        MessageResponse forOther,
        MessageResponse forSender,
        CancellationToken ct
    ) => Task.CompletedTask;

    public Task Read(Guid conversationId, Guid readerId, Guid otherId, CancellationToken ct) =>
        Task.CompletedTask;

    public Task Typing(Guid conversationId, Guid otherId, bool typing, CancellationToken ct) =>
        Task.CompletedTask;

    public Task Closed(Guid conversationId, Guid accountA, Guid accountB, CancellationToken ct) =>
        Task.CompletedTask;
}
