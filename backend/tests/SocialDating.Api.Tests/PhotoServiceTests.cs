using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Photos;
using Xunit;

namespace SocialDating.Api.Tests;

public class PhotoServiceTests : IDisposable
{
    static readonly byte[] Jpeg =
    [
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00, 0x00, 0xFF, 0xD9
    ];

    static readonly byte[] Gif = "GIF89a"u8.ToArray();

    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly PhotoService _photos;
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public PhotoServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        _photos = PhotoService.ForTests(_db, new FixedTime(_now));
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task upload_lists_and_opens_a_signed_jpeg()
    {
        var account = SeedPerson();
        await _db.SaveChangesAsync();

        var uploaded = await _photos.Upload(account.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);
        Assert.Equal(0, uploaded.SortOrder);
        Assert.Contains("/v1/media/", uploaded.Url, StringComparison.Ordinal);
        Assert.Contains("e=", uploaded.Url, StringComparison.Ordinal);
        Assert.Contains("s=", uploaded.Url, StringComparison.Ordinal);

        var listed = await _photos.ListMine(account.Id, CancellationToken.None);
        Assert.Single(listed);
        Assert.Equal(uploaded.Id, listed[0].Id);

        var uri = new Uri("http://local.test" + uploaded.Url);
        var id = Guid.Parse(uploaded.Id);
        var exp = long.Parse(uri.Query.TrimStart('?').Split('&').Single(p => p.StartsWith("e="))[2..]);
        var sig = uri.Query.TrimStart('?').Split('&').Single(p => p.StartsWith("s="))[2..];
        var opened = await _photos.OpenSigned(id, exp, sig, CancellationToken.None);
        Assert.NotNull(opened);
        Assert.Equal("image/jpeg", opened.Value.ContentType);
        Assert.Equal(Jpeg, opened.Value.Bytes);
    }

    [Fact]
    public async Task rejects_unsupported_types_and_a_seventh_photo()
    {
        var account = SeedPerson();
        await _db.SaveChangesAsync();

        var gif = await Assert.ThrowsAsync<AuthException>(() =>
            _photos.Upload(account.Id, new MemoryStream(Gif), "image/gif", Gif.Length, CancellationToken.None));
        Assert.Equal(400, gif.StatusCode);

        for (var i = 0; i < 6; i++)
        {
            await _photos.Upload(account.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);
        }

        var tooMany = await Assert.ThrowsAsync<AuthException>(() =>
            _photos.Upload(account.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None));
        Assert.Equal(400, tooMany.StatusCode);

        var chat = await _photos.UploadChat(account.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);
        Assert.Equal(6, (await _photos.ListMine(account.Id, CancellationToken.None)).Count);
        Assert.Contains("/v1/media/", chat.Url, StringComparison.Ordinal);
    }

    [Fact]
    public async Task reorder_and_delete_keep_sort_order_contiguous()
    {
        var account = SeedPerson();
        await _db.SaveChangesAsync();
        var first = await _photos.Upload(account.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);
        var second = await _photos.Upload(account.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);

        await _photos.Reorder(account.Id, [second.Id, first.Id], CancellationToken.None);
        var ordered = await _photos.ListMine(account.Id, CancellationToken.None);
        Assert.Equal(second.Id, ordered[0].Id);
        Assert.Equal(0, ordered[0].SortOrder);
        Assert.Equal(first.Id, ordered[1].Id);

        await _photos.Delete(account.Id, Guid.Parse(second.Id), CancellationToken.None);
        var remaining = await _photos.ListMine(account.Id, CancellationToken.None);
        Assert.Single(remaining);
        Assert.Equal(first.Id, remaining[0].Id);
        Assert.Equal(0, remaining[0].SortOrder);
    }

    [Fact]
    public async Task expired_or_forged_signatures_do_not_open()
    {
        var account = SeedPerson();
        await _db.SaveChangesAsync();
        var uploaded = await _photos.Upload(account.Id, new MemoryStream(Jpeg), "image/jpeg", Jpeg.Length, CancellationToken.None);
        var id = Guid.Parse(uploaded.Id);

        Assert.Null(await _photos.OpenSigned(id, 1, "deadbeef", CancellationToken.None));
        Assert.Null(await _photos.OpenSigned(Guid.NewGuid(), 1, "deadbeef", CancellationToken.None));
    }

    Account SeedPerson()
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
            DisplayName = "Ada",
            City = "Kathmandu",
            Gender = "woman",
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
