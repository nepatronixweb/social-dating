using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Data;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Discovery;

public static class DiscoverySeeder
{
    public static async Task SeedAsync(IServiceProvider services, CancellationToken ct = default)
    {
        using var scope = services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        await AdminAccount.EnsureAsync(db, DateTimeOffset.UtcNow, ct);
        await db.SaveChangesAsync(ct);

        if (!await db.Accounts.AnyAsync(a => a.PhoneE164.StartsWith("+97798110000"), ct))
        {
            await SeedDemoProfilesAsync(db, ct);
        }

        await SeedInboundForMembersAsync(db, ct);
    }

    static async Task SeedDemoProfilesAsync(AppDbContext db, CancellationToken ct)
    {
        var now = DateTimeOffset.UtcNow;
        var adult = DateOnly.FromDateTime(now.UtcDateTime).AddYears(-26);
        var profiles = new (string Phone, string Name, string City, string Gender, string Bio, string[] Interests)[]
        {
            ("+9779811000001", "Asha", "Kathmandu", "female", "Hikes on Saturday.", ["Hiking", "Coffee", "Film"]),
            ("+9779811000002", "Nabin", "Lalitpur", "male", "Cooks too much dal bhat.", ["Cooking", "Music", "Travel"]),
            ("+9779811000003", "Maya", "Pokhara", "female", "Lakeside mornings.", ["Yoga", "Books", "Dogs"]),
            ("+9779811000004", "Kiran", "Bhaktapur", "lgbtq", "Photographs courtyards.", ["Photography", "Art", "Film"]),
            ("+9779811000005", "Sita", "Kathmandu", "female", "Runs before work.", ["Running", "Coffee", "Hiking"]),
            ("+9779811000006", "Arjun", "Dharan", "male", "Guitar on the roof.", ["Music", "Film", "Travel"]),
            ("+9779811000007", "Pooja", "Bharatpur", "female", "Always planning a trip.", ["Travel", "Books", "Cooking"]),
            ("+9779811000008", "Ravi", "Nepalgunj", "other", "Climbs on weekends.", ["Climbing", "Hiking", "Photography"]),
        };

        foreach (var row in profiles)
        {
            db.Accounts.Add(
                new Account
                {
                    Id = Guid.NewGuid(),
                    PhoneE164 = row.Phone,
                    CreatedAt = now,
                    UpdatedAt = now,
                    TermsAcceptedAt = now,
                    AgeEligible = true,
                    AgeCheckedAt = now,
                    BirthDate = adult,
                    DisplayName = row.Name,
                    Bio = row.Bio,
                    Interests = row.Interests,
                    City = row.City,
                    Gender = row.Gender,
                }
            );
        }

        await db.SaveChangesAsync(ct);
    }

    static async Task SeedInboundForMembersAsync(AppDbContext db, CancellationToken ct)
    {
        var demos = await db.Accounts
            .Where(a => a.PhoneE164.StartsWith("+97798110000"))
            .ToListAsync(ct);
        if (demos.Count == 0) return;

        var members = (await db.Accounts
            .Where(a =>
                a.DisplayName != null
                && a.City != null
                && a.Gender != null
                && a.AgeEligible == true)
            .ToListAsync(ct))
            .Where(a => !a.PhoneE164.StartsWith("+97798110000"))
            .ToList();
        if (members.Count == 0) return;

        var existing = await db.Swipes.ToListAsync(ct);
        var now = DateTimeOffset.UtcNow;
        foreach (var member in members)
        {
            foreach (var demo in demos.Take(3))
            {
                if (demo.Id == member.Id) continue;
                if (existing.Any(s =>
                    s.FromAccountId == demo.Id
                    && s.ToAccountId == member.Id
                    && s.UndoneAt == null))
                {
                    continue;
                }

                db.Swipes.Add(new Swipe
                {
                    Id = Guid.NewGuid(),
                    FromAccountId = demo.Id,
                    ToAccountId = member.Id,
                    Direction = "right",
                    CreatedAt = now,
                });
            }
        }

        await db.SaveChangesAsync(ct);
    }
}
