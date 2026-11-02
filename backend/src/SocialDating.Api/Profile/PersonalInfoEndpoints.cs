using System.Security.Claims;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Profile;

public static class PersonalInfoEndpoints
{
    public static void MapPersonalInfoEndpoints(this WebApplication app)
    {
        var group = app.MapGroup("/v1/me/personal-info")
            .WithTags("PersonalInfo")
            .RequireAuthorization();
        group.MapGet("", Get);
        group.MapPut("", Upsert);
    }

    static async Task<IResult> Get(
        ClaimsPrincipal user,
        IPersonalInfoService personal,
        CancellationToken ct
    ) => Results.Ok(await personal.GetAsync(user.RequireAccountId(), ct));

    static async Task<IResult> Upsert(
        UpsertPersonalInfoRequest body,
        ClaimsPrincipal user,
        IPersonalInfoService personal,
        CancellationToken ct
    ) => Results.Ok(await personal.UpsertAsync(user.RequireAccountId(), body, ct));
}
