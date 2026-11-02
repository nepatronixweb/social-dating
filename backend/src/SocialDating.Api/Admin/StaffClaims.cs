using System.Security.Claims;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Admin;

public static class StaffClaims
{
    public const string TokenType = "staff";
    public const string TypeClaim = "typ";
    public const string RoleClaim = "staff_role";
    public const string EmailClaim = "staff_email";
    public const string PolicyName = "AdminStaff";
    public const string SupportWritePolicy = "AdminSupportWrite";
    public const string FinanceWritePolicy = "AdminFinanceWrite";
    public const string SuperadminPolicy = "AdminSuperadmin";

    public static Guid RequireStaffId(this ClaimsPrincipal user)
    {
        if (!string.Equals(user.FindFirstValue(TypeClaim), TokenType, StringComparison.Ordinal))
        {
            throw new AuthException(403, "Staff access required.", "This action is limited to admin staff.");
        }

        var raw =
            user.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? user.FindFirstValue("sub");
        if (raw is null || !Guid.TryParse(raw, out var id))
        {
            throw new AuthException(401, "Please sign in again.", "The staff session is no longer valid.");
        }

        return id;
    }

    public static string RequireStaffEmail(this ClaimsPrincipal user) =>
        user.FindFirstValue(EmailClaim)
        ?? throw new AuthException(401, "Please sign in again.", "The staff session is no longer valid.");

    public static string RequireStaffRole(this ClaimsPrincipal user) =>
        user.FindFirstValue(RoleClaim)
        ?? throw new AuthException(401, "Please sign in again.", "The staff session is no longer valid.");
}
