namespace SocialDating.Api.Admin;

public static class AdminDeskEndpoints
{
    public static void MapAdminDeskEndpoints(
        this RouteGroupBuilder read,
        RouteGroupBuilder finance
    )
    {
        read.MapGet("/queues/attention", Attention);
        read.MapGet("/payouts/run", PayoutRun);
        read.MapGet("/revenue/today", RevenueToday);
        read.MapGet("/staff/activity", StaffActivity);

        finance.MapPost("/payouts/run/mark-paid", MarkPayoutRun);
    }

    static async Task<IResult> Attention(IAdminDeskService desk, CancellationToken ct) =>
        Results.Ok(await desk.AttentionAsync(ct));

    static async Task<IResult> PayoutRun(IAdminDeskService desk, CancellationToken ct) =>
        Results.Ok(await desk.PayoutRunAsync(ct));

    static async Task<IResult> RevenueToday(IAdminDeskService desk, CancellationToken ct) =>
        Results.Ok(await desk.RevenueAsync(ct));

    static async Task<IResult> StaffActivity(IAdminDeskService desk, CancellationToken ct) =>
        Results.Ok(await desk.StaffActivityAsync(ct));

    static async Task<IResult> MarkPayoutRun(
        MarkPayoutRunRequest body,
        HttpContext http,
        IAdminDeskService desk,
        CancellationToken ct
    ) => Results.Ok(await desk.MarkPayoutRunAsync(body, http.User, ct));
}
