using SocialDating.Api.Auth;

namespace SocialDating.Api.Inbox;

public static class InboxEndpoints
{
    public static void MapInboxEndpoints(this WebApplication app)
    {
        var inbox = app.MapGroup("/v1/notifications").WithTags("Notifications").RequireAuthorization();
        inbox.MapGet("", List);
        inbox.MapPost("/read-all", MarkAllRead);
        inbox.MapPost("/{id:guid}/read", MarkRead);
    }

    static async Task<IResult> List(
        HttpContext http,
        IInboxService inbox,
        CancellationToken ct
    ) => Results.Ok(await inbox.ListAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> MarkRead(
        Guid id,
        HttpContext http,
        IInboxService inbox,
        CancellationToken ct
    )
    {
        await inbox.MarkReadAsync(http.User.RequireAccountId(), id, ct);
        return Results.NoContent();
    }

    static async Task<IResult> MarkAllRead(
        HttpContext http,
        IInboxService inbox,
        CancellationToken ct
    )
    {
        await inbox.MarkAllReadAsync(http.User.RequireAccountId(), ct);
        return Results.NoContent();
    }
}
