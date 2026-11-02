using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;

namespace SocialDating.Api.Subscription;

public interface ISubscriptionService
{
    Task<SubscriptionOverviewResponse> FetchOverviewAsync(Guid accountId, CancellationToken ct);
    Task<SubscriptionPlanListResponse> FetchPlansAsync(Guid accountId, CancellationToken ct);
    Task<PurchaseListResponse> FetchHistoryAsync(Guid accountId, CancellationToken ct);
    Task SubmitCheckoutAsync(Guid accountId, SubmitCheckoutRequest body, CancellationToken ct);
}

public sealed class SubscriptionService(AppDbContext db) : ISubscriptionService
{
    public const string StandardPlanId = "npr-100";
    public const string ComplimentaryPlanId = "included";
    public const int MinPricePaisa = 1000;
    public const int SuggestedPricePaisa = 10000;

    static readonly string[] ComplimentaryFeatures =
    [
        "See who likes you",
        "Unlimited likes",
        "Priority in discovery",
        "No daily swipe limit",
    ];

    public async Task<SubscriptionOverviewResponse> FetchOverviewAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        var complimentary = ProfileRules.HasComplimentaryPremium(account);
        var needsPaid = ProfileRules.NeedsPaidSubscription(account);
        return new SubscriptionOverviewResponse(
            needsPaid,
            complimentary,
            complimentary,
            false,
            true,
            complimentary ? ComplimentaryActive(account.CreatedAt) : null
        );
    }

    public async Task<SubscriptionPlanListResponse> FetchPlansAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        return new SubscriptionPlanListResponse(PaidPlans());
    }

    public async Task<PurchaseListResponse> FetchHistoryAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        return new PurchaseListResponse([]);
    }

    public async Task SubmitCheckoutAsync(
        Guid accountId,
        SubmitCheckoutRequest body,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        if (!body.Confirmed)
        {
            throw new AuthException(
                400,
                "Confirm first.",
                "Confirm this purchase before continuing."
            );
        }

        if (ProfileRules.HasComplimentaryPremium(account)
            || !ProfileRules.NeedsPaidSubscription(account))
        {
            throw new AuthException(
                400,
                "Not needed.",
                "Premium is included with female, LGBTQ+ and other accounts. Only male accounts can buy a subscription."
            );
        }

        throw new AuthException(
            400,
            "Not available.",
            "Payments are not enabled yet. Premium is not charged from this server."
        );
    }

    async Task<Account> RequireAccount(Guid accountId, CancellationToken ct)
    {
        var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == accountId, ct);
        if (account is null)
        {
            throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        }

        return account;
    }

    static ActiveSubscriptionResponse ComplimentaryActive(DateTimeOffset startedAt) =>
        new(
            ComplimentaryPlan(),
            startedAt,
            null,
            null,
            false,
            true
        );

    static SubscriptionPlanResponse ComplimentaryPlan() =>
        new(
            ComplimentaryPlanId,
            "Included",
            0,
            "with your account",
            ComplimentaryFeatures,
            false,
            null,
            false,
            "Included"
        );

    /// Paid plan cards are removed; male checkout is amount-only on the client.
    static IReadOnlyList<SubscriptionPlanResponse> PaidPlans() => [];
}
