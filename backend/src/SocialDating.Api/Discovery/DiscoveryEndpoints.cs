using SocialDating.Api.Auth;

namespace SocialDating.Api.Discovery;

public static class DiscoveryEndpoints
{
    public static void MapDiscoveryEndpoints(this WebApplication app)
    {
        var discovery = app.MapGroup("/v1/discovery").WithTags("Discovery").RequireAuthorization();
        discovery.MapGet("/candidates", FetchDeck);
        discovery.MapGet("/quota", FetchQuota);
        discovery.MapPost("/swipes", Swipe);
        discovery.MapPost("/undo", Undo);
        discovery.MapPost("/message", Message);
    }

    static async Task<IResult> FetchDeck(
        int? minAge,
        int? maxAge,
        string? showMe,
        bool? verifiedOnly,
        string? interests,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        var tags = string.IsNullOrWhiteSpace(interests)
            ? null
            : interests.Split(',', StringSplitOptions.TrimEntries | StringSplitOptions.RemoveEmptyEntries);
        var page = await discovery.FetchDeckAsync(
            http.User.RequireAccountId(),
            minAge,
            maxAge,
            showMe,
            verifiedOnly == true,
            tags,
            ct
        );
        return Results.Ok(page);
    }

    static async Task<IResult> FetchQuota(
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.FetchQuotaAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> Swipe(
        SwipeRequest body,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.SwipeAsync(http.User.RequireAccountId(), body, ct));

    static async Task<IResult> Undo(
        UndoRequest? body,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        var result = await discovery.UndoLastAsync(
            http.User.RequireAccountId(),
            body ?? new UndoRequest(false),
            ct
        );
        return result is null ? Results.NoContent() : Results.Ok(result);
    }

    static async Task<IResult> Message(
        DiscoveryMessageRequest body,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.MessageAsync(http.User.RequireAccountId(), body, ct));
}
