using System.Security.Claims;

namespace SocialDating.Api.Auth;

public static class AccountClaims
{
    public static Guid RequireAccountId(this ClaimsPrincipal user)
    {
        var raw =
            user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? user.FindFirstValue("sub");
        if (raw is null || !Guid.TryParse(raw, out var id))
        {
            throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        }

        return id;
    }
}
