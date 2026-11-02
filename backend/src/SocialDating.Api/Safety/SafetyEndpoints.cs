using System.Security.Claims;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Safety;

public static class SafetyEndpoints
{
    public static void MapSafetyEndpoints(this WebApplication app)
    {
        var safety = app.MapGroup("/v1/safety").WithTags("Safety").RequireAuthorization();
        safety.MapPost("/reports", Submit);
    }

    static async Task<IResult> Submit(
        SubmitReportRequest body,
        ClaimsPrincipal user,
        ISafetyService safety,
        CancellationToken ct
    ) => Results.Ok(await safety.SubmitReportAsync(user.RequireAccountId(), body, ct));
}
