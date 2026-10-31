using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Chat;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Inbox;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;
using Xunit;

namespace SocialDating.Api.Tests;

public class InboxServiceTests : IDisposable
{
    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly DiscoveryService _discovery;
    readonly ChatService _chat;
    readonly InboxService _inbox;
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public InboxServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        var clock = new FixedTime(_now);
        var wallet = new WalletService(_db, clock);
        var photos = PhotoService.ForTests(_db, clock);
        _inbox = new InboxService(_db, clock);
        _discovery = new DiscoveryService(_db, clock, wallet, photos, inbox: _inbox);
        _chat = new ChatService(_db, clock, wallet, photos, inbox: _inbox);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task a_right_swipe_notifies_the_other_person()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();

        await _discovery.SwipeAsync(
            ada.Id,
            new SwipeRequest(asha.Id.ToString(), "right", false),
            CancellationToken.None
        );

        var ashaInbox = await _inbox.ListAsync(asha.Id, CancellationToken.None);
        Assert.Single(ashaInbox.Items);
        Assert.Equal("like", ashaInbox.Items[0].Type);
        Assert.Equal("Someone likes you", ashaInbox.Items[0].Title);
        Assert.Equal("Ada liked your profile.", ashaInbox.Items[0].Body);
        Assert.False(ashaInbox.Items[0].IsRead);
        Assert.DoesNotContain(
            "phone",
            System.Text.Json.JsonSerializer.Serialize(ashaInbox),
            StringComparison.OrdinalIgnoreCase
        );

        var adaInbox = await _inbox.ListAsync(ada.Id, CancellationToken.None);
        Assert.Empty(adaInbox.Items);
    }

    [Fact]
    public async Task a_match_notifies_both_people()
    {
        var (ada, asha, _) = await MatchedWomen();

        var adaInbox = await _inbox.ListAsync(ada.Id, CancellationToken.None);
        var ashaInbox = await _inbox.ListAsync(asha.Id, CancellationToken.None);
        Assert.Contains(adaInbox.Items, n => n.Type == "match" && n.Body.Contains("Asha", StringComparison.Ordinal));
        Assert.Contains(ashaInbox.Items, n => n.Type == "match" && n.Body.Contains("Ada", StringComparison.Ordinal));
        Assert.DoesNotContain(adaInbox.Items, n => n.Type == "like");
    }

    [Fact]
    public async Task messages_coalesce_until_read_and_skip_muted_chats()
    {
        var (ada, asha, matchId) = await MatchedWomen();
        await _chat.SendAsync(ada.Id, matchId, new SendMessageRequest("Hello Asha", false), CancellationToken.None);
        await _chat.SendAsync(ada.Id, matchId, new SendMessageRequest("Still there", false), CancellationToken.None);

        var before = await _inbox.ListAsync(asha.Id, CancellationToken.None);
        var message = Assert.Single(before.Items, n => n.Type == "message");
        Assert.Equal("Ada sent you a message.", message.Body);
        await _inbox.MarkReadAsync(asha.Id, Guid.Parse(message.Id), CancellationToken.None);
        await _chat.SendAsync(ada.Id, matchId, new SendMessageRequest("Again", false), CancellationToken.None);
        var afterRead = await _inbox.ListAsync(asha.Id, CancellationToken.None);
        Assert.Equal(2, afterRead.Items.Count(n => n.Type == "message"));

        await _chat.SetMutedAsync(asha.Id, matchId, true, CancellationToken.None);
        await _inbox.MarkAllReadAsync(asha.Id, CancellationToken.None);
        await _chat.SendAsync(ada.Id, matchId, new SendMessageRequest("Muted", false), CancellationToken.None);
        var muted = await _inbox.ListAsync(asha.Id, CancellationToken.None);
        Assert.Equal(2, muted.Items.Count(n => n.Type == "message"));
        Assert.All(muted.Items, n => Assert.True(n.IsRead));
    }

    [Fact]
    public async Task mark_read_is_owner_only()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await _db.SaveChangesAsync();
        await _discovery.SwipeAsync(
            ada.Id,
            new SwipeRequest(asha.Id.ToString(), "right", false),
            CancellationToken.None
        );
        var item = (await _inbox.ListAsync(asha.Id, CancellationToken.None)).Items[0];
        var missing = await Assert.ThrowsAsync<AuthException>(() =>
            _inbox.MarkReadAsync(ada.Id, Guid.Parse(item.Id), CancellationToken.None)
        );
        Assert.Equal(404, missing.StatusCode);
    }

    async Task<(Account Ada, Account Asha, Guid MatchId)> MatchedWomen()
    {
        var ada = SeedPerson("Ada", "woman", "Kathmandu");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await RightSwipe(asha, ada);
        await _db.SaveChangesAsync();
        var created = await _discovery.LikeBackAsync(ada.Id, asha.Id, CancellationToken.None);
        return (ada, asha, Guid.Parse(created.Match!.Id));
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
