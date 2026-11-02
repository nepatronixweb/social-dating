using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Wallet;
using Xunit;

namespace SocialDating.Api.Tests;

public class WalletServiceTests : IDisposable
{
    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly WalletService _wallet;
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public WalletServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        _wallet = new WalletService(_db, new FixedTime(_now));
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task a_complete_profile_gets_the_welcome_bonus_once()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        await _db.SaveChangesAsync();

        var first = await _wallet.FetchSummaryAsync(ada.Id, CancellationToken.None);
        Assert.Equal(WalletService.WelcomeBonusPoints, first.PromotionalPoints);
        Assert.Equal(0, first.EarnedPoints);
        Assert.Equal(0, first.PendingWithdrawalPoints);

        var second = await _wallet.FetchSummaryAsync(ada.Id, CancellationToken.None);
        Assert.Equal(WalletService.WelcomeBonusPoints, second.PromotionalPoints);
        Assert.Single((await _wallet.FetchTransactionsAsync(ada.Id, CancellationToken.None)).Items);
        Assert.DoesNotContain(
            "phone",
            System.Text.Json.JsonSerializer.Serialize(first),
            StringComparison.OrdinalIgnoreCase
        );
    }

    [Fact]
    public async Task an_incomplete_profile_is_not_granted_points()
    {
        var bare = new Account
        {
            Id = Guid.NewGuid(),
            PhoneE164 = $"+9779700{Interlocked.Increment(ref _phones):D6}",
            CreatedAt = _now,
            UpdatedAt = _now,
        };
        _db.Accounts.Add(bare);
        await _db.SaveChangesAsync();

        var summary = await _wallet.FetchSummaryAsync(bare.Id, CancellationToken.None);
        Assert.Equal(0, summary.PromotionalPoints);
        Assert.Empty((await _wallet.FetchTransactionsAsync(bare.Id, CancellationToken.None)).Items);
    }

    [Fact]
    public async Task spend_uses_promotional_points_first()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        var charged = await _wallet.TryChargeAsync(
            nabin,
            40,
            "messageSpend",
            "Paid message",
            "Eligible words charged at 10 paisa each.",
            Guid.NewGuid().ToString(),
            CancellationToken.None
        );
        await _db.SaveChangesAsync();

        Assert.True(charged.Ok);
        Assert.Equal(40, charged.ChargedPaisa);
        var starting = WalletService.WelcomeBonusPoints + WalletService.DailyFreePointsMale;
        Assert.Equal(starting - 40, charged.BalancePaisa);

        var summary = await _wallet.FetchSummaryAsync(nabin.Id, CancellationToken.None);
        Assert.Equal(starting - 40, summary.PromotionalPoints);
        Assert.Equal(0, summary.EarnedPoints);
    }

    [Fact]
    public async Task a_charge_is_refused_when_the_balance_is_gone()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();
        var starting = WalletService.WelcomeBonusPoints + WalletService.DailyFreePointsMale;
        await _wallet.TryChargeAsync(
            nabin,
            starting,
            "messageSpend",
            "Paid message",
            "Eligible words charged at 10 paisa each.",
            Guid.NewGuid().ToString(),
            CancellationToken.None
        );
        await _db.SaveChangesAsync();

        var refused = await _wallet.TryChargeAsync(
            nabin,
            10,
            "swipeSpend",
            "Paid swipe",
            "NPR 0.10 charged as 10 points for an extra swipe.",
            Guid.NewGuid().ToString(),
            CancellationToken.None
        );
        Assert.False(refused.Ok);
        Assert.Equal(0, refused.BalancePaisa);
    }

    [Fact]
    public async Task a_paid_swipe_refund_returns_the_points()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();
        var source = Guid.NewGuid().ToString();
        await _wallet.TryChargeAsync(
            nabin,
            10,
            "swipeSpend",
            "Paid swipe",
            "NPR 0.10 charged as 10 points for an extra swipe.",
            source,
            CancellationToken.None
        );
        await _db.SaveChangesAsync();

        await _wallet.RefundAsync(nabin.Id, source, CancellationToken.None);
        await _db.SaveChangesAsync();
        await _wallet.RefundAsync(nabin.Id, source, CancellationToken.None);
        await _db.SaveChangesAsync();

        var summary = await _wallet.FetchSummaryAsync(nabin.Id, CancellationToken.None);
        Assert.Equal(
            WalletService.WelcomeBonusPoints + WalletService.DailyFreePointsMale,
            summary.PromotionalPoints
        );
    }

    [Fact]
    public async Task unsubscribed_males_receive_daily_free_points_once_per_nepal_day()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        var first = await _wallet.FetchSummaryAsync(nabin.Id, CancellationToken.None);
        Assert.Equal(
            WalletService.WelcomeBonusPoints + WalletService.DailyFreePointsMale,
            first.PromotionalPoints
        );

        var second = await _wallet.FetchSummaryAsync(nabin.Id, CancellationToken.None);
        Assert.Equal(first.PromotionalPoints, second.PromotionalPoints);
        Assert.Equal(
            2,
            (await _wallet.FetchTransactionsAsync(nabin.Id, CancellationToken.None)).Items.Count
        );
    }

    [Fact]
    public async Task charge_to_admin_credits_the_admin_ledger()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        var charge = await _wallet.ChargeToAdminAsync(
            nabin,
            WalletService.PremiumActionPricePoints,
            "superLikeSpend",
            "Super like",
            "100 points for a super like.",
            Guid.NewGuid().ToString(),
            CancellationToken.None
        );
        await _db.SaveChangesAsync();

        Assert.True(charge.Ok);
        var admin = await _db.Accounts.SingleAsync(a => a.PhoneE164 == AdminAccount.PhoneE164);
        var adminWallet = await _wallet.FetchSummaryAsync(admin.Id, CancellationToken.None);
        Assert.Equal(WalletService.PremiumActionPricePoints, adminWallet.EarnedPoints);
    }

    [Fact]
    public async Task a_woman_can_record_and_cancel_a_withdrawal_without_a_payout()
    {
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();
        await _wallet.CreditEarnedAsync(
            asha.Id,
            610,
            "messageReceived",
            "Eligible messaging",
            "Earned points from a paid message. Not cash and not a payout.",
            Guid.NewGuid().ToString("D") + ":earn",
            CancellationToken.None
        );
        await _db.SaveChangesAsync();

        var eligibility = await _wallet.FetchEligibilityAsync(asha.Id, CancellationToken.None);
        Assert.True(eligibility.EligibleAccount);
        Assert.True(eligibility.CanSubmit);
        Assert.Equal(610, eligibility.EarnedAvailable);
        Assert.False(eligibility.PayoutsEnabled);
        Assert.True(eligibility.IsLive);

        var refused = await Assert.ThrowsAsync<AuthException>(() =>
            _wallet.SubmitWithdrawalAsync(
                asha.Id,
                new SubmitWithdrawalRequest(500, false),
                CancellationToken.None
            )
        );
        Assert.Equal(400, refused.StatusCode);

        var recorded = await _wallet.SubmitWithdrawalAsync(
            asha.Id,
            new SubmitWithdrawalRequest(500, true),
            CancellationToken.None
        );
        Assert.Equal("recorded", recorded.Status);
        Assert.NotEqual("paid", recorded.Status);
        Assert.False(recorded.PayoutsEnabled);

        var after = await _wallet.FetchSummaryAsync(asha.Id, CancellationToken.None);
        Assert.Equal(110, after.EarnedPoints);
        Assert.Equal(500, after.PendingWithdrawalPoints);
        Assert.Equal(WalletService.WelcomeBonusPoints, after.PromotionalPoints);

        var blocked = await _wallet.FetchEligibilityAsync(asha.Id, CancellationToken.None);
        Assert.False(blocked.CanSubmit);

        var cancelled = await _wallet.CancelWithdrawalAsync(
            asha.Id,
            Guid.Parse(recorded.Id),
            CancellationToken.None
        );
        Assert.Equal("cancelled", cancelled.Status);
        Assert.NotEqual("paid", cancelled.Status);

        var released = await _wallet.FetchSummaryAsync(asha.Id, CancellationToken.None);
        Assert.Equal(610, released.EarnedPoints);
        Assert.Equal(0, released.PendingWithdrawalPoints);
        Assert.DoesNotContain(
            "phone",
            System.Text.Json.JsonSerializer.Serialize(recorded),
            StringComparison.OrdinalIgnoreCase
        );
    }

    [Fact]
    public async Task men_and_promotional_points_cannot_withdraw()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();
        await _wallet.CreditEarnedAsync(
            nabin.Id,
            800,
            "messageReceived",
            "Eligible messaging",
            "Earned points from a paid message. Not cash and not a payout.",
            Guid.NewGuid().ToString("D") + ":earn",
            CancellationToken.None
        );
        await _db.SaveChangesAsync();

        var man = await _wallet.FetchEligibilityAsync(nabin.Id, CancellationToken.None);
        Assert.False(man.EligibleAccount);
        Assert.False(man.CanSubmit);
        Assert.Equal(800, man.EarnedAvailable);

        var manRefused = await Assert.ThrowsAsync<AuthException>(() =>
            _wallet.SubmitWithdrawalAsync(
                nabin.Id,
                new SubmitWithdrawalRequest(500, true),
                CancellationToken.None
            )
        );
        Assert.Equal(400, manRefused.StatusCode);

        var woman = await _wallet.FetchEligibilityAsync(asha.Id, CancellationToken.None);
        Assert.True(woman.EligibleAccount);
        Assert.False(woman.CanSubmit);
        Assert.Equal(0, woman.EarnedAvailable);
        Assert.Equal(WalletService.WelcomeBonusPoints, (await _wallet.FetchSummaryAsync(asha.Id, CancellationToken.None)).PromotionalPoints);
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
