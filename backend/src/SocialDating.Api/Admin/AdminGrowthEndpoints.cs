namespace SocialDating.Api.Admin;

public static class AdminGrowthEndpoints
{
    public static void MapAdminGrowthEndpoints(
        this RouteGroupBuilder read,
        RouteGroupBuilder support,
        RouteGroupBuilder finance
    )
    {
        read.MapGet("/promos", ListPromos);

        finance.MapPost("/promos", CreatePromo);
        finance.MapPost("/promos/{id:guid}/active", SetPromoActive);

        support.MapPost("/broadcast", Broadcast);
    }

    static async Task<IResult> ListPromos(IAdminGrowthService growth, CancellationToken ct) =>
        Results.Ok(await growth.ListPromoCodesAsync(ct));

    static async Task<IResult> CreatePromo(
        CreatePromoCodeRequest body,
        HttpContext http,
        IAdminGrowthService growth,
        CancellationToken ct
    ) => Results.Ok(await growth.CreatePromoCodeAsync(body, http.User, ct));

    static async Task<IResult> SetPromoActive(
        Guid id,
        SetPromoActiveRequest body,
        HttpContext http,
        IAdminGrowthService growth,
        CancellationToken ct
    )
    {
        await growth.SetPromoActiveAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> Broadcast(
        BroadcastRequest body,
        HttpContext http,
        IAdminGrowthService growth,
        CancellationToken ct
    ) => Results.Ok(await growth.BroadcastAsync(body, http.User, ct));
}
