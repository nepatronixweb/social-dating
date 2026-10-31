using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;
using Xunit;

namespace SocialDating.Api.Tests;

public class MatchingServiceTests : IDisposable
{
    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly DiscoveryService _discovery;
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public MatchingServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        var clock = new FixedTime(_now);
        _discovery = new DiscoveryService(_db, clock, new WalletService(_db, clock), PhotoService.ForTests(_db, clock));
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task received_like_can_be_answered_without_using_quota()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await RightSwipe(asha, ada);
        await _db.SaveChangesAsync();

        var inbound = await _discovery.FetchLikesReceivedAsync(ada.Id, CancellationToken.None);
        Assert.Single(inbound.Items);
        Assert.Equal("Asha", inbound.Items[0].Profile.DisplayName);

        var outcome = await _discovery.LikeBackAsync(ada.Id, asha.Id, CancellationToken.None);
        Assert.True(outcome.Created);
        Assert.Equal("Asha", outcome.Match!.Profile.DisplayName);

        var after = await _discovery.FetchLikesReceivedAsync(ada.Id, CancellationToken.None);
        Assert.Empty(after.Items);
        var matches = await _discovery.FetchMatchesAsync(ada.Id, CancellationToken.None);
        Assert.Single(matches.Items);
        var quota = await _discovery.FetchQuotaAsync(ada.Id, CancellationToken.None);
        Assert.Equal(0, quota.DailyUsed);
    }

    [Fact]
    public async Task like_back_without_an_inbound_like_is_gone()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();

        var error = await Assert.ThrowsAsync<AuthException>(() =>
            _discovery.LikeBackAsync(ada.Id, asha.Id, CancellationToken.None)
        );
        Assert.Equal(404, error.StatusCode);
    }

    [Fact]
    public async Task sent_like_can_be_withdrawn_and_returns_to_the_deck()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        await _discovery.SwipeAsync(
            ada.Id,
            new SwipeRequest(nabin.Id.ToString(), "right", false),
            CancellationToken.None
        );

        var sent = await _discovery.FetchLikesSentAsync(ada.Id, CancellationToken.None);
        Assert.Single(sent.Items);
        Assert.Equal("Nabin", sent.Items[0].Profile.DisplayName);

        await _discovery.WithdrawLikeAsync(ada.Id, nabin.Id, CancellationToken.None);
        Assert.Empty((await _discovery.FetchLikesSentAsync(ada.Id, CancellationToken.None)).Items);
        var deck = await _discovery.FetchDeckAsync(ada.Id, null, null, null, false, null, CancellationToken.None);
        Assert.Contains(deck.Items, p => p.DisplayName == "Nabin");
    }

    [Fact]
    public async Task unmatch_keeps_the_person_off_the_deck_and_likes()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await RightSwipe(asha, ada);
        await _db.SaveChangesAsync();
        var created = await _discovery.LikeBackAsync(ada.Id, asha.Id, CancellationToken.None);

        await _discovery.UnmatchAsync(ada.Id, Guid.Parse(created.Match!.Id), CancellationToken.None);

        Assert.Empty((await _discovery.FetchMatchesAsync(ada.Id, CancellationToken.None)).Items);
        Assert.Empty((await _discovery.FetchLikesReceivedAsync(ada.Id, CancellationToken.None)).Items);
        Assert.Empty((await _discovery.FetchLikesSentAsync(ada.Id, CancellationToken.None)).Items);
        var deck = await _discovery.FetchDeckAsync(ada.Id, null, null, null, false, null, CancellationToken.None);
        Assert.DoesNotContain(deck.Items, p => p.Id == asha.Id.ToString());
    }

    [Fact]
    public async Task block_hides_a_person_from_discovery_and_lists_them()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var maya = SeedPerson("Maya", "woman", "Pokhara");
        await _db.SaveChangesAsync();

        await _discovery.BlockAsync(ada.Id, maya.Id, CancellationToken.None);

        var deck = await _discovery.FetchDeckAsync(ada.Id, null, null, null, false, null, CancellationToken.None);
        Assert.DoesNotContain(deck.Items, p => p.Id == maya.Id.ToString());
        var blocked = await _discovery.FetchBlockedAsync(ada.Id, CancellationToken.None);
        Assert.Single(blocked.Items);
        Assert.Equal("Maya", blocked.Items[0].DisplayName);
        Assert.DoesNotContain(
            "phone",
            System.Text.Json.JsonSerializer.Serialize(blocked),
            StringComparison.OrdinalIgnoreCase
        );
    }

    [Fact]
    public async Task a_man_at_the_daily_limit_can_still_like_back()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        _db.SwipeDays.Add(new SwipeDay
        {
            AccountId = nabin.Id,
            DayKey = NepalTime.DayKey(_now),
            DailyUsed = DiscoveryService.FreeDailySwipesMale,
        });
        await RightSwipe(asha, nabin);
        await _db.SaveChangesAsync();

        var outcome = await _discovery.LikeBackAsync(nabin.Id, asha.Id, CancellationToken.None);
        Assert.True(outcome.Created);
        var quota = await _discovery.FetchQuotaAsync(nabin.Id, CancellationToken.None);
        Assert.Equal(DiscoveryService.FreeDailySwipesMale, quota.DailyUsed);
    }

    [Fact]
    public async Task decline_removes_the_received_like()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await RightSwipe(asha, ada);
        await _db.SaveChangesAsync();

        await _discovery.DeclineLikeAsync(ada.Id, asha.Id, CancellationToken.None);
        Assert.Empty((await _discovery.FetchLikesReceivedAsync(ada.Id, CancellationToken.None)).Items);
        var deck = await _discovery.FetchDeckAsync(ada.Id, null, null, null, false, null, CancellationToken.None);
        Assert.DoesNotContain(deck.Items, p => p.Id == asha.Id.ToString());
    }

    async Task RightSwipe(Account from, Account to)
    {
        _db.Swipes.Add(new Swipe
        {
            Id = Guid.NewGuid(),
            FromAccountId = from.Id,
            ToAccountId = to.Id,
            Direction = "right",
            CreatedAt = _now,
        });
        await Task.CompletedTask;
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
