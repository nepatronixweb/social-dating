using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Referrals;
using Xunit;

namespace SocialDating.Api.Tests;

public class ReferralServiceTests : IDisposable
{
    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly ReferralService _referrals;
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public ReferralServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        _referrals = new ReferralService(
            _db,
            new FixedTime(_now),
            Options.Create(new ReferralOptions())
        );
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task overview_assigns_a_unique_code_and_hides_the_phone()
    {
        var ada = SeedPerson("Ada", "female", "Kathmandu");
        await _db.SaveChangesAsync();

        var first = await _referrals.FetchInfoAsync(ada.Id, CancellationToken.None);
        Assert.False(string.IsNullOrWhiteSpace(first.Code));
        Assert.Equal(8, first.Code.Length);
        Assert.StartsWith("socialdating://invite/", first.InviteLink);
        Assert.Contains(first.Code, first.ShareMessage);
        Assert.Equal(0, first.InvitesSent);
        Assert.False(first.PayoutsEnabled);
        Assert.True(first.IsLive);
        Assert.Equal(ReferralService.CommissionPaisa, first.Allocation.ReferrerCommissionPaisa);
        Assert.DoesNotContain("phone", System.Text.Json.JsonSerializer.Serialize(first), StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain(ada.PhoneE164, System.Text.Json.JsonSerializer.Serialize(first));

        var second = await _referrals.FetchInfoAsync(ada.Id, CancellationToken.None);
        Assert.Equal(first.Code, second.Code);
    }

    [Fact]
    public async Task claiming_a_code_creates_a_pending_commission()
    {
        var ada = SeedPerson("Ada", "female", "Kathmandu");
        var nabin = SeedPerson("Nabin", "male", "Lalitpur");
        await _db.SaveChangesAsync();
        var adaInfo = await _referrals.FetchInfoAsync(ada.Id, CancellationToken.None);

        await _referrals.ClaimAsync(nabin.Id, adaInfo.Code, CancellationToken.None);

        var overview = await _referrals.FetchInfoAsync(ada.Id, CancellationToken.None);
        Assert.Equal(1, overview.InvitesSent);
        Assert.Equal(1, overview.FriendsJoined);
        Assert.Equal(ReferralService.CommissionPaisa, overview.PendingCommissionPaisa);
        Assert.Equal(0, overview.ApprovedCommissionPaisa);

        var invites = await _referrals.FetchInvitesAsync(ada.Id, CancellationToken.None);
        Assert.Single(invites.Items);
        Assert.Equal("Nabin", invites.Items[0].DisplayName);
        Assert.Equal("joined", invites.Items[0].Status);
        Assert.DoesNotContain("phone", System.Text.Json.JsonSerializer.Serialize(invites), StringComparison.OrdinalIgnoreCase);

        var commissions = await _referrals.FetchCommissionsAsync(ada.Id, CancellationToken.None);
        Assert.Single(commissions.Items);
        Assert.Equal("pending", commissions.Items[0].Status);
        Assert.Equal(ReferralService.CommissionPaisa, commissions.Items[0].AmountPaisa);

        var notice = await _db.InboxNotifications.SingleAsync();
        Assert.Equal(ada.Id, notice.AccountId);
        Assert.Equal("system", notice.Type);
        Assert.Contains("Nabin", notice.Body);
    }

    [Fact]
    public async Task you_cannot_use_your_own_code_or_claim_twice()
    {
        var ada = SeedPerson("Ada", "female", "Kathmandu");
        var nabin = SeedPerson("Nabin", "male", "Lalitpur");
        await _db.SaveChangesAsync();
        var adaInfo = await _referrals.FetchInfoAsync(ada.Id, CancellationToken.None);

        var own = await Assert.ThrowsAsync<AuthException>(
            () => _referrals.ClaimAsync(ada.Id, adaInfo.Code, CancellationToken.None)
        );
        Assert.Equal(400, own.StatusCode);

        var missing = await Assert.ThrowsAsync<AuthException>(
            () => _referrals.ClaimAsync(nabin.Id, "NOTACODE", CancellationToken.None)
        );
        Assert.Equal(400, missing.StatusCode);

        await _referrals.ClaimAsync(nabin.Id, adaInfo.Code.ToLowerInvariant(), CancellationToken.None);
        var again = await Assert.ThrowsAsync<AuthException>(
            () => _referrals.ClaimAsync(nabin.Id, adaInfo.Code, CancellationToken.None)
        );
        Assert.Equal(400, again.StatusCode);
    }

    [Fact]
    public async Task verify_can_attribute_a_new_account()
    {
        var ada = SeedPerson("Ada", "female", "Kathmandu");
        await _db.SaveChangesAsync();
        var adaInfo = await _referrals.FetchInfoAsync(ada.Id, CancellationToken.None);

        var nabin = SeedPerson("Nabin", "male", "Lalitpur");
        await _db.SaveChangesAsync();
        await _referrals.TryAttributeOnVerifyAsync(nabin.Id, adaInfo.Code, CancellationToken.None);

        Assert.Equal(ada.Id, (await _db.Accounts.SingleAsync(a => a.Id == nabin.Id)).ReferredByAccountId);
        var overview = await _referrals.FetchInfoAsync(ada.Id, CancellationToken.None);
        Assert.Equal(1, overview.FriendsJoined);
    }

    Account SeedPerson(string name, string gender, string city)
    {
        var account = new Account
        {
            Id = Guid.NewGuid(),
            PhoneE164 = $"+9779800{Interlocked.Increment(ref _phones):D6}",
            CreatedAt = _now,
            UpdatedAt = _now,
            TermsAcceptedAt = _now,
            AgeEligible = true,
            AgeCheckedAt = _now,
            BirthDate = new DateOnly(1998, 3, 7),
            DisplayName = name,
            City = city,
            Gender = gender,
            Interests = ["Hiking", "Coffee", "Film"],
        };
        _db.Accounts.Add(account);
        return account;
    }

    sealed class FixedTime(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
