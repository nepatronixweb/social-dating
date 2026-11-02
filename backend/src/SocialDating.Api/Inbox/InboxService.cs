using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;

namespace SocialDating.Api.Inbox;

public interface IInboxService
{
    Task<NotificationListResponse> ListAsync(Guid viewerId, CancellationToken ct);
    Task MarkReadAsync(Guid viewerId, Guid id, CancellationToken ct);
    Task MarkAllReadAsync(Guid viewerId, CancellationToken ct);
    Task NotifyLikeAsync(Guid recipientId, Account from, CancellationToken ct);
    Task NotifyMatchAsync(Account a, Account b, Guid matchId, CancellationToken ct);
    Task NotifyMessageAsync(Guid recipientId, Account from, Guid matchId, CancellationToken ct);
    Task NotifySystemBulkAsync(
        IReadOnlyList<Guid> accountIds,
        string title,
        string body,
        CancellationToken ct
    );

    Task NotifySystemAsync(Guid accountId, string title, string body, CancellationToken ct);
}

public sealed class NullInboxService : IInboxService
{
    public static readonly NullInboxService Instance = new();

    public Task<NotificationListResponse> ListAsync(Guid viewerId, CancellationToken ct) =>
        Task.FromResult(new NotificationListResponse([]));

    public Task MarkReadAsync(Guid viewerId, Guid id, CancellationToken ct) => Task.CompletedTask;
    public Task MarkAllReadAsync(Guid viewerId, CancellationToken ct) => Task.CompletedTask;
    public Task NotifyLikeAsync(Guid recipientId, Account from, CancellationToken ct) => Task.CompletedTask;
    public Task NotifyMatchAsync(Account a, Account b, Guid matchId, CancellationToken ct) => Task.CompletedTask;
    public Task NotifyMessageAsync(Guid recipientId, Account from, Guid matchId, CancellationToken ct) =>
        Task.CompletedTask;

    public Task NotifySystemBulkAsync(
        IReadOnlyList<Guid> accountIds,
        string title,
        string body,
        CancellationToken ct
    ) => Task.CompletedTask;

    public Task NotifySystemAsync(Guid accountId, string title, string body, CancellationToken ct) =>
        Task.CompletedTask;
}

public sealed class InboxService(AppDbContext db, TimeProvider time) : IInboxService
{
    public const int MaxItems = 100;

    DateTimeOffset Now => time.GetUtcNow();

    public async Task<NotificationListResponse> ListAsync(Guid viewerId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var rows = (await db.InboxNotifications
            .AsNoTracking()
            .Where(n => n.AccountId == viewerId)
            .ToListAsync(ct))
            .OrderByDescending(n => n.CreatedAt)
            .ThenByDescending(n => n.Id)
            .Take(MaxItems)
            .ToList();
        return new NotificationListResponse(rows.Select(ToResponse).ToList());
    }

    public async Task MarkReadAsync(Guid viewerId, Guid id, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var row = await db.InboxNotifications
            .FirstOrDefaultAsync(n => n.Id == id && n.AccountId == viewerId, ct);
        if (row is null)
        {
            throw new AuthException(404, "That notification is gone.", "That notification is gone.");
        }

        row.ReadAt ??= Now;
        await db.SaveChangesAsync(ct);
    }

    public async Task MarkAllReadAsync(Guid viewerId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var rows = await db.InboxNotifications
            .Where(n => n.AccountId == viewerId && n.ReadAt == null)
            .ToListAsync(ct);
        foreach (var row in rows) row.ReadAt = Now;
        await db.SaveChangesAsync(ct);
    }

    public async Task NotifyLikeAsync(Guid recipientId, Account from, CancellationToken ct)
    {
        if (recipientId == from.Id) return;
        await Add(
            recipientId,
            "like",
            "Someone likes you",
            $"{Name(from)} liked your profile.",
            null,
            from.Id,
            ct
        );
    }

    public async Task NotifyMatchAsync(Account a, Account b, Guid matchId, CancellationToken ct)
    {
        if (a.Id == b.Id) return;
        await Add(
            a.Id,
            "match",
            "New match",
            $"You and {Name(b)} liked each other.",
            matchId,
            b.Id,
            ct
        );
        await Add(
            b.Id,
            "match",
            "New match",
            $"You and {Name(a)} liked each other.",
            matchId,
            a.Id,
            ct
        );
    }

    public async Task NotifyMessageAsync(
        Guid recipientId,
        Account from,
        Guid matchId,
        CancellationToken ct
    )
    {
        if (recipientId == from.Id) return;
        var member = await db.ChatMembers.FindAsync([matchId, recipientId], ct);
        if (member is { Muted: true }) return;

        var unread = (await db.InboxNotifications
            .Where(n => n.AccountId == recipientId && n.Type == "message" && n.MatchId == matchId)
            .ToListAsync(ct))
            .Any(n => n.ReadAt == null);
        if (unread) return;

        await Add(
            recipientId,
            "message",
            "New message",
            $"{Name(from)} sent you a message.",
            matchId,
            from.Id,
            ct
        );
    }

    public async Task NotifySystemBulkAsync(
        IReadOnlyList<Guid> accountIds,
        string title,
        string body,
        CancellationToken ct
    )
    {
        if (accountIds.Count == 0) return;
        foreach (var accountId in accountIds.Distinct())
        {
            db.InboxNotifications.Add(
                new InboxNotification
                {
                    Id = Guid.NewGuid(),
                    AccountId = accountId,
                    Type = "system",
                    Title = title,
                    Body = body,
                    CreatedAt = Now,
                }
            );
        }

        await db.SaveChangesAsync(ct);
    }

    public Task NotifySystemAsync(Guid accountId, string title, string body, CancellationToken ct) =>
        NotifySystemBulkAsync([accountId], title, body, ct);

    async Task Add(
        Guid accountId,
        string type,
        string title,
        string body,
        Guid? matchId,
        Guid? actorId,
        CancellationToken ct)
    {
        db.InboxNotifications.Add(new InboxNotification
        {
            Id = Guid.NewGuid(),
            AccountId = accountId,
            Type = type,
            Title = title,
            Body = body,
            CreatedAt = Now,
            MatchId = matchId,
            ActorAccountId = actorId,
        });
        await db.SaveChangesAsync(ct);
    }

    async Task RequireAccount(Guid accountId, CancellationToken ct)
    {
        var account = await db.Accounts.AsNoTracking().FirstOrDefaultAsync(a => a.Id == accountId, ct);
        if (account is null)
        {
            throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        }
    }

    static string Name(Account account) =>
        string.IsNullOrWhiteSpace(account.DisplayName) ? "Someone" : account.DisplayName.Trim();

    static NotificationResponse ToResponse(InboxNotification row) =>
        new(row.Id.ToString(), row.Type, row.Title, row.Body, row.CreatedAt, row.ReadAt is not null);
}
