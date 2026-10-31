using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Chat;

[Authorize]
public sealed class ChatHub(IChatService chat) : Hub
{
    public async Task Typing(string conversationId, bool typing)
    {
        if (!Guid.TryParse(conversationId, out var id)) return;
        try
        {
            await chat.SetTypingAsync(Context.User!.RequireAccountId(), id, typing, Context.ConnectionAborted);
        }
        catch (AuthException)
        {
            Context.Abort();
        }
    }
}

public sealed class AccountUserIdProvider : IUserIdProvider
{
    public string? GetUserId(HubConnectionContext connection) =>
        connection.User?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
        ?? connection.User?.FindFirst("sub")?.Value;
}
