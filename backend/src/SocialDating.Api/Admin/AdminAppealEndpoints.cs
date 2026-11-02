using System.Security.Claims;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Admin;

public static class AdminAppealEndpoints
{
    public static void MapAdminAppealEndpoints(
        this RouteGroupBuilder read,
        RouteGroupBuilder support
    )
    {
        read.MapGet("/appeals", ListAppeals);
        support.MapPost("/users/{id:guid}/appeals", CreateAppeal);
        support.MapPost("/appeals/{id:guid}/resolve", ResolveAppeal);
    }

    public static void MapUserAppealEndpoints(this WebApplication app)
    {
        var me = app.MapGroup("/v1/me").RequireAuthorization();
        me.MapPost("/appeals", CreateMine);

        app.MapGet("/v1/app/client-config", ClientConfig).AllowAnonymous().WithTags("App");
    }

    static async Task<IResult> ListAppeals(
        IAdminAppealService appeals,
        string? status,
        string? sla,
        CancellationToken ct
    ) => Results.Ok(await appeals.ListAsync(status, sla, ct));

    static async Task<IResult> CreateAppeal(
        Guid id,
        CreateAppealRequest body,
        HttpContext http,
        IAdminAppealService appeals,
        CancellationToken ct
    ) => Results.Ok(await appeals.CreateForUserAsync(id, body, http.User, ct));

    static async Task<IResult> ResolveAppeal(
        Guid id,
        ResolveAppealRequest body,
        HttpContext http,
        IAdminAppealService appeals,
        CancellationToken ct
    ) => Results.Ok(await appeals.ResolveAsync(id, body, http.User, ct));

    static async Task<IResult> CreateMine(
        CreateAppealRequest body,
        ClaimsPrincipal user,
        IAdminAppealService appeals,
        CancellationToken ct
    )
    {
        var accountId = user.RequireAccountId();
        return Results.Ok(await appeals.CreateMineAsync(accountId, body, ct));
    }

    static async Task<IResult> ClientConfig(
        IAdminAppealService appeals,
        CancellationToken ct
    ) => Results.Ok(await appeals.ClientConfigAsync(ct));
}
