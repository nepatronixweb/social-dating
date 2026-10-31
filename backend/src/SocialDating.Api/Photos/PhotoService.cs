using System.Security.Cryptography;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;

namespace SocialDating.Api.Photos;

public sealed class PhotoService(
    AppDbContext db,
    TimeProvider time,
    IOptions<PhotoOptions> options,
    IOptions<JwtOptions> jwt)
{
    private readonly PhotoOptions _photos = options.Value;
    private readonly string _signingKey = jwt.Value.SigningKey;

    public static PhotoService ForTests(AppDbContext db, TimeProvider time)
    {
        var root = Path.Combine(Path.GetTempPath(), "sd-photos", Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(root);
        return new PhotoService(
            db,
            time,
            Options.Create(new PhotoOptions { RootPath = root }),
            Options.Create(new JwtOptions { SigningKey = new string('k', 32) }));
    }

    public async Task<IReadOnlyList<PhotoResponse>> ListMine(Guid accountId, CancellationToken ct)
    {
        var rows = await db.Photos.AsNoTracking()
            .Where(p => p.AccountId == accountId && p.Kind == "profile")
            .OrderBy(p => p.SortOrder)
            .ToListAsync(ct);
        return rows.Select(ToResponse).ToList();
    }

    public async Task<string[]> UrlsFor(Guid accountId, CancellationToken ct)
    {
        var map = await UrlsByAccount([accountId], ct);
        return map.GetValueOrDefault(accountId) ?? [];
    }

    public async Task<Dictionary<Guid, string[]>> UrlsByAccount(
        IEnumerable<Guid> accountIds,
        CancellationToken ct)
    {
        var ids = accountIds.Distinct().ToArray();
        if (ids.Length == 0) return [];

        var rows = await db.Photos.AsNoTracking()
            .Where(p => ids.Contains(p.AccountId) && p.Kind == "profile")
            .OrderBy(p => p.SortOrder)
            .ToListAsync(ct);

        return rows
            .GroupBy(p => p.AccountId)
            .ToDictionary(
                g => g.Key,
                g => g.Select(p => SignedPath(p.Id)).ToArray());
    }

    public Task<PhotoResponse> Upload(
        Guid accountId,
        Stream content,
        string? contentType,
        long length,
        CancellationToken ct
    ) => Store(accountId, content, contentType, length, "profile", true, ct);

    public Task<PhotoResponse> UploadChat(
        Guid accountId,
        Stream content,
        string? contentType,
        long length,
        CancellationToken ct
    ) => Store(accountId, content, contentType, length, "chat", false, ct);

    public string SignedUrl(Guid photoId) => SignedPath(photoId);

    async Task<PhotoResponse> Store(
        Guid accountId,
        Stream content,
        string? contentType,
        long length,
        string kind,
        bool enforceMax,
        CancellationToken ct)
    {
        _ = contentType;
        if (length <= 0 || length > _photos.MaxBytes)
            throw new AuthException(400, "Photo is too large.", "Keep each photo under 5 MB.");

        var count = await db.Photos.CountAsync(
            p => p.AccountId == accountId && p.Kind == "profile",
            ct);
        if (enforceMax && count >= _photos.MaxCount)
            throw new AuthException(400, "You already have six photos.", "Remove one before adding another.");

        var header = new byte[Math.Min(16, (int)length)];
        var read = await content.ReadAsync(header, ct);
        if (read == 0) throw new AuthException(400, "Photo file is empty.", "Choose a photo to upload.");
        var detected = DetectType(header.AsSpan(0, read));
        if (detected is null)
            throw new AuthException(400, "That file type is not supported.", "Use JPEG, PNG, or WebP.");

        var id = Guid.NewGuid();
        var path = FilePath(accountId, id);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);

        await using (var output = File.Create(path))
        {
            await output.WriteAsync(header.AsMemory(0, read), ct);
            await content.CopyToAsync(output, ct);
        }

        var size = (int)new FileInfo(path).Length;
        if (size > _photos.MaxBytes)
        {
            File.Delete(path);
            throw new AuthException(400, "Photo is too large.", "Keep each photo under 5 MB.");
        }

        var row = new Photo
        {
            Id = id,
            AccountId = accountId,
            SortOrder = kind == "profile" ? count : 0,
            ContentType = detected,
            Kind = kind,
            ByteSize = size,
            CreatedAt = time.GetUtcNow(),
        };
        try
        {
            db.Photos.Add(row);
            await db.SaveChangesAsync(ct);
        }
        catch
        {
            if (File.Exists(path)) File.Delete(path);
            throw;
        }
        return ToResponse(row);
    }

    public async Task Reorder(Guid accountId, string[] ids, CancellationToken ct)
    {
        var rows = await db.Photos
            .Where(p => p.AccountId == accountId && p.Kind == "profile")
            .ToListAsync(ct);
        if (ids.Length != rows.Count)
            throw new AuthException(400, "Photo order is not valid.", "Send every photo id exactly once.");

        var parsed = new List<Guid>(ids.Length);
        foreach (var raw in ids)
        {
            if (!Guid.TryParse(raw, out var id))
                throw new AuthException(400, "A photo id is not valid.", "A photo id is not valid.");
            parsed.Add(id);
        }

        if (parsed.Distinct().Count() != parsed.Count)
            throw new AuthException(400, "Photo order is not valid.", "Send every photo id exactly once.");

        var byId = rows.ToDictionary(p => p.Id);
        for (var i = 0; i < parsed.Count; i++)
        {
            if (!byId.TryGetValue(parsed[i], out var row))
                throw new AuthException(404, "That photo is not on your profile.", "That photo is not on your profile.");
            row.SortOrder = i;
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task Delete(Guid accountId, Guid photoId, CancellationToken ct)
    {
        var row = await db.Photos.FirstOrDefaultAsync(
            p => p.Id == photoId && p.AccountId == accountId && p.Kind == "profile",
            ct);
        if (row is null)
            throw new AuthException(404, "That photo is not on your profile.", "That photo is not on your profile.");

        db.Photos.Remove(row);
        var remaining = await db.Photos
            .Where(p => p.AccountId == accountId && p.Kind == "profile" && p.Id != photoId)
            .OrderBy(p => p.SortOrder)
            .ToListAsync(ct);
        for (var i = 0; i < remaining.Count; i++) remaining[i].SortOrder = i;
        await db.SaveChangesAsync(ct);

        var path = FilePath(accountId, photoId);
        if (File.Exists(path)) File.Delete(path);
    }

    public async Task<(byte[] Bytes, string ContentType)?> OpenSigned(Guid photoId, long exp, string sig, CancellationToken ct)
    {
        if (!IsValidSignature(photoId, exp, sig)) return null;
        if (exp < time.GetUtcNow().ToUnixTimeSeconds()) return null;

        var row = await db.Photos.AsNoTracking().FirstOrDefaultAsync(p => p.Id == photoId, ct);
        if (row is null) return null;

        var path = FilePath(row.AccountId, row.Id);
        if (!File.Exists(path)) return null;
        return (await File.ReadAllBytesAsync(path, ct), row.ContentType);
    }

    private PhotoResponse ToResponse(Photo row) =>
        new(row.Id.ToString(), SignedPath(row.Id), row.SortOrder);

    private string SignedPath(Guid photoId)
    {
        var exp = time.GetUtcNow().AddMinutes(_photos.UrlTtlMinutes).ToUnixTimeSeconds();
        var sig = Sign(photoId, exp);
        return $"/v1/media/{photoId:D}?e={exp}&s={sig}";
    }

    private bool IsValidSignature(Guid photoId, long exp, string sig)
    {
        var expected = Sign(photoId, exp);
        var a = Encoding.UTF8.GetBytes(expected);
        var b = Encoding.UTF8.GetBytes(sig ?? "");
        return a.Length == b.Length && CryptographicOperations.FixedTimeEquals(a, b);
    }

    private string Sign(Guid photoId, long exp)
    {
        var payload = $"{photoId:D}|{exp}";
        var mac = HMACSHA256.HashData(Encoding.UTF8.GetBytes(_signingKey), Encoding.UTF8.GetBytes(payload));
        return Convert.ToHexString(mac).ToLowerInvariant();
    }

    private string FilePath(Guid accountId, Guid photoId)
    {
        var root = string.IsNullOrWhiteSpace(_photos.RootPath)
            ? Path.Combine(Path.GetTempPath(), "social-dating-photos")
            : _photos.RootPath;
        return Path.Combine(root, accountId.ToString("D"), photoId.ToString("D"));
    }

    private static string? DetectType(ReadOnlySpan<byte> header)
    {
        if (header.Length >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF)
            return "image/jpeg";
        if (header.Length >= 8
            && header[0] == 0x89 && header[1] == 0x50 && header[2] == 0x4E && header[3] == 0x47
            && header[4] == 0x0D && header[5] == 0x0A && header[6] == 0x1A && header[7] == 0x0A)
            return "image/png";
        if (header.Length >= 12
            && header[0] == 0x52 && header[1] == 0x49 && header[2] == 0x46 && header[3] == 0x46
            && header[8] == 0x57 && header[9] == 0x45 && header[10] == 0x42 && header[11] == 0x50)
            return "image/webp";
        return null;
    }
}
