using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Ops;

namespace SocialDating.Api.Referrals;

public interface IReferralService
{
    Task<ReferralInfoResponse> FetchInfoAsync(Guid accountId, CancellationToken ct);
    Task<ReferralInviteListResponse> FetchInvitesAsync(Guid accountId, CancellationToken ct);
    Task<ReferralCommissionListResponse> FetchCommissionsAsync(Guid accountId, CancellationToken ct);
    Task<ReferralCommissionResponse> FetchCommissionAsync(Guid accountId, Guid id, CancellationToken ct);
    Task ClaimAsync(Guid accountId, string? code, CancellationToken ct);
    Task TryAttributeOnVerifyAsync(Guid accountId, string? code, CancellationToken ct);
    Task EnsureCodeAsync(Account account, CancellationToken ct);
}

public sealed class ReferralService(
    AppDbContext db,
    TimeProvider time,
    IOptions<ReferralOptions> options,
    IAppConfigService? appConfig = null
) : IReferralService
{
    public const int CommissionPaisa = 1000;
    public const int PurchasePaisa = 10000;
    public const int CompanyPaisa = 6000;
    public const int BuyerRewardPaisa = 3000;
    const int CodeLength = 8;
    const string Alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

    DateTimeOffset Now => time.GetUtcNow();

    public async Task<ReferralInfoResponse> FetchInfoAsync(Guid accountId, CancellationToken ct)
    {
        var account = await RequireAccount(accountId, ct);
        await EnsureCodeAsync(account, ct);
        var invites = await db.ReferralInvites
            .AsNoTracking()
            .Where(i => i.ReferrerAccountId == accountId)
            .ToListAsync(ct);
        var commissions = await db.ReferralCommissions
            .AsNoTracking()
            .Where(c => c.ReferrerAccountId == accountId)
            .ToListAsync(ct);

        var joined = invites.Count(i => i.Status is not "invited");
        var purchases = invites.Count(i => i.Status is "purchased" or "refunded");
        var pending = Sum(commissions, "pending");
        var approved = Sum(commissions, "approved");
        var paid = Sum(commissions, "paid");
        var reversed = Sum(commissions, "reversed");
        var code = account.ReferralCode!;
        var link = InviteLink(code);

        return new ReferralInfoResponse(
            code,
            link,
            ShareMessage(code, link),
            invites.Count,
            joined,
            purchases,
            pending,
            approved,
            paid,
            reversed,
            (approved + paid) / 10,
            false,
            true,
            new ReferralAllocationResponse(
                PurchasePaisa,
                CompanyPaisa,
                BuyerRewardPaisa,
                CommissionPaisa
            )
        );
    }

    public async Task<ReferralInviteListResponse> FetchInvitesAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        var rows = (await db.ReferralInvites
            .AsNoTracking()
            .Where(i => i.ReferrerAccountId == accountId)
            .ToListAsync(ct))
            .OrderByDescending(i => i.CreatedAt)
            .ThenByDescending(i => i.Id)
            .ToList();
        var names = await DisplayNames(
            rows.Select(r => r.InviteeAccountId).Distinct().ToList(),
            ct
        );
        return new ReferralInviteListResponse(
            rows.Select(r => new ReferralInviteResponse(
                r.Id.ToString(),
                names.GetValueOrDefault(r.InviteeAccountId, "A friend"),
                r.Status,
                r.CreatedAt,
                InviteDetail(r.Status)
            )).ToList()
        );
    }

    public async Task<ReferralCommissionListResponse> FetchCommissionsAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        var rows = (await db.ReferralCommissions
            .AsNoTracking()
            .Where(c => c.ReferrerAccountId == accountId)
            .ToListAsync(ct))
            .OrderByDescending(c => c.CreatedAt)
            .ThenByDescending(c => c.Id)
            .ToList();
        var invites = await db.ReferralInvites
            .AsNoTracking()
            .Where(i => i.ReferrerAccountId == accountId)
            .ToListAsync(ct);
        var names = await DisplayNames(
            invites.Select(i => i.InviteeAccountId).Distinct().ToList(),
            ct
        );
        var inviteById = invites.ToDictionary(i => i.Id);
        return new ReferralCommissionListResponse(
            rows.Select(r =>
            {
                inviteById.TryGetValue(r.InviteId, out var invite);
                var name = invite is null
                    ? "A friend"
                    : names.GetValueOrDefault(invite.InviteeAccountId, "A friend");
                return ToCommission(r, name);
            }).ToList()
        );
    }

    public async Task<ReferralCommissionResponse> FetchCommissionAsync(
        Guid accountId,
        Guid id,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        var row = await db.ReferralCommissions
            .AsNoTracking()
            .FirstOrDefaultAsync(c => c.Id == id && c.ReferrerAccountId == accountId, ct);
        if (row is null)
        {
            throw new AuthException(404, "That commission is gone.", "That commission is gone.");
        }

        var invite = await db.ReferralInvites
            .AsNoTracking()
            .FirstOrDefaultAsync(i => i.Id == row.InviteId, ct);
        var name = "A friend";
        if (invite is not null)
        {
            var names = await DisplayNames([invite.InviteeAccountId], ct);
            name = names.GetValueOrDefault(invite.InviteeAccountId, "A friend");
        }

        return ToCommission(row, name);
    }

    public Task ClaimAsync(Guid accountId, string? code, CancellationToken ct) =>
        AttributeAsync(accountId, code, required: true, ct);

    public Task TryAttributeOnVerifyAsync(Guid accountId, string? code, CancellationToken ct) =>
        string.IsNullOrWhiteSpace(code)
            ? Task.CompletedTask
            : AttributeAsync(accountId, code, required: false, ct);

    public async Task EnsureCodeAsync(Account account, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(account.ReferralCode)) return;

        for (var attempt = 0; attempt < 8; attempt++)
        {
            var code = NewCode();
            var taken = await db.Accounts.AnyAsync(a => a.ReferralCode == code, ct);
            if (taken) continue;
            account.ReferralCode = code;
            account.UpdatedAt = Now;
            await db.SaveChangesAsync(ct);
            return;
        }

        throw new AuthException(500, "Try again.", "Could not create an invite code.");
    }

    async Task AttributeAsync(Guid inviteeId, string? rawCode, bool required, CancellationToken ct)
    {
        if (appConfig is not null)
        {
            var cfg = await appConfig.GetAsync(ct);
            if (cfg.KillReferrals)
            {
                if (required)
                {
                    throw new AuthException(
                        503,
                        "Referrals paused.",
                        "Invite codes are temporarily unavailable."
                    );
                }

                return;
            }
        }

        var code = Normalize(rawCode);
        if (code is null)
        {
            if (required)
            {
                throw new AuthException(400, "Check your details.", "Enter a valid invite code.");
            }

            return;
        }

        var invitee = await RequireAccount(inviteeId, ct);
        if (invitee.ReferredByAccountId is not null)
        {
            if (required)
            {
                throw new AuthException(
                    400,
                    "Check your details.",
                    "This account already used an invite."
                );
            }

            return;
        }

        var referrer = await db.Accounts.FirstOrDefaultAsync(a => a.ReferralCode == code, ct);
        if (referrer is null)
        {
            if (required)
            {
                throw new AuthException(400, "Check your details.", "That invite code is not valid.");
            }

            return;
        }

        if (referrer.Id == invitee.Id)
        {
            if (required)
            {
                throw new AuthException(400, "Check your details.", "You cannot use your own invite.");
            }

            return;
        }

        var already = await db.ReferralInvites.AnyAsync(i => i.InviteeAccountId == invitee.Id, ct);
        if (already)
        {
            if (required)
            {
                throw new AuthException(
                    400,
                    "Check your details.",
                    "This account already used an invite."
                );
            }

            return;
        }

        invitee.ReferredByAccountId = referrer.Id;
        invitee.UpdatedAt = Now;
        var invite = new ReferralInvite
        {
            Id = Guid.NewGuid(),
            ReferrerAccountId = referrer.Id,
            InviteeAccountId = invitee.Id,
            CodeUsed = code,
            Status = "joined",
            CreatedAt = Now,
        };
        db.ReferralInvites.Add(invite);
        db.ReferralCommissions.Add(
            new ReferralCommission
            {
                Id = Guid.NewGuid(),
                InviteId = invite.Id,
                ReferrerAccountId = referrer.Id,
                AmountPaisa = CommissionPaisa,
                Status = "pending",
                Detail =
                    "Pending until a qualifying NPR 100 purchase is confirmed. "
                    + "Pending is not approved earnings.",
                CreatedAt = Now,
            }
        );
        var name = string.IsNullOrWhiteSpace(invitee.DisplayName) ? "A friend" : invitee.DisplayName;
        db.InboxNotifications.Add(
            new InboxNotification
            {
                Id = Guid.NewGuid(),
                AccountId = referrer.Id,
                Type = "system",
                Title = "A friend joined",
                Body = $"{name} used your invite.",
                CreatedAt = Now,
                ActorAccountId = invitee.Id,
            }
        );
        await db.SaveChangesAsync(ct);
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

    async Task<Dictionary<Guid, string>> DisplayNames(List<Guid> ids, CancellationToken ct)
    {
        if (ids.Count == 0) return [];
        var rows = await db.Accounts
            .AsNoTracking()
            .Where(a => ids.Contains(a.Id))
            .Select(a => new { a.Id, a.DisplayName })
            .ToListAsync(ct);
        return rows.ToDictionary(
            r => r.Id,
            r => string.IsNullOrWhiteSpace(r.DisplayName) ? "A friend" : r.DisplayName!
        );
    }

    string InviteLink(string code)
    {
        var prefix = options.Value.InviteBaseUrl.Trim().TrimEnd('/');
        if (string.IsNullOrWhiteSpace(prefix))
        {
            return $"socialdating://invite/{code}";
        }

        return $"{prefix}/{code}";
    }

    static string ShareMessage(string code, string link) =>
        $"Join me on Social Dating.\n{link}\nUse code {code} when you create an account.";

    static string InviteDetail(string status) => status switch
    {
        "purchased" =>
            "A qualifying NPR 100 purchase is recorded. The direct commission is approved.",
        "refunded" =>
            "The qualifying purchase was refunded. The commission is reversed and is not earnings.",
        _ =>
            "They joined with your code. The NPR 10 commission stays pending until a qualifying purchase is confirmed.",
    };

    static ReferralCommissionResponse ToCommission(ReferralCommission row, string name) =>
        new(
            row.Id.ToString(),
            row.InviteId.ToString(),
            name,
            row.AmountPaisa,
            row.Status,
            row.CreatedAt,
            row.ResolvedAt,
            string.IsNullOrWhiteSpace(row.Detail)
                ? "A referrer commission stays pending until a qualifying purchase is confirmed."
                : row.Detail
        );

    static int Sum(List<ReferralCommission> rows, string status) =>
        rows.Where(r => r.Status == status).Sum(r => r.AmountPaisa);

    static string? Normalize(string? raw)
    {
        if (string.IsNullOrWhiteSpace(raw)) return null;
        var chars = raw.Where(char.IsLetterOrDigit).Select(char.ToUpperInvariant).ToArray();
        if (chars.Length is < 6 or > 12) return null;
        return new string(chars);
    }

    static string NewCode()
    {
        Span<char> buffer = stackalloc char[CodeLength];
        for (var i = 0; i < CodeLength; i++)
        {
            buffer[i] = Alphabet[RandomNumberGenerator.GetInt32(Alphabet.Length)];
        }

        return new string(buffer);
    }
}
