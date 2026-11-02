using System.Security.Claims;

namespace SocialDating.Api.Admin;

public static class AdminOpsEndpoints
{
    public static void MapAdminOpsEndpoints(this RouteGroupBuilder read, RouteGroupBuilder support, RouteGroupBuilder super)
    {
        read.MapGet("/overview", LiveOverview);
        read.MapGet("/ops/overview", LiveOverview);
        read.MapGet("/marketplace/health", MarketplaceHealth);
        read.MapGet("/config", GetConfig);
        read.MapGet("/config/history", ConfigHistory);
        read.MapGet("/moderation/photos", PhotoQueue);
        read.MapGet("/moderation/messages", MessageQueue);

        support.MapPost("/moderation/photos/{id:guid}/visibility", SetPhotoVisibility);
        support.MapPost("/moderation/messages/{id:guid}/visibility", SetMessageVisibility);

        super.MapPut("/config", UpdateConfig);
    }

    static async Task<IResult> LiveOverview(IAdminOpsService ops, CancellationToken ct) =>
        Results.Ok(await ops.LiveOverviewAsync(ct));

    static async Task<IResult> MarketplaceHealth(IAdminOpsService ops, CancellationToken ct) =>
        Results.Ok(await ops.MarketplaceHealthAsync(ct));

    static async Task<IResult> GetConfig(IAdminOpsService ops, CancellationToken ct) =>
        Results.Ok(await ops.GetConfigAsync(ct));

    static async Task<IResult> ConfigHistory(IAdminOpsService ops, CancellationToken ct) =>
        Results.Ok(await ops.ConfigHistoryAsync(ct));

    static async Task<IResult> UpdateConfig(
        UpdateRuntimeConfigRequest body,
        HttpContext http,
        IAdminOpsService ops,
        CancellationToken ct
    ) => Results.Ok(await ops.UpdateConfigAsync(body, http.User, ct));

    static async Task<IResult> PhotoQueue(
        IAdminOpsService ops,
        string? filter,
        CancellationToken ct
    ) => Results.Ok(await ops.PhotoQueueAsync(filter, ct));

    static async Task<IResult> SetPhotoVisibility(
        Guid id,
        ModerationHideRequest body,
        HttpContext http,
        IAdminOpsService ops,
        CancellationToken ct
    )
    {
        await ops.SetPhotoHiddenAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> MessageQueue(
        IAdminOpsService ops,
        string? q,
        CancellationToken ct
    ) => Results.Ok(await ops.MessageQueueAsync(q, ct));

    static async Task<IResult> SetMessageVisibility(
        Guid id,
        ModerationHideRequest body,
        HttpContext http,
        IAdminOpsService ops,
        CancellationToken ct
    )
    {
        await ops.SetMessageHiddenAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }
}
