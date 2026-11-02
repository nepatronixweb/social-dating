using System.Security.Claims;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Admin;

/// <summary>
/// Soft RBAC for staff. Roles are claim values on the staff JWT.
/// support/trust — moderation + light user help; finance — money; superadmin — all.
/// </summary>
public static class StaffRoles
{
    public const string Support = "support";
    public const string Trust = "trust";
    public const string Finance = "finance";
    public const string Superadmin = "superadmin";

    public static readonly string[] All = [Support, Trust, Finance, Superadmin];

    public static bool IsKnown(string? role)
    {
        var r = Normalize(role);
        return r is Support or Trust or Finance or Superadmin;
    }

    public static string Normalize(string? role) =>
        (role ?? "").Trim().ToLowerInvariant();

    public static bool CanSupportWrite(string? role)
    {
        var r = Normalize(role);
        return r is Support or Trust or Superadmin;
    }

    public static bool CanFinanceWrite(string? role)
    {
        var r = Normalize(role);
        return r is Finance or Superadmin;
    }

    public static bool CanSuperadminWrite(string? role) =>
        Normalize(role) == Superadmin;

    public static bool CanDestructiveModeration(string? role) =>
        CanSuperadminWrite(role);

    public static void RequireSupportWrite(ClaimsPrincipal user)
    {
        if (!CanSupportWrite(user.RequireStaffRole()))
        {
            throw new AuthException(
                403,
                "Support role required.",
                "This action needs support, trust, or superadmin."
            );
        }
    }

    public static void RequireFinanceWrite(ClaimsPrincipal user)
    {
        if (!CanFinanceWrite(user.RequireStaffRole()))
        {
            throw new AuthException(
                403,
                "Finance role required.",
                "This action needs finance or superadmin."
            );
        }
    }

    public static void RequireSuperadmin(ClaimsPrincipal user)
    {
        if (!CanSuperadminWrite(user.RequireStaffRole()))
        {
            throw new AuthException(
                403,
                "Superadmin required.",
                "This action is limited to superadmin staff."
            );
        }
    }
}
