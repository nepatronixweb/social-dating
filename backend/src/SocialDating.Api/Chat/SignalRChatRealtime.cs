using Microsoft.AspNetCore.SignalR;

namespace SocialDating.Api.Chat;

public sealed class SignalRChatRealtime(IHubContext<ChatHub> hub) : IChatRealtime
{
    public Task MessageSent(
        Guid conversationId,
        Guid senderId,
        Guid otherId,
        MessageResponse forOther,
        MessageResponse forSender,
        CancellationToken ct
    ) => Task.WhenAll(
        Push(otherId, new ChatPush("message", conversationId.ToString(), forOther), ct),
        Push(senderId, new ChatPush("message", conversationId.ToString(), forSender), ct)
    );

    public Task Read(Guid conversationId, Guid readerId, Guid otherId, CancellationToken ct) =>
        Push(otherId, new ChatPush("read", conversationId.ToString()), ct);

    public Task Typing(Guid conversationId, Guid otherId, bool typing, CancellationToken ct) =>
        Push(otherId, new ChatPush("typing", conversationId.ToString(), Typing: typing), ct);

    public Task Closed(Guid conversationId, Guid accountA, Guid accountB, CancellationToken ct) =>
        Task.WhenAll(
            Push(accountA, new ChatPush("closed", conversationId.ToString()), ct),
            Push(accountB, new ChatPush("closed", conversationId.ToString()), ct)
        );

    async Task Push(Guid accountId, ChatPush payload, CancellationToken ct)
    {
        try
        {
            await hub.Clients.User(accountId.ToString()).SendAsync("event", payload, ct);
        }
        catch
        {
            // REST is the source of truth. A dropped socket must not fail a send.
        }
    }
}
