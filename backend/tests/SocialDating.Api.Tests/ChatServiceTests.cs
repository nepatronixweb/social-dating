using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Chat;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;
using Xunit;

namespace SocialDating.Api.Tests;

public class ChatServiceTests : IDisposable
{
    static readonly byte[] Jpeg =
    [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9
    ];

    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly DiscoveryService _discovery;
    readonly ChatService _chat;
    readonly PhotoService _photos;
    readonly RecordingChatRealtime _realtime = new();
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public ChatServiceTests()
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
        _photos = PhotoService.ForTests(_db, clock);
        _discovery = new DiscoveryService(_db, clock, wallet, _photos, _realtime);
        _chat = new ChatService(_db, clock, wallet, _photos, _realtime);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public void eligible_words_ignore_digits_and_punctuation()
    {
        Assert.Equal(2, WordCount.EligibleWords("  Hello,  world! 123 "));
        Assert.Equal(0, WordCount.EligibleWords(" :-) 42 "));
    }

    [Fact]
    public async Task matched_people_can_send_and_read_text()
    {
        var (ada, asha, matchId) = await MatchedWomen();

        var sent = await _chat.SendAsync(
            ada.Id,
            matchId,
            new SendMessageRequest("Hello Asha", false),
            CancellationToken.None
        );
        Assert.Null(sent.Rejection);
        Assert.Equal("Hello Asha", sent.Message!.Text);
        Assert.True(sent.Message.IsMine);
        Assert.Equal(0, sent.ChargedPaisa);
        Assert.Equal(WalletService.WelcomeBonusPoints, sent.BalancePaisa);

        var thread = await _chat.FetchMessagesAsync(asha.Id, matchId, CancellationToken.None);
        Assert.Single(thread.Items);
        Assert.False(thread.Items[0].IsMine);
        Assert.Equal("Hello Asha", thread.Items[0].Text);

        var previews = await _chat.FetchPreviewsAsync(asha.Id, CancellationToken.None);
        Assert.Single(previews.Items);
        Assert.Equal("Ada", previews.Items[0].Profile.DisplayName);
        Assert.Equal(1, previews.Items[0].UnreadCount);
        Assert.DoesNotContain(
            "phone",
            System.Text.Json.JsonSerializer.Serialize(previews),
            StringComparison.OrdinalIgnoreCase
        );

        await _chat.MarkReadAsync(asha.Id, matchId, CancellationToken.None);
        var afterRead = await _chat.FetchPreviewsAsync(asha.Id, CancellationToken.None);
        Assert.Equal(0, afterRead.Items[0].UnreadCount);

        Assert.Contains(_realtime.Events, e => e.StartsWith($"message:{matchId}:{asha.Id}:False:True", StringComparison.Ordinal));
        Assert.Contains(_realtime.Events, e => e.StartsWith($"read:{matchId}:{ada.Id}", StringComparison.Ordinal));
    }

    [Fact]
    public async Task a_man_is_charged_from_promotional_points()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        var asha = SeedPerson("Asha", "woman", "Pokhara");
        await RightSwipe(asha, nabin);
        await _db.SaveChangesAsync();
        var created = await _discovery.LikeBackAsync(nabin.Id, asha.Id, CancellationToken.None);
        var matchId = Guid.Parse(created.Match!.Id);

        var outcome = await _chat.SendAsync(
            nabin.Id,
            matchId,
            new SendMessageRequest("Hello there", false),
            CancellationToken.None
        );
        Assert.Null(outcome.Rejection);
        Assert.Equal(20, outcome.ChargedPaisa);
        Assert.Equal(
            WalletService.WelcomeBonusPoints + WalletService.DailyFreePointsMale - 20,
            outcome.BalancePaisa
        );
        Assert.Single((await _chat.FetchMessagesAsync(nabin.Id, matchId, CancellationToken.None)).Items);

        var ashaWallet = await new WalletService(_db, new FixedTime(_now)).FetchSummaryAsync(
            asha.Id,
            CancellationToken.None
        );
        Assert.Equal(20, ashaWallet.EarnedPoints);
        Assert.Equal(WalletService.WelcomeBonusPoints, ashaWallet.PromotionalPoints);
    }

    [Fact]
    public async Task unmatched_conversations_are_gone()
    {
        var (ada, _, matchId) = await MatchedWomen();
        await _discovery.UnmatchAsync(ada.Id, matchId, CancellationToken.None);

        var error = await Assert.ThrowsAsync<AuthException>(() =>
            _chat.FetchMessagesAsync(ada.Id, matchId, CancellationToken.None)
        );
        Assert.Equal(404, error.StatusCode);
        Assert.Contains(_realtime.Events, e => e == $"closed:{matchId}");
    }

    [Fact]
    public async Task typing_is_pushed_to_the_other_person()
    {
        var (ada, asha, matchId) = await MatchedWomen();
        await _chat.SetTypingAsync(ada.Id, matchId, true, CancellationToken.None);
        Assert.Contains(_realtime.Events, e => e == $"typing:{matchId}:{asha.Id}:True");
    }

    [Fact]
    public async Task hide_removes_the_preview_but_keeps_the_thread()
    {
        var (ada, asha, matchId) = await MatchedWomen();
        await _chat.SendAsync(ada.Id, matchId, new SendMessageRequest("Hi", false), CancellationToken.None);
        await _chat.HideAsync(asha.Id, matchId, CancellationToken.None);

        Assert.Empty((await _chat.FetchPreviewsAsync(asha.Id, CancellationToken.None)).Items);
        Assert.Single((await _chat.FetchMessagesAsync(asha.Id, matchId, CancellationToken.None)).Items);
    }

    [Fact]
    public async Task empty_and_overlong_messages_are_rejected()
    {
        var (ada, _, matchId) = await MatchedWomen();
        var empty = await _chat.SendAsync(ada.Id, matchId, new SendMessageRequest("   ", false), CancellationToken.None);
        Assert.Equal("empty", empty.Rejection);

        var tooLong = await _chat.SendAsync(
            ada.Id,
            matchId,
            new SendMessageRequest(new string('a', WordCount.MaxCharacters + 1), false),
            CancellationToken.None
        );
        Assert.Equal("tooLong", tooLong.Rejection);
    }

    [Fact]
    public async Task image_only_messages_are_stored_without_using_album_slots()
    {
        var (ada, asha, matchId) = await MatchedWomen();
        var album = await _photos.Upload(ada.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);
        for (var i = 0; i < 5; i++)
        {
            await _photos.Upload(ada.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);
        }

        var uploaded = await _chat.UploadPhotoAsync(
            ada.Id,
            matchId,
            new MemoryStream(Jpeg),
            "image/jpeg",
            Jpeg.Length,
            CancellationToken.None
        );
        Assert.Equal(6, (await _photos.ListMine(ada.Id, CancellationToken.None)).Count);
        Assert.DoesNotContain(
            await _photos.ListMine(ada.Id, CancellationToken.None),
            p => p.Id == uploaded.Id
        );

        var sent = await _chat.SendAsync(
            ada.Id,
            matchId,
            new SendMessageRequest("", false, ImageId: uploaded.Id),
            CancellationToken.None
        );
        Assert.Null(sent.Rejection);
        Assert.Equal("", sent.Message!.Text);
        Assert.Equal(uploaded.Url, sent.Message.ImageUrl);
        Assert.Equal(0, sent.ChargedPaisa);

        var thread = await _chat.FetchMessagesAsync(asha.Id, matchId, CancellationToken.None);
        Assert.Equal(uploaded.Url, thread.Items[0].ImageUrl);
        Assert.False(thread.Items[0].IsMine);

        var previews = await _chat.FetchPreviewsAsync(asha.Id, CancellationToken.None);
        Assert.Equal("Photo", previews.Items[0].LastMessage);

        var fromAlbum = await Assert.ThrowsAsync<AuthException>(() =>
            _chat.SendAsync(
                ada.Id,
                matchId,
                new SendMessageRequest("Hi", false, ImageId: album.Id),
                CancellationToken.None
            ));
        Assert.Equal(400, fromAlbum.StatusCode);
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
