using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Inbox;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Chat;

public interface IChatService
{
    Task<ConversationListResponse> FetchPreviewsAsync(Guid viewerId, CancellationToken ct);
    Task<MessageListResponse> FetchMessagesAsync(Guid viewerId, Guid conversationId, CancellationToken ct);
    Task<SendOutcomeResponse> SendAsync(Guid viewerId, Guid conversationId, SendMessageRequest body, CancellationToken ct);
    Task MarkReadAsync(Guid viewerId, Guid conversationId, CancellationToken ct);
    Task SetMutedAsync(Guid viewerId, Guid conversationId, bool muted, CancellationToken ct);
    Task HideAsync(Guid viewerId, Guid conversationId, CancellationToken ct);
    Task SetTypingAsync(Guid viewerId, Guid conversationId, bool typing, CancellationToken ct);
    Task<PhotoResponse> UploadPhotoAsync(
        Guid viewerId,
        Guid conversationId,
        Stream content,
        string? contentType,
        long length,
        CancellationToken ct);
}

public sealed class ChatService(
    AppDbContext db,
    TimeProvider time,
    IWalletService wallet,
    PhotoService photos,
    IChatRealtime? realtime = null,
    IInboxService? inbox = null) : IChatService
{
    readonly IChatRealtime _realtime = realtime ?? NullChatRealtime.Instance;
    readonly IInboxService _inbox = inbox ?? NullInboxService.Instance;
    DateTimeOffset Now => time.GetUtcNow();

    public async Task<ConversationListResponse> FetchPreviewsAsync(Guid viewerId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var hiddenPeople = await HiddenIds(viewerId, ct);
        var matches = (await db.Matches
            .Where(m => m.AccountLowId == viewerId || m.AccountHighId == viewerId)
            .ToListAsync(ct))
            .Where(m => m.UnmatchedAt == null)
            .ToList();

        var items = new List<ConversationResponse>();
        foreach (var match in matches)
        {
            var otherId = Other(match, viewerId);
            if (hiddenPeople.Contains(otherId)) continue;
            var member = await Member(match.Id, viewerId, ct);
            if (member.Hidden) continue;

            var last = (await db.Messages
                .Where(m => m.MatchId == match.Id)
                .ToListAsync(ct))
                .OrderByDescending(m => m.CreatedAt)
                .ThenByDescending(m => m.Id)
                .FirstOrDefault();
            if (last is null) continue;

            var other = await db.Accounts.FirstOrDefaultAsync(a => a.Id == otherId, ct);
            var profile = await PublicOf(other, ct);
            if (profile is null) continue;

            items.Add(new ConversationResponse(
                match.Id.ToString(),
                profile,
                PreviewText(last),
                last.CreatedAt,
                member.Muted ? 0 : await UnreadCount(match.Id, viewerId, member.LastReadAt, ct),
                member.Muted,
                false
            ));
        }

        return new ConversationListResponse(
            items.OrderByDescending(i => i.LastMessageAt).ToList()
        );
    }

    public async Task<MessageListResponse> FetchMessagesAsync(
        Guid viewerId,
        Guid conversationId,
        CancellationToken ct
    )
    {
        await RequireOpenChat(viewerId, conversationId, ct);
        var rows = (await db.Messages
            .Where(m => m.MatchId == conversationId)
            .ToListAsync(ct))
            .OrderBy(m => m.CreatedAt)
            .ThenBy(m => m.Id)
            .ToList();

        var items = rows.Select(m => ToMessage(m, viewerId, 0)).ToList();
        return new MessageListResponse(items);
    }

    public async Task<SendOutcomeResponse> SendAsync(
        Guid viewerId,
        Guid conversationId,
        SendMessageRequest body,
        CancellationToken ct
    )
    {
        var account = await RequireOpenChat(viewerId, conversationId, ct);
        await wallet.EnsureWelcomeAsync(account, ct);
        var text = (body.Text ?? "").Trim();
        var spendable = await wallet.SpendableAsync(viewerId, ct);
        var photoId = await RequireChatPhoto(viewerId, body.ImageId, ct);
        if (text.Length == 0 && photoId is null)
        {
            return Reject("empty", account, text, spendable);
        }

        if (text.Length > WordCount.MaxCharacters)
        {
            return Reject("tooLong", account, text, spendable);
        }

        var quote = QuoteFor(account, text);
        if (quote.CostPaisa > 0 && !body.ConfirmedPaid)
        {
            return new SendOutcomeResponse(null, "paymentRequired", quote, 0, spendable);
        }

        var message = new Message
        {
            Id = Guid.NewGuid(),
            MatchId = conversationId,
            SenderAccountId = viewerId,
            Body = text,
            PhotoId = photoId,
            CreatedAt = Now,
        };

        var charged = 0;
        if (quote.CostPaisa > 0)
        {
            var charge = await wallet.TryChargeAsync(
                account,
                quote.CostPaisa,
                "messageSpend",
                "Paid message",
                "Eligible words charged at 10 paisa each.",
                message.Id.ToString(),
                ct
            );
            if (!charge.Ok)
            {
                return new SendOutcomeResponse(null, "insufficientFunds", quote, 0, charge.BalancePaisa);
            }

            charged = charge.ChargedPaisa;
            spendable = charge.BalancePaisa;
        }

        var match = await db.Matches.FirstAsync(m => m.Id == conversationId, ct);
        var otherId = Other(match, viewerId);
        if (charged > 0)
        {
            await wallet.CreditEarnedAsync(
                otherId,
                charged,
                "messageReceived",
                "Eligible messaging",
                "Earned points from a paid message. Not cash and not a payout.",
                message.Id.ToString("D") + ":earn",
                ct
            );
        }

        db.Messages.Add(message);

        var member = await Member(conversationId, viewerId, ct);
        member.Hidden = false;
        member.LastReadAt = Now;
        await db.SaveChangesAsync(ct);
        try
        {
            await _inbox.NotifyMessageAsync(otherId, account, conversationId, ct);
        }
        catch
        {
            // Inbox must not fail a recorded send.
        }

        await _realtime.MessageSent(
            conversationId,
            viewerId,
            otherId,
            ToMessage(message, otherId, 0),
            ToMessage(message, viewerId, charged),
            ct
        );

        return new SendOutcomeResponse(ToMessage(message, viewerId, charged), null, quote, charged, spendable);
    }

    public async Task MarkReadAsync(Guid viewerId, Guid conversationId, CancellationToken ct)
    {
        await RequireOpenChat(viewerId, conversationId, ct);
        var member = await Member(conversationId, viewerId, ct);
        member.LastReadAt = Now;
        await db.SaveChangesAsync(ct);
        var match = await db.Matches.FirstAsync(m => m.Id == conversationId, ct);
        await _realtime.Read(conversationId, viewerId, Other(match, viewerId), ct);
    }

    public async Task SetTypingAsync(Guid viewerId, Guid conversationId, bool typing, CancellationToken ct)
    {
        await RequireOpenChat(viewerId, conversationId, ct);
        var match = await db.Matches.FirstAsync(m => m.Id == conversationId, ct);
        await _realtime.Typing(conversationId, Other(match, viewerId), typing, ct);
    }

    public async Task SetMutedAsync(Guid viewerId, Guid conversationId, bool muted, CancellationToken ct)
    {
        await RequireOpenChat(viewerId, conversationId, ct);
        var member = await Member(conversationId, viewerId, ct);
        member.Muted = muted;
        if (muted) member.LastReadAt = Now;
        await db.SaveChangesAsync(ct);
    }

    public async Task HideAsync(Guid viewerId, Guid conversationId, CancellationToken ct)
    {
        await RequireOpenChat(viewerId, conversationId, ct);
        var member = await Member(conversationId, viewerId, ct);
        member.Hidden = true;
        await db.SaveChangesAsync(ct);
    }

    public async Task<PhotoResponse> UploadPhotoAsync(
        Guid viewerId,
        Guid conversationId,
        Stream content,
        string? contentType,
        long length,
        CancellationToken ct)
    {
        await RequireOpenChat(viewerId, conversationId, ct);
        return await photos.UploadChat(viewerId, content, contentType, length, ct);
    }

    async Task<Account> RequireAccount(Guid accountId, CancellationToken ct)
    {
        var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == accountId, ct);
        if (account is null)
        {
            throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        }

        return account;
    }

    async Task<Account> RequireOpenChat(Guid viewerId, Guid conversationId, CancellationToken ct)
    {
        var account = await RequireAccount(viewerId, ct);
        var match = await db.Matches.FirstOrDefaultAsync(m => m.Id == conversationId, ct);
        if (match is null
            || match.UnmatchedAt is not null
            || (match.AccountLowId != viewerId && match.AccountHighId != viewerId))
        {
            throw Closed();
        }

        var otherId = Other(match, viewerId);
        if (await IsHidden(viewerId, otherId, ct))
        {
            throw Closed();
        }

        return account;
    }

    async Task<ChatMember> Member(Guid matchId, Guid accountId, CancellationToken ct)
    {
        var row = await db.ChatMembers.FindAsync([matchId, accountId], ct);
        if (row is not null) return row;
        row = new ChatMember { MatchId = matchId, AccountId = accountId };
        db.ChatMembers.Add(row);
        return row;
    }

    async Task<int> UnreadCount(Guid matchId, Guid viewerId, DateTimeOffset? lastReadAt, CancellationToken ct)
    {
        var rows = await db.Messages
            .Where(m => m.MatchId == matchId && m.SenderAccountId != viewerId)
            .ToListAsync(ct);
        if (lastReadAt is null) return rows.Count;
        return rows.Count(m => m.CreatedAt > lastReadAt.Value);
    }

    async Task<HashSet<Guid>> HiddenIds(Guid viewerId, CancellationToken ct)
    {
        var rows = await db.Blocks
            .Where(b => b.BlockerAccountId == viewerId || b.BlockedAccountId == viewerId)
            .ToListAsync(ct);
        var ids = new HashSet<Guid>();
        foreach (var row in rows)
        {
            ids.Add(row.BlockerAccountId == viewerId ? row.BlockedAccountId : row.BlockerAccountId);
        }

        return ids;
    }

    async Task<bool> IsHidden(Guid viewerId, Guid otherId, CancellationToken ct) =>
        (await HiddenIds(viewerId, ct)).Contains(otherId);

    async Task<PublicProfileResponse?> PublicOf(Account? account, CancellationToken ct)
    {
        if (account is null) return null;
        return ProfileMapper.ToPublic(account, Now, await photos.UrlsFor(account.Id, ct));
    }

    static Guid Other(MatchPair match, Guid viewerId) =>
        match.AccountLowId == viewerId ? match.AccountHighId : match.AccountLowId;

    static AuthException Closed() =>
        new(404, "This conversation has ended.", "This conversation has ended because the match was removed.");

    static MessageQuoteResponse QuoteFor(Account account, string text)
    {
        var words = WordCount.EligibleWords(text);
        var senderPays = ProfileRules.IsMale(account.Gender);
        var cost = senderPays ? words * WordCount.PaisaPerEligibleWord : 0;
        return new MessageQuoteResponse(words, text.Length, cost, senderPays);
    }

    static SendOutcomeResponse Reject(string reason, Account account, string text, int balancePaisa) =>
        new(null, reason, QuoteFor(account, text), 0, balancePaisa);

    async Task<Guid?> RequireChatPhoto(Guid viewerId, string? imageId, CancellationToken ct)
    {
        if (string.IsNullOrWhiteSpace(imageId)) return null;
        if (!Guid.TryParse(imageId, out var photoId))
        {
            throw new AuthException(400, "That photo cannot be sent.", "Upload the photo again.");
        }

        var owned = await db.Photos.AsNoTracking()
            .AnyAsync(p => p.Id == photoId && p.AccountId == viewerId && p.Kind == "chat", ct);
        if (!owned)
        {
            throw new AuthException(400, "That photo cannot be sent.", "Upload the photo again.");
        }

        return photoId;
    }

    static string PreviewText(Message message)
    {
        if (!string.IsNullOrWhiteSpace(message.Body)) return message.Body;
        return message.PhotoId is null ? "" : "Photo";
    }

    MessageResponse ToMessage(Message message, Guid viewerId, int chargedPaisa) =>
        new(
            message.Id.ToString(),
            message.Body,
            message.SenderAccountId == viewerId,
            message.CreatedAt,
            "sent",
            chargedPaisa,
            WordCount.EligibleWords(message.Body),
            message.PhotoId is Guid photoId ? photos.SignedUrl(photoId) : null
        );
}
