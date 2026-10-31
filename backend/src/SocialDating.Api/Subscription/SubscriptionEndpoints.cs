using SocialDating.Api.Auth;

namespace SocialDating.Api.Subscription;

public static class SubscriptionEndpoints
{
    public static void MapSubscriptionEndpoints(this WebApplication app)
    {
        var subscription = app.MapGroup("/v1/subscription").WithTags("Subscription").RequireAuthorization();
        subscription.MapGet("", FetchOverview);
        subscription.MapGet("/plans", FetchPlans);
        subscription.MapGet("/history", FetchHistory);
        subscription.MapPost("/checkout", SubmitCheckout);
    }

    static async Task<IResult> FetchOverview(
        HttpContext http,
        ISubscriptionService subscriptions,
        CancellationToken ct
    ) => Results.Ok(await subscriptions.FetchOverviewAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchPlans(
        HttpContext http,
        ISubscriptionService subscriptions,
        CancellationToken ct
    ) => Results.Ok(await subscriptions.FetchPlansAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchHistory(
        HttpContext http,
        ISubscriptionService subscriptions,
        CancellationToken ct
    ) => Results.Ok(await subscriptions.FetchHistoryAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> SubmitCheckout(
        SubmitCheckoutRequest body,
        HttpContext http,
        ISubscriptionService subscriptions,
        CancellationToken ct
    )
    {
        await subscriptions.SubmitCheckoutAsync(http.User.RequireAccountId(), body, ct);
        return Results.BadRequest();
    }
}
