using SocialDating.Api.Auth;

namespace SocialDating.Api.Referrals;

public static class ReferralEndpoints
{
    public static void MapReferralEndpoints(this WebApplication app)
    {
        var referrals = app.MapGroup("/v1/referrals").WithTags("Referrals").RequireAuthorization();
        referrals.MapGet("", FetchInfo);
        referrals.MapGet("/invites", FetchInvites);
        referrals.MapGet("/commissions", FetchCommissions);
        referrals.MapGet("/commissions/{id:guid}", FetchCommission);
        referrals.MapPost("/claim", Claim);
    }

    static async Task<IResult> FetchInfo(
        HttpContext http,
        IReferralService referrals,
        CancellationToken ct
    ) => Results.Ok(await referrals.FetchInfoAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchInvites(
        HttpContext http,
        IReferralService referrals,
        CancellationToken ct
    ) => Results.Ok(await referrals.FetchInvitesAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchCommissions(
        HttpContext http,
        IReferralService referrals,
        CancellationToken ct
    ) => Results.Ok(await referrals.FetchCommissionsAsync(http.User.RequireAccountId(), ct));

    static async Task<IResult> FetchCommission(
        Guid id,
        HttpContext http,
        IReferralService referrals,
        CancellationToken ct
    ) => Results.Ok(await referrals.FetchCommissionAsync(http.User.RequireAccountId(), id, ct));

    static async Task<IResult> Claim(
        ClaimReferralRequest body,
        HttpContext http,
        IReferralService referrals,
        CancellationToken ct
    )
    {
        await referrals.ClaimAsync(http.User.RequireAccountId(), body.Code, ct);
        return Results.NoContent();
    }
}
