using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;
using Xunit;

namespace SocialDating.Api.Tests;

public class DiscoveryServiceTests : IDisposable
{
    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly DiscoveryService _discovery;
    readonly PhotoService _photos;
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public DiscoveryServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        var clock = new FixedTime(_now);
        _photos = PhotoService.ForTests(_db, clock);
        _discovery = new DiscoveryService(_db, clock, new WalletService(_db, clock), _photos);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task deck_hides_self_and_already_swiped()
    {
        var viewer = SeedPerson("Ada", "woman", "Kathmandu");
        var other = SeedPerson("Asha", "woman", "Pokhara");
        SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        var first = await _discovery.FetchDeckAsync(viewer.Id, null, null, null, false, null, CancellationToken.None);
        var nabin = Assert.Single(first.Items);
        Assert.Equal("Nabin", nabin.DisplayName);
        Assert.DoesNotContain(first.Items, p => p.Id == viewer.Id.ToString());
        Assert.DoesNotContain(first.Items, p => p.Id == other.Id.ToString());
        Assert.All(first.Items, p => Assert.Null(p.DistanceKm));
        Assert.DoesNotContain("phone", System.Text.Json.JsonSerializer.Serialize(first), StringComparison.OrdinalIgnoreCase);

        await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(nabin.Id, "left", false),
            CancellationToken.None
        );
        var second = await _discovery.FetchDeckAsync(viewer.Id, null, null, null, false, null, CancellationToken.None);
        Assert.Empty(second.Items);
    }

    [Fact]
    public async Task deck_includes_signed_photo_urls()
    {
        var viewer = SeedPerson("Nabin", "man", "Lalitpur");
        var other = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();
        await _photos.Upload(
            other.Id,
            new MemoryStream(
            [
                0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
                0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9
            ]),
            "image/jpeg",
            20,
            CancellationToken.None);

        var deck = await _discovery.FetchDeckAsync(viewer.Id, null, null, null, false, null, CancellationToken.None);
        var asha = Assert.Single(deck.Items);
        Assert.Equal("Asha", asha.DisplayName);
        Assert.Equal(1, asha.PhotoCount);
        Assert.Single(asha.PhotoUrls);
        Assert.StartsWith("/v1/media/", asha.PhotoUrls[0]);
    }

    [Fact]
    public async Task mutual_right_swipe_creates_a_match()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();

        await _discovery.SwipeAsync(ada.Id, new SwipeRequest(asha.Id.ToString(), "right", false), CancellationToken.None);
        var back = await _discovery.SwipeAsync(asha.Id, new SwipeRequest(ada.Id.ToString(), "right", false), CancellationToken.None);

        Assert.NotNull(back.MatchedProfile);
        Assert.Equal("Ada", back.MatchedProfile!.DisplayName);
        var matches = await _discovery.FetchMatchesAsync(ada.Id, CancellationToken.None);
        Assert.Single(matches.Items);
        Assert.Equal("Asha", matches.Items[0].Profile.DisplayName);
    }

    [Fact]
    public async Task preview_limit_rejects_before_the_profile_is_complete()
    {
        var viewer = SeedBare();
        var other = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();

        for (var i = 0; i < DiscoveryService.PreviewSwipes; i++)
        {
            var ok = await _discovery.SwipeAsync(
                viewer.Id,
                new SwipeRequest(other.Id.ToString(), "left", false),
                CancellationToken.None
            );
            Assert.Null(ok.Rejection);
            foreach (var swipe in _db.Swipes.ToList().Where(s => s.UndoneAt == null))
            {
                swipe.UndoneAt = _now;
            }
            await _db.SaveChangesAsync();
        }

        var blocked = await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(other.Id.ToString(), "left", false),
            CancellationToken.None
        );
        Assert.Equal("profileIncomplete", blocked.Rejection);
    }

    [Fact]
    public async Task verified_only_returns_an_empty_deck()
    {
        var viewer = SeedPerson("Ada", "woman", "Kathmandu");
        SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();

        var page = await _discovery.FetchDeckAsync(
            viewer.Id,
            null,
            null,
            null,
            true,
            null,
            CancellationToken.None
        );
        Assert.Empty(page.Items);
    }

    [Fact]
    public async Task deck_follows_viewer_gender_matching()
    {
        var man = SeedPerson("Nabin", "man", "Lalitpur");
        SeedPerson("Ada", "woman", "Kathmandu");
        SeedPerson("Kiran", "transgender", "Bhaktapur");
        SeedPerson("Ravi", "other", "Nepalgunj");
        await _db.SaveChangesAsync();

        var forMan = await _discovery.FetchDeckAsync(man.Id, null, null, null, false, null, CancellationToken.None);
        Assert.Equal(2, forMan.Items.Count);
        Assert.Contains(forMan.Items, p => p.DisplayName == "Ada");
        Assert.Contains(forMan.Items, p => p.DisplayName == "Kiran");

        var woman = _db.Accounts.Single(a => a.DisplayName == "Ada");
        var forWoman = await _discovery.FetchDeckAsync(woman.Id, null, null, null, false, null, CancellationToken.None);
        Assert.Equal("Nabin", Assert.Single(forWoman.Items).DisplayName);

        var trans = _db.Accounts.Single(a => a.DisplayName == "Kiran");
        var forTrans = await _discovery.FetchDeckAsync(trans.Id, null, null, null, false, null, CancellationToken.None);
        Assert.Equal("Nabin", Assert.Single(forTrans.Items).DisplayName);
    }

    [Fact]
    public async Task extra_male_swipes_charge_promotional_points()
    {
        var viewer = SeedPerson("Nabin", "man", "Lalitpur");
        var other = SeedPerson("Asha", "woman", "Pokhara");
        _db.SwipeDays.Add(new SwipeDay
        {
            AccountId = viewer.Id,
            DayKey = NepalTime.DayKey(_now),
            DailyUsed = DiscoveryService.FreeDailySwipesMale,
        });
        await _db.SaveChangesAsync();

        var unconfirmed = await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(other.Id.ToString(), "right", false),
            CancellationToken.None
        );
        Assert.Equal("paymentRequired", unconfirmed.Rejection);
        var starting =
            WalletService.WelcomeBonusPoints + WalletService.DailyFreePointsMale;
        Assert.Equal(starting, unconfirmed.Quota.BalancePaisa);
        Assert.Equal(DiscoveryService.PremiumActionPricePaisa, unconfirmed.Quota.ActionPricePaisa);

        var paid = await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(other.Id.ToString(), "right", true),
            CancellationToken.None
        );
        Assert.Null(paid.Rejection);
        Assert.Equal(DiscoveryService.ExtraSwipePricePaisa, paid.ChargedPaisa);
        Assert.Equal(starting - DiscoveryService.ExtraSwipePricePaisa, paid.Quota.BalancePaisa);
    }

    [Fact]
    public async Task super_like_charges_male_and_credits_admin()
    {
        var viewer = SeedPerson("Nabin", "man", "Lalitpur");
        var other = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();

        var needConfirm = await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(other.Id.ToString(), "super", false),
            CancellationToken.None
        );
        Assert.Equal("paymentRequired", needConfirm.Rejection);

        var paid = await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(other.Id.ToString(), "super", true),
            CancellationToken.None
        );
        Assert.Null(paid.Rejection);
        Assert.Equal(DiscoveryService.PremiumActionPricePaisa, paid.ChargedPaisa);

        var admin = await AdminAccount.EnsureAsync(_db, _now, CancellationToken.None);
        await _db.SaveChangesAsync();
        var adminEarned = await _db.WalletEntries
            .Where(e => e.AccountId == admin.Id && e.Bucket == "earned")
            .SumAsync(e => e.Points);
        Assert.Equal(DiscoveryService.PremiumActionPricePaisa, adminEarned);
    }

    [Fact]
    public async Task discovery_message_and_rewind_charge_male_to_admin()
    {
        var viewer = SeedPerson("Nabin", "man", "Lalitpur");
        var other = SeedPerson("Harper", "woman", "Kathmandu");
        await _db.SaveChangesAsync();

        await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(other.Id.ToString(), "left", false),
            CancellationToken.None
        );

        var rewindBlocked = await _discovery.UndoLastAsync(
            viewer.Id,
            new UndoRequest(false),
            CancellationToken.None
        );
        Assert.Equal("paymentRequired", rewindBlocked!.Rejection);

        var rewind = await _discovery.UndoLastAsync(
            viewer.Id,
            new UndoRequest(true),
            CancellationToken.None
        );
        Assert.Null(rewind!.Rejection);
        Assert.Equal(DiscoveryService.PremiumActionPricePaisa, rewind.ChargedPaisa);
        Assert.Equal("Harper", rewind.Profile!.DisplayName);

        var message = await _discovery.MessageAsync(
            viewer.Id,
            new DiscoveryMessageRequest(other.Id.ToString(), true),
            CancellationToken.None
        );
        Assert.Null(message.Rejection);
        Assert.Equal(DiscoveryService.PremiumActionPricePaisa, message.ChargedPaisa);
        Assert.False(string.IsNullOrWhiteSpace(message.ConversationId));
    }

    [Fact]
    public async Task female_accounts_have_no_daily_swipe_limit()
    {
        var viewer = SeedPerson("Ada", "woman", "Kathmandu");
        var other = SeedPerson("Nabin", "man", "Lalitpur");
        _db.SwipeDays.Add(new SwipeDay
        {
            AccountId = viewer.Id,
            DayKey = NepalTime.DayKey(_now),
            DailyUsed = DiscoveryService.FreeDailySwipesMale,
        });
        await _db.SaveChangesAsync();

        var quota = await _discovery.FetchQuotaAsync(viewer.Id, CancellationToken.None);
        Assert.Null(quota.FreeDailyLimit);

        var outcome = await _discovery.SwipeAsync(
            viewer.Id,
            new SwipeRequest(other.Id.ToString(), "right", false),
            CancellationToken.None
        );
        Assert.Null(outcome.Rejection);
        Assert.Equal(0, outcome.ChargedPaisa);
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

    Account SeedBare()
    {
        var account = new Account
        {
            Id = Guid.NewGuid(),
            PhoneE164 = $"+9779700{Interlocked.Increment(ref _phones):D6}",
            CreatedAt = _now,
            UpdatedAt = _now,
        };
        _db.Accounts.Add(account);
        return account;
    }

    sealed class FixedTime(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
