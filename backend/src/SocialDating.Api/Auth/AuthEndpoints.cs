using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;

namespace SocialDating.Api.Auth;

public static class AuthEndpoints
{
    public static void MapAuthEndpoints(this WebApplication app)
    {
        var auth = app.MapGroup("/v1/auth").WithTags("Auth");
        auth.MapPost("/code", RequestCode);
        auth.MapPost("/verify", Verify);
        auth.MapPost("/refresh", Refresh);
        auth.MapPost("/sign-out", SignOut).RequireAuthorization();

        var me = app.MapGroup("/v1/me").WithTags("Me").RequireAuthorization();
        me.MapGet("", GetMe);
        me.MapPost("/terms", AcceptTerms);
        me.MapPost("/age", SubmitAge);
        me.MapPost("/gender", SetGender);
        me.MapPost("/profile", CompleteProfile);
        me.MapDelete("", DeleteAccount);
    }

    static async Task<IResult> RequestCode(
        RequestCodeRequest body,
        IAuthService auth,
        CancellationToken ct
    )
    {
        var result = await auth.RequestCodeAsync(body.Phone, ct);
        return Results.Ok(result);
    }

    static async Task<IResult> Verify(
        VerifyCodeRequest body,
        HttpContext http,
        IAuthService auth,
        CancellationToken ct
    )
    {
        var result = await auth.VerifyAsync(
            body.Phone,
            body.Code,
            ct,
            body.ReferralCode,
            body.Login,
            ClientContext.FromHttp(http)
        );
        return Results.Ok(result);
    }

    static async Task<IResult> Refresh(
        RefreshRequest body,
        HttpContext http,
        IAuthService auth,
        CancellationToken ct
    )
    {
        var result = await auth.RefreshAsync(
            body.RefreshToken,
            ct,
            ClientContext.FromHttp(http)
        );
        return Results.Ok(result);
    }

    static async Task<IResult> SignOut(
        ClaimsPrincipal user,
        [FromBody] RefreshRequest? body,
        IAuthService auth,
        CancellationToken ct
    )
    {
        await auth.SignOutAsync(user.RequireAccountId(), body?.RefreshToken, ct);
        return Results.NoContent();
    }

    static async Task<IResult> GetMe(ClaimsPrincipal user, IAuthService auth, CancellationToken ct) =>
        Results.Ok(await auth.GetMeAsync(user.RequireAccountId(), ct));

    static async Task<IResult> AcceptTerms(
        ClaimsPrincipal user,
        IAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.AcceptTermsAsync(user.RequireAccountId(), ct));

    static async Task<IResult> SubmitAge(
        SubmitAgeRequest body,
        ClaimsPrincipal user,
        IAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.SubmitAgeAsync(user.RequireAccountId(), body.BirthDate, ct));

    static async Task<IResult> SetGender(
        SetGenderRequest body,
        ClaimsPrincipal user,
        IAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.SetGenderAsync(user.RequireAccountId(), body.Gender, ct));

    static async Task<IResult> CompleteProfile(
        CompleteProfileRequest body,
        ClaimsPrincipal user,
        IAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.CompleteProfileAsync(user.RequireAccountId(), body, ct));

    static async Task<IResult> DeleteAccount(
        ClaimsPrincipal user,
        IAuthService auth,
        CancellationToken ct
    )
    {
        await auth.DeleteAccountAsync(user.RequireAccountId(), ct);
        return Results.NoContent();
    }

}
