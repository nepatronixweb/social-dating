using SocialDating.Api.Auth;

namespace SocialDating.Api.Discovery;

public static class MatchingEndpoints
{
    public static void MapMatchingEndpoints(this WebApplication app)
    {
        var likes = app.MapGroup("/v1/likes").WithTags("Likes").RequireAuthorization();
        likes.MapGet("/received", FetchReceived);
        likes.MapGet("/sent", FetchSent);
        likes.MapPost("/{profileId:guid}/back", LikeBack);
        likes.MapPost("/{profileId:guid}/decline", Decline);
        likes.MapDelete("/sent/{profileId:guid}", Withdraw);

        var matches = app.MapGroup("/v1/matches").WithTags("Matches").RequireAuthorization();
        matches.MapGet("", FetchMatches);
        matches.MapDelete("/{matchId:guid}", Unmatch);
        matches.MapPost("/{matchId:guid}/seen", MarkSeen);

        var blocks = app.MapGroup("/v1/blocks").WithTags("Blocks").RequireAuthorization();
        blocks.MapGet("", FetchBlocked);
        blocks.MapPost("/{profileId:guid}", Block);
        blocks.MapDelete("/{profileId:guid}", Unblock);
    }

    static async Task<IResult> FetchReceived(
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.FetchLikesReceivedAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchSent(
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.FetchLikesSentAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> LikeBack(
        Guid profileId,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.LikeBackAsync(http.User.RequireAccountId(), profileId, ct));

    static async Task<IResult> Decline(
        Guid profileId,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        await discovery.DeclineLikeAsync(http.User.RequireAccountId(), profileId, ct);
        return Results.NoContent();
    }

    static async Task<IResult> Withdraw(
        Guid profileId,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        await discovery.WithdrawLikeAsync(http.User.RequireAccountId(), profileId, ct);
        return Results.NoContent();
    }

    static async Task<IResult> FetchMatches(
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.FetchMatchesAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> Unmatch(
        Guid matchId,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        await discovery.UnmatchAsync(http.User.RequireAccountId(), matchId, ct);
        return Results.NoContent();
    }

    static async Task<IResult> MarkSeen(
        Guid matchId,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        await discovery.MarkMatchSeenAsync(http.User.RequireAccountId(), matchId, ct);
        return Results.NoContent();
    }

    static async Task<IResult> FetchBlocked(
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    ) => Results.Ok(await discovery.FetchBlockedAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> Block(
        Guid profileId,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        await discovery.BlockAsync(http.User.RequireAccountId(), profileId, ct);
        return Results.NoContent();
    }

    static async Task<IResult> Unblock(
        Guid profileId,
        HttpContext http,
        IDiscoveryService discovery,
        CancellationToken ct
    )
    {
        await discovery.UnblockAsync(http.User.RequireAccountId(), profileId, ct);
        return Results.NoContent();
    }
}
