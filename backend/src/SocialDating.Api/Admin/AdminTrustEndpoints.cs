using System.Security.Claims;

namespace SocialDating.Api.Admin;

public static class AdminTrustEndpoints
{
    public static void MapAdminTrustEndpoints(
        this RouteGroupBuilder read,
        RouteGroupBuilder support
    )
    {
        read.MapGet("/fraud/signals", FraudDesk);
        read.MapGet("/users/{id:guid}/timeline", Timeline);
        read.MapGet("/users/{id:guid}/case-packet", CasePacket);
        read.MapGet("/users/{id:guid}/linked-accounts", LinkedAccounts);
        read.MapGet("/moderation/keyword-hits", KeywordHits);
        read.MapGet("/watchlist", Watchlist);
        read.MapGet("/auth-blocks", ListAuthBlocks);

        support.MapPost("/users/{id:guid}/case-notes", AddCaseNote);
        support.MapPost("/users/{id:guid}/shadow-ban", ShadowBan);
        support.MapPost("/users/{id:guid}/unshadow-ban", UnshadowBan);
        support.MapPost("/users/{id:guid}/watch", AddWatch);
        support.MapPost("/users/{id:guid}/unwatch", RemoveWatch);
        support.MapPost("/moderation/photos/{id:guid}/review", ReviewPhoto);
        support.MapPost("/moderation/photos/bulk-review", BulkReviewPhotos);
        support.MapPost("/moderation/keyword-hits/{id:guid}/resolve", ResolveKeywordHit);
        support.MapPost("/auth-blocks", AddAuthBlock);
        support.MapPost("/auth-blocks/{id:guid}/clear", ClearAuthBlock);
    }

    static async Task<IResult> FraudDesk(IAdminTrustService trust, CancellationToken ct) =>
        Results.Ok(await trust.FraudDeskAsync(ct));

    static async Task<IResult> Timeline(
        Guid id,
        IAdminTrustService trust,
        CancellationToken ct
    ) => Results.Ok(await trust.TimelineAsync(id, ct));

    static async Task<IResult> AddCaseNote(
        Guid id,
        AddCaseNoteRequest body,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    )
    {
        await trust.AddCaseNoteAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> ShadowBan(
        Guid id,
        ShadowBanRequest body,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    )
    {
        await trust.ShadowBanAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> UnshadowBan(
        Guid id,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    )
    {
        await trust.UnshadowBanAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> ReviewPhoto(
        Guid id,
        ReviewPhotoRequest body,
        HttpContext http,
        IAdminOpsService ops,
        CancellationToken ct
    )
    {
        await ops.ReviewPhotoAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> BulkReviewPhotos(
        BulkReviewPhotosRequest body,
        HttpContext http,
        IAdminOpsService ops,
        CancellationToken ct
    ) => Results.Ok(await ops.BulkReviewPhotosAsync(body, http.User, ct));

    static async Task<IResult> KeywordHits(
        IAdminTrustService trust,
        string? status,
        CancellationToken ct
    ) => Results.Ok(await trust.ListKeywordHitsAsync(status, ct));

    static async Task<IResult> ResolveKeywordHit(
        Guid id,
        ResolveKeywordHitRequest body,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    ) => Results.Ok(await trust.ResolveKeywordHitAsync(id, body, http.User, ct));

    static async Task<IResult> Watchlist(
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    ) => Results.Ok(await trust.ListWatchAsync(http.User, ct));

    static async Task<IResult> AddWatch(
        Guid id,
        AddWatchRequest body,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    ) => Results.Ok(await trust.AddWatchAsync(id, body, http.User, ct));

    static async Task<IResult> RemoveWatch(
        Guid id,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    )
    {
        await trust.RemoveWatchAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> CasePacket(
        Guid id,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    ) => Results.Ok(await trust.CasePacketAsync(id, http.User, ct));

    static async Task<IResult> LinkedAccounts(
        Guid id,
        IAdminTrustService trust,
        CancellationToken ct
    ) => Results.Ok(await trust.LinkedAccountsAsync(id, ct));

    static async Task<IResult> ListAuthBlocks(
        IAdminTrustService trust,
        bool? active,
        CancellationToken ct
    ) => Results.Ok(await trust.ListAuthBlocksAsync(active, ct));

    static async Task<IResult> AddAuthBlock(
        AddAuthBlockRequest body,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    ) => Results.Ok(await trust.AddAuthBlockAsync(body, http.User, ct));

    static async Task<IResult> ClearAuthBlock(
        Guid id,
        HttpContext http,
        IAdminTrustService trust,
        CancellationToken ct
    )
    {
        await trust.ClearAuthBlockAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }
}
