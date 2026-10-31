using SocialDating.Api.Auth;

namespace SocialDating.Api.Chat;

public static class ChatEndpoints
{
    public static void MapChatEndpoints(this WebApplication app)
    {
        var chats = app.MapGroup("/v1/chats").WithTags("Chat").RequireAuthorization();
        chats.MapGet("", FetchPreviews);
        chats.MapGet("/{conversationId:guid}/messages", FetchMessages);
        chats.MapPost("/{conversationId:guid}/messages", Send);
        chats.MapPost("/{conversationId:guid}/photos", UploadPhoto).DisableAntiforgery();
        chats.MapPost("/{conversationId:guid}/read", MarkRead);
        chats.MapPost("/{conversationId:guid}/mute", Mute);
        chats.MapPost("/{conversationId:guid}/hide", Hide);
    }

    static async Task<IResult> FetchPreviews(
        HttpContext http,
        IChatService chat,
        CancellationToken ct
    ) => Results.Ok(await chat.FetchPreviewsAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchMessages(
        Guid conversationId,
        HttpContext http,
        IChatService chat,
        CancellationToken ct
    ) => Results.Ok(await chat.FetchMessagesAsync(http.User.RequireAccountId(), conversationId, ct));

    static async Task<IResult> Send(
        Guid conversationId,
        SendMessageRequest body,
        HttpContext http,
        IChatService chat,
        CancellationToken ct
    ) => Results.Ok(await chat.SendAsync(http.User.RequireAccountId(), conversationId, body, ct));

    static async Task<IResult> UploadPhoto(
        Guid conversationId,
        HttpContext http,
        IChatService chat,
        IFormFile? file,
        CancellationToken ct
    )
    {
        if (file is null || file.Length == 0)
            throw new AuthException(400, "Choose a photo to upload.", "Choose a photo to upload.");

        await using var stream = file.OpenReadStream();
        var item = await chat.UploadPhotoAsync(
            http.User.RequireAccountId(),
            conversationId,
            stream,
            file.ContentType,
            file.Length,
            ct);
        return Results.Json(item);
    }

    static async Task<IResult> MarkRead(
        Guid conversationId,
        HttpContext http,
        IChatService chat,
        CancellationToken ct
    )
    {
        await chat.MarkReadAsync(http.User.RequireAccountId(), conversationId, ct);
        return Results.NoContent();
    }

    static async Task<IResult> Mute(
        Guid conversationId,
        MuteRequest body,
        HttpContext http,
        IChatService chat,
        CancellationToken ct
    )
    {
        await chat.SetMutedAsync(http.User.RequireAccountId(), conversationId, body.Muted, ct);
        return Results.NoContent();
    }

    static async Task<IResult> Hide(
        Guid conversationId,
        HttpContext http,
        IChatService chat,
        CancellationToken ct
    )
    {
        await chat.HideAsync(http.User.RequireAccountId(), conversationId, ct);
        return Results.NoContent();
    }
}
