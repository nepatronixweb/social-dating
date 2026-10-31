using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Chat;
using SocialDating.Api.Inbox;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Discovery;

public interface IDiscoveryService
{
    Task<DiscoveryPageResponse> FetchDeckAsync(
        Guid viewerId,
        int? minAge,
        int? maxAge,
        string? showMe,
        bool verifiedOnly,
        string[]? interests,
        CancellationToken ct
    );

    Task<SwipeQuotaResponse> FetchQuotaAsync(Guid viewerId, CancellationToken ct);
    Task<SwipeOutcomeResponse> SwipeAsync(Guid viewerId, SwipeRequest body, CancellationToken ct);
    Task<UndoOutcomeResponse?> UndoLastAsync(Guid viewerId, CancellationToken ct);
    Task<MatchListResponse> FetchMatchesAsync(Guid viewerId, CancellationToken ct);
    Task<LikeListResponse> FetchLikesReceivedAsync(Guid viewerId, CancellationToken ct);
    Task<LikeListResponse> FetchLikesSentAsync(Guid viewerId, CancellationToken ct);
    Task<LikeOutcomeResponse> LikeBackAsync(Guid viewerId, Guid profileId, CancellationToken ct);
    Task DeclineLikeAsync(Guid viewerId, Guid profileId, CancellationToken ct);
    Task WithdrawLikeAsync(Guid viewerId, Guid profileId, CancellationToken ct);
    Task UnmatchAsync(Guid viewerId, Guid matchId, CancellationToken ct);
    Task MarkMatchSeenAsync(Guid viewerId, Guid matchId, CancellationToken ct);
    Task BlockAsync(Guid viewerId, Guid profileId, CancellationToken ct);
    Task UnblockAsync(Guid viewerId, Guid profileId, CancellationToken ct);
    Task<DiscoveryPageResponse> FetchBlockedAsync(Guid viewerId, CancellationToken ct);
}

public sealed class DiscoveryService(
    AppDbContext db,
    TimeProvider time,
    IWalletService wallet,
    PhotoService photos,
    IChatRealtime? realtime = null,
    IInboxService? inbox = null) : IDiscoveryService
{
    readonly IChatRealtime _realtime = realtime ?? NullChatRealtime.Instance;
    readonly IInboxService _inbox = inbox ?? NullInboxService.Instance;
    public const int PreviewSwipes = 5;
    public const int FreeDailySwipesMale = 20;
    public const int ExtraSwipePricePaisa = 10;

    DateTimeOffset Now => time.GetUtcNow();

    public async Task<DiscoveryPageResponse> FetchDeckAsync(
        Guid viewerId,
        int? minAge,
        int? maxAge,
        string? showMe,
        bool verifiedOnly,
        string[]? interests,
        CancellationToken ct
    )
    {
        var viewer = await RequireAccount(viewerId, ct);
        var hidden = await HiddenIds(viewerId, ct);
        var swiped = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId)
            .ToListAsync(ct))
            .Where(s => s.UndoneAt == null)
            .Select(s => s.ToAccountId)
            .ToHashSet();

        var rows = await db.Accounts
            .Where(a =>
                a.Id != viewerId
                && a.AgeEligible == true
                && a.DisplayName != null
                && a.BirthDate != null
                && a.City != null
                && a.Gender != null)
            .ToListAsync(ct);

        var min = minAge ?? 18;
        var max = maxAge ?? 60;
        var wanted = interests?.Where(i => !string.IsNullOrWhiteSpace(i)).ToHashSet(StringComparer.Ordinal)
            ?? [];

        var matched = new List<Account>();
        foreach (var account in rows)
        {
            if (swiped.Contains(account.Id) || hidden.Contains(account.Id)) continue;
            var profile = ProfileMapper.ToPublic(account, Now);
            if (profile is null) continue;
            if (profile.Age < min || profile.Age > max) continue;
            if (verifiedOnly && !profile.IsVerified) continue;
            if (!ProfileRules.ViewerSees(viewer.Gender, profile.Gender)) continue;
            if (!MatchesShowMe(showMe, profile.Gender)) continue;
            if (wanted.Count > 0 && !profile.Interests.Any(wanted.Contains)) continue;
            matched.Add(account);
            if (matched.Count >= 20) break;
        }

        var urls = await photos.UrlsByAccount(matched.Select(a => a.Id), ct);
        var items = matched
            .Select(account => ProfileMapper.ToPublic(
                account,
                Now,
                urls.GetValueOrDefault(account.Id)))
            .OfType<PublicProfileResponse>()
            .ToList();

        return new DiscoveryPageResponse(items);
    }

    public async Task<SwipeQuotaResponse> FetchQuotaAsync(Guid viewerId, CancellationToken ct)
    {
        var account = await RequireAccount(viewerId, ct);
        var quota = await QuotaFor(account, ct);
        await db.SaveChangesAsync(ct);
        return quota;
    }

    public Task<SwipeOutcomeResponse> SwipeAsync(
        Guid viewerId,
        SwipeRequest body,
        CancellationToken ct
    ) => RecordSwipe(viewerId, body, ct, countTowardQuota: true);

    async Task<SwipeOutcomeResponse> RecordSwipe(
        Guid viewerId,
        SwipeRequest body,
        CancellationToken ct,
        bool countTowardQuota
    )
    {
        var account = await RequireAccount(viewerId, ct);
        var quota = await QuotaFor(account, ct);
        var direction = (body.Direction ?? "").Trim().ToLowerInvariant();
        if (direction is not ("left" or "right"))
        {
            throw new AuthException(400, "Check your details.", "Swipe left or right.");
        }

        if (!Guid.TryParse(body.ProfileId, out var toId) || toId == viewerId)
        {
            return new SwipeOutcomeResponse(quota, null, 0, null);
        }

        if (await IsHidden(viewerId, toId, ct))
        {
            return new SwipeOutcomeResponse(quota, null, 0, null);
        }

        var paidExtra = countTowardQuota && NeedsPaid(quota);
        if (countTowardQuota)
        {
            var rejection = Reject(quota, body.ConfirmedPaid);
            if (rejection is not null)
            {
                return new SwipeOutcomeResponse(quota, null, 0, rejection);
            }
        }

        var existing = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId && s.ToAccountId == toId)
            .ToListAsync(ct))
            .FirstOrDefault(s => s.UndoneAt == null);
        if (existing is not null)
        {
            return new SwipeOutcomeResponse(quota, null, 0, null);
        }

        var target = await db.Accounts.FirstOrDefaultAsync(a => a.Id == toId, ct);
        var publicTarget = await PublicOf(target, ct);
        if (publicTarget is null)
        {
            return new SwipeOutcomeResponse(quota, null, 0, null);
        }

        if (countTowardQuota)
        {
            var day = await DayFor(viewerId, quota.DayKey, ct);
            if (quota.ProfileComplete) day.DailyUsed++;
            else day.PreviewUsed++;
        }

        var swipe = new Swipe
        {
            Id = Guid.NewGuid(),
            FromAccountId = viewerId,
            ToAccountId = toId,
            Direction = direction,
            CreatedAt = Now,
        };
        db.Swipes.Add(swipe);

        PublicProfileResponse? matched = null;
        if (direction == "right")
        {
            var otherLiked = (await db.Swipes
                .Where(s => s.FromAccountId == toId && s.ToAccountId == viewerId)
                .ToListAsync(ct))
                .Any(s => s.UndoneAt == null && s.Direction == "right");
            if (otherLiked)
            {
                var pair = Pair(viewerId, toId);
                var open = (await db.Matches
                    .Where(m => m.AccountLowId == pair.Low && m.AccountHighId == pair.High)
                    .ToListAsync(ct))
                    .FirstOrDefault(m => m.UnmatchedAt == null);
                if (open is null)
                {
                    open = new MatchPair
                    {
                        Id = Guid.NewGuid(),
                        AccountLowId = pair.Low,
                        AccountHighId = pair.High,
                        CreatedAt = Now,
                    };
                    db.Matches.Add(open);
                }

                swipe.MatchId = open.Id;
                matched = publicTarget;
            }
        }

        var charged = 0;
        if (paidExtra)
        {
            var charge = await wallet.TryChargeAsync(
                account,
                ExtraSwipePricePaisa,
                "swipeSpend",
                "Paid swipe",
                "NPR 0.10 charged as 10 points for an extra swipe.",
                swipe.Id.ToString(),
                ct
            );
            if (!charge.Ok)
            {
                return new SwipeOutcomeResponse(await QuotaFor(account, ct), null, 0, "insufficientFunds");
            }

            charged = charge.ChargedPaisa;
        }

        await db.SaveChangesAsync(ct);
        if (direction == "right" && target is not null)
        {
            try
            {
                if (matched is not null && swipe.MatchId is Guid matchId)
                    await _inbox.NotifyMatchAsync(account, target, matchId, ct);
                else
                    await _inbox.NotifyLikeAsync(toId, account, ct);
            }
            catch
            {
                // Inbox must not fail a recorded swipe.
            }
        }

        return new SwipeOutcomeResponse(await QuotaFor(account, ct), matched, charged, null);
    }

    public async Task<UndoOutcomeResponse?> UndoLastAsync(Guid viewerId, CancellationToken ct)
    {
        var account = await RequireAccount(viewerId, ct);
        var last = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId)
            .ToListAsync(ct))
            .Where(s => s.UndoneAt == null)
            .OrderByDescending(s => s.CreatedAt)
            .ThenByDescending(s => s.Id)
            .FirstOrDefault();
        if (last is null) return null;

        last.UndoneAt = Now;
        await wallet.RefundAsync(viewerId, last.Id.ToString(), ct);
        if (last.MatchId is Guid matchId)
        {
            var match = await db.Matches.FirstOrDefaultAsync(m => m.Id == matchId, ct);
            if (match is not null && match.UnmatchedAt is null)
            {
                match.UnmatchedAt = Now;
            }
        }

        var dayKey = NepalTime.DayKey(last.CreatedAt);
        var today = NepalTime.DayKey(Now);
        var day = await db.SwipeDays.FindAsync([viewerId, dayKey], ct);
        if (day is not null)
        {
            var complete = IsComplete(account);
            if (!complete) day.PreviewUsed = Math.Max(0, day.PreviewUsed - 1);
            else if (dayKey == today) day.DailyUsed = Math.Max(0, day.DailyUsed - 1);
        }

        await db.SaveChangesAsync(ct);
        var target = await db.Accounts.FirstOrDefaultAsync(a => a.Id == last.ToAccountId, ct);
        var profile = await PublicOf(target, ct);
        if (profile is null) return null;
        return new UndoOutcomeResponse(profile, await QuotaFor(account, ct));
    }

    public async Task<MatchListResponse> FetchMatchesAsync(Guid viewerId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var hidden = await HiddenIds(viewerId, ct);
        var rows = (await db.Matches
            .Where(m => m.AccountLowId == viewerId || m.AccountHighId == viewerId)
            .ToListAsync(ct))
            .Where(m => m.UnmatchedAt == null)
            .OrderByDescending(m => m.CreatedAt)
            .ToList();

        var items = new List<MatchResponse>();
        foreach (var match in rows)
        {
            var otherId = match.AccountLowId == viewerId ? match.AccountHighId : match.AccountLowId;
            if (hidden.Contains(otherId)) continue;
            var other = await db.Accounts.FirstOrDefaultAsync(a => a.Id == otherId, ct);
            var profile = await PublicOf(other, ct);
            if (profile is null) continue;
            var isNew = match.AccountLowId == viewerId ? !match.SeenByLow : !match.SeenByHigh;
            items.Add(new MatchResponse(match.Id.ToString(), profile, match.CreatedAt, isNew, null, match.Id.ToString()));
        }

        return new MatchListResponse(items);
    }

    public async Task<LikeListResponse> FetchLikesReceivedAsync(Guid viewerId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var hidden = await HiddenIds(viewerId, ct);
        var paired = await PairedIds(viewerId, ct);
        var answered = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId)
            .ToListAsync(ct))
            .Where(s => s.UndoneAt == null)
            .Select(s => s.ToAccountId)
            .ToHashSet();

        var inbound = (await db.Swipes
            .Where(s => s.ToAccountId == viewerId)
            .ToListAsync(ct))
            .Where(s =>
                s.UndoneAt == null
                && s.Direction == "right"
                && !hidden.Contains(s.FromAccountId)
                && !paired.Contains(s.FromAccountId)
                && !answered.Contains(s.FromAccountId))
            .OrderByDescending(s => s.CreatedAt)
            .ThenByDescending(s => s.Id)
            .ToList();

        return new LikeListResponse(await ToLikeItems(inbound, fromThem: true, ct));
    }

    public async Task<LikeListResponse> FetchLikesSentAsync(Guid viewerId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var hidden = await HiddenIds(viewerId, ct);
        var paired = await PairedIds(viewerId, ct);
        var sent = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId)
            .ToListAsync(ct))
            .Where(s =>
                s.UndoneAt == null
                && s.Direction == "right"
                && !hidden.Contains(s.ToAccountId)
                && !paired.Contains(s.ToAccountId))
            .OrderByDescending(s => s.CreatedAt)
            .ThenByDescending(s => s.Id)
            .ToList();

        return new LikeListResponse(await ToLikeItems(sent, fromThem: false, ct));
    }

    public async Task<LikeOutcomeResponse> LikeBackAsync(Guid viewerId, Guid profileId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        if (profileId == viewerId || await IsHidden(viewerId, profileId, ct))
        {
            throw new AuthException(404, "That like is no longer available.", "That like is no longer available.");
        }

        var open = await OpenMatch(viewerId, profileId, ct);
        if (open is not null)
        {
            var other = await db.Accounts.FirstOrDefaultAsync(a => a.Id == profileId, ct);
            var profile = await PublicOf(other, ct);
            if (profile is null)
            {
                throw new AuthException(404, "That like is no longer available.", "That like is no longer available.");
            }

            var isNew = open.AccountLowId == viewerId ? !open.SeenByLow : !open.SeenByHigh;
            return new LikeOutcomeResponse(
                new MatchResponse(open.Id.ToString(), profile, open.CreatedAt, isNew, null, open.Id.ToString()),
                false
            );
        }

        if (!await HasActiveRightSwipe(profileId, viewerId, ct))
        {
            throw new AuthException(404, "That like is no longer available.", "That like is no longer available.");
        }

        var already = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId && s.ToAccountId == profileId)
            .ToListAsync(ct))
            .FirstOrDefault(s => s.UndoneAt == null);
        if (already is not null)
        {
            throw new AuthException(404, "That like is no longer available.", "That like is no longer available.");
        }

        var outcome = await RecordSwipe(
            viewerId,
            new SwipeRequest(profileId.ToString(), "right", false),
            ct,
            countTowardQuota: false
        );
        if (outcome.MatchedProfile is null)
        {
            throw new AuthException(404, "That like is no longer available.", "That like is no longer available.");
        }

        var match = await OpenMatch(viewerId, profileId, ct);
        if (match is null)
        {
            throw new AuthException(404, "That like is no longer available.", "That like is no longer available.");
        }

        return new LikeOutcomeResponse(
            new MatchResponse(match.Id.ToString(), outcome.MatchedProfile, match.CreatedAt, true, null, match.Id.ToString()),
            true
        );
    }

    public async Task DeclineLikeAsync(Guid viewerId, Guid profileId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        if (!await HasActiveRightSwipe(profileId, viewerId, ct)) return;
        if (await IsHidden(viewerId, profileId, ct)) return;
        var mine = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId && s.ToAccountId == profileId)
            .ToListAsync(ct))
            .FirstOrDefault(s => s.UndoneAt == null);
        if (mine is not null) return;

        await RecordSwipe(
            viewerId,
            new SwipeRequest(profileId.ToString(), "left", false),
            ct,
            countTowardQuota: false
        );
    }

    public async Task WithdrawLikeAsync(Guid viewerId, Guid profileId, CancellationToken ct)
    {
        var account = await RequireAccount(viewerId, ct);
        if (await OpenMatch(viewerId, profileId, ct) is not null) return;
        if (await PairRow(viewerId, profileId, ct) is not null) return;

        var swipe = (await db.Swipes
            .Where(s => s.FromAccountId == viewerId && s.ToAccountId == profileId)
            .ToListAsync(ct))
            .FirstOrDefault(s => s.UndoneAt == null && s.Direction == "right");
        if (swipe is null) return;

        swipe.UndoneAt = Now;
        var dayKey = NepalTime.DayKey(swipe.CreatedAt);
        var today = NepalTime.DayKey(Now);
        var day = await db.SwipeDays.FindAsync([viewerId, dayKey], ct);
        if (day is not null)
        {
            var complete = IsComplete(account);
            if (!complete) day.PreviewUsed = Math.Max(0, day.PreviewUsed - 1);
            else if (dayKey == today) day.DailyUsed = Math.Max(0, day.DailyUsed - 1);
        }

        await db.SaveChangesAsync(ct);
    }

    public async Task UnmatchAsync(Guid viewerId, Guid matchId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var match = await db.Matches.FirstOrDefaultAsync(m => m.Id == matchId, ct);
        if (match is null) return;
        if (match.AccountLowId != viewerId && match.AccountHighId != viewerId) return;
        if (match.UnmatchedAt is not null) return;
        match.UnmatchedAt = Now;
        await db.SaveChangesAsync(ct);
        await _realtime.Closed(match.Id, match.AccountLowId, match.AccountHighId, ct);
    }

    public async Task MarkMatchSeenAsync(Guid viewerId, Guid matchId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var match = await db.Matches.FirstOrDefaultAsync(m => m.Id == matchId, ct);
        if (match is null || match.UnmatchedAt is not null) return;
        if (match.AccountLowId == viewerId) match.SeenByLow = true;
        else if (match.AccountHighId == viewerId) match.SeenByHigh = true;
        else return;
        await db.SaveChangesAsync(ct);
    }

    public async Task BlockAsync(Guid viewerId, Guid profileId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        if (profileId == viewerId)
        {
            throw new AuthException(400, "Check your details.", "You cannot block yourself.");
        }

        var existing = await db.Blocks.FindAsync([viewerId, profileId], ct);
        if (existing is null)
        {
            db.Blocks.Add(new Block
            {
                BlockerAccountId = viewerId,
                BlockedAccountId = profileId,
                CreatedAt = Now,
            });
        }

        var match = await OpenMatch(viewerId, profileId, ct);
        if (match is not null)
        {
            match.UnmatchedAt = Now;
        }

        await db.SaveChangesAsync(ct);
        if (match is not null)
        {
            await _realtime.Closed(match.Id, match.AccountLowId, match.AccountHighId, ct);
        }
    }

    public async Task UnblockAsync(Guid viewerId, Guid profileId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var row = await db.Blocks.FindAsync([viewerId, profileId], ct);
        if (row is not null) db.Blocks.Remove(row);
        await db.SaveChangesAsync(ct);
    }

    public async Task<DiscoveryPageResponse> FetchBlockedAsync(Guid viewerId, CancellationToken ct)
    {
        await RequireAccount(viewerId, ct);
        var rows = (await db.Blocks
            .Where(b => b.BlockerAccountId == viewerId)
            .ToListAsync(ct))
            .OrderByDescending(b => b.CreatedAt)
            .ToList();

        var items = new List<PublicProfileResponse>();
        foreach (var row in rows)
        {
            var other = await db.Accounts.FirstOrDefaultAsync(a => a.Id == row.BlockedAccountId, ct);
            var profile = await PublicOf(other, ct);
            if (profile is not null) items.Add(profile);
        }

        return new DiscoveryPageResponse(items);
    }

    async Task<PublicProfileResponse?> PublicOf(Account? account, CancellationToken ct)
    {
        if (account is null) return null;
        return ProfileMapper.ToPublic(account, Now, await photos.UrlsFor(account.Id, ct));
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

    async Task<SwipeQuotaResponse> QuotaFor(Account account, CancellationToken ct)
    {
        await wallet.EnsureWelcomeAsync(account, ct);
        var dayKey = NepalTime.DayKey(Now);
        var day = await DayFor(account.Id, dayKey, ct);
        var complete = IsComplete(account);
        int? limit = ProfileRules.NeedsPaidSubscription(account.Gender)
            ? FreeDailySwipesMale
            : null;
        return new SwipeQuotaResponse(
            complete,
            day.PreviewUsed,
            day.DailyUsed,
            limit,
            await wallet.SpendableAsync(account.Id, ct),
            ExtraSwipePricePaisa,
            dayKey,
            NepalTime.NextMidnightUtc(Now)
        );
    }

    async Task<SwipeDay> DayFor(Guid accountId, string dayKey, CancellationToken ct)
    {
        var day = await db.SwipeDays.FindAsync([accountId, dayKey], ct);
        if (day is not null) return day;
        day = new SwipeDay { AccountId = accountId, DayKey = dayKey };
        db.SwipeDays.Add(day);
        return day;
    }

    static bool NeedsPaid(SwipeQuotaResponse quota) =>
        quota.ProfileComplete && quota.FreeDailyLimit is int limit && quota.DailyUsed >= limit;

    static string? Reject(SwipeQuotaResponse quota, bool confirmedPaid)
    {
        if (!quota.ProfileComplete)
        {
            return quota.PreviewUsed >= PreviewSwipes ? "profileIncomplete" : null;
        }

        if (NeedsPaid(quota))
        {
            if (quota.BalancePaisa < quota.PricePaisa) return "insufficientFunds";
            if (!confirmedPaid) return "paymentRequired";
        }

        return null;
    }

    static bool IsComplete(Account account) =>
        account.DisplayName is not null
        && account.City is not null
        && account.Gender is not null;

    static bool MatchesShowMe(string? showMe, string? gender) =>
        showMe switch
        {
            "women" => ProfileRules.IsFemale(gender),
            "men" => ProfileRules.IsMale(gender),
            _ => true,
        };

    static (Guid Low, Guid High) Pair(Guid a, Guid b) =>
        a.CompareTo(b) < 0 ? (a, b) : (b, a);

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

    async Task<HashSet<Guid>> PairedIds(Guid viewerId, CancellationToken ct)
    {
        var rows = await db.Matches
            .Where(m => m.AccountLowId == viewerId || m.AccountHighId == viewerId)
            .ToListAsync(ct);
        return rows
            .Select(m => m.AccountLowId == viewerId ? m.AccountHighId : m.AccountLowId)
            .ToHashSet();
    }

    async Task<MatchPair?> PairRow(Guid a, Guid b, CancellationToken ct)
    {
        var pair = Pair(a, b);
        return (await db.Matches
            .Where(m => m.AccountLowId == pair.Low && m.AccountHighId == pair.High)
            .ToListAsync(ct))
            .FirstOrDefault();
    }

    async Task<MatchPair?> OpenMatch(Guid a, Guid b, CancellationToken ct)
    {
        var row = await PairRow(a, b, ct);
        return row is { UnmatchedAt: null } ? row : null;
    }

    async Task<bool> HasActiveRightSwipe(Guid fromId, Guid toId, CancellationToken ct) =>
        (await db.Swipes
            .Where(s => s.FromAccountId == fromId && s.ToAccountId == toId)
            .ToListAsync(ct))
            .Any(s => s.UndoneAt == null && s.Direction == "right");

    async Task<List<LikeItemResponse>> ToLikeItems(List<Swipe> swipes, bool fromThem, CancellationToken ct)
    {
        var items = new List<LikeItemResponse>();
        foreach (var swipe in swipes)
        {
            var otherId = fromThem ? swipe.FromAccountId : swipe.ToAccountId;
            var other = await db.Accounts.FirstOrDefaultAsync(a => a.Id == otherId, ct);
            var profile = await PublicOf(other, ct);
            if (profile is null) continue;
            items.Add(new LikeItemResponse(profile, swipe.CreatedAt));
        }

        return items;
    }
}
