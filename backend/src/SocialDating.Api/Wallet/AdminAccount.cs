using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Data;

namespace SocialDating.Api.Wallet;

/// <summary>
/// System ledger account that receives premium discovery spend
/// (super like, discovery message, rewind).
/// </summary>
public static class AdminAccount
{
    public const string PhoneE164 = "+9779800000000";
    public const string DisplayName = "Admin";

    public static bool IsAdmin(Account account) =>
        string.Equals(account.PhoneE164, PhoneE164, StringComparison.Ordinal);

    public static bool IsAdminPhone(string? phoneE164) =>
        string.Equals(phoneE164, PhoneE164, StringComparison.Ordinal);

    public static async Task<Account> EnsureAsync(AppDbContext db, DateTimeOffset now, CancellationToken ct)
    {
        var existing = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.PhoneE164 == PhoneE164, ct);
        if (existing is not null) return existing;

        var admin = new Account
        {
            Id = Guid.NewGuid(),
            PhoneE164 = PhoneE164,
            CreatedAt = now,
            UpdatedAt = now,
            TermsAcceptedAt = now,
            AgeEligible = true,
            AgeCheckedAt = now,
            BirthDate = new DateOnly(1990, 1, 1),
            DisplayName = DisplayName,
            City = "Kathmandu",
            Gender = "other",
            Bio = "",
            Interests = [],
        };
        db.Accounts.Add(admin);
        return admin;
    }
}
