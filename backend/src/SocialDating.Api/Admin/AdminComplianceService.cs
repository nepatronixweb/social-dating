using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Admin;

public interface IAdminComplianceService
{
    Task<UserComplianceExportResponse> ExportUserAsync(Guid accountId, CancellationToken ct);

    Task<EraseUserResponse> EraseUserAsync(
        Guid accountId,
        EraseUserRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
}

public sealed class AdminComplianceService(AppDbContext db, TimeProvider time) : IAdminComplianceService
{
    DateTimeOffset Now => time.GetUtcNow();

    public async Task<UserComplianceExportResponse> ExportUserAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");

        if (AdminAccount.IsAdminPhone(account.PhoneE164))
        {
            throw new AuthException(400, "System account.", "Cannot export the admin ledger account.");
        }

        var promo = await db.WalletEntries
            .Where(e => e.AccountId == accountId && e.Bucket == "promotional")
            .SumAsync(e => (int?)e.Points, ct) ?? 0;
        var earned = await db.WalletEntries
            .Where(e => e.AccountId == accountId && e.Bucket == "earned")
            .SumAsync(e => (int?)e.Points, ct) ?? 0;
        var pendingWd = await db.WithdrawalRequests
            .Where(w => w.AccountId == accountId && w.Status == "recorded")
            .SumAsync(w => (int?)w.Points, ct) ?? 0;

        var photos = await db.Photos
            .Where(p => p.AccountId == accountId)
            .OrderBy(p => p.SortOrder)
            .Select(p => new UserCompliancePhoto(
                p.Id.ToString(),
                p.Kind,
                p.ReviewStatus,
                p.HiddenAt != null,
                p.CreatedAt
            ))
            .ToListAsync(ct);

        var about = await db.ModerationReports
            .Where(r => r.ReportedAccountId == accountId)
            .OrderByDescending(r => r.CreatedAt)
            .Take(50)
            .Select(r => new UserComplianceReport(
                r.Id.ToString(),
                r.Reason,
                r.Status,
                r.CreatedAt,
                r.ResolvedAt
            ))
            .ToListAsync(ct);

        var filed = await db.ModerationReports
            .Where(r => r.ReporterAccountId == accountId)
            .OrderByDescending(r => r.CreatedAt)
            .Take(50)
            .Select(r => new UserComplianceReport(
                r.Id.ToString(),
                r.Reason,
                r.Status,
                r.CreatedAt,
                r.ResolvedAt
            ))
            .ToListAsync(ct);

        var ledger = await db.WalletEntries
            .Where(e => e.AccountId == accountId)
            .OrderByDescending(e => e.OccurredAt)
            .Take(100)
            .Select(e => new UserComplianceLedgerRow(
                e.Id.ToString(),
                e.Points,
                e.Bucket,
                e.Kind,
                e.Title,
                e.OccurredAt
            ))
            .ToListAsync(ct);

        var matches = await db.Matches.CountAsync(
            m =>
                m.UnmatchedAt == null
                && (m.AccountLowId == accountId || m.AccountHighId == accountId),
            ct
        );
        var messages = await db.Messages.CountAsync(m => m.SenderAccountId == accountId, ct);
        var swipes = await db.Swipes.CountAsync(s => s.FromAccountId == accountId, ct);
        var tokens = await db.RefreshTokens.CountAsync(
            t => t.AccountId == accountId && t.RevokedAt == null && t.ExpiresAt > Now,
            ct
        );
        var openWd = await db.WithdrawalRequests.CountAsync(
            w => w.AccountId == accountId && w.Status == "recorded",
            ct
        );

        var status =
            account.DeletedAt != null ? "banned"
            : account.SuspendedAt != null ? "suspended"
            : account.ShadowBannedAt != null ? "shadowBanned"
            : "active";

        return new UserComplianceExportResponse(
            Now.ToString("O"),
            account.Id.ToString(),
            new UserComplianceAccount(
                account.PhoneE164,
                account.DisplayName,
                account.Bio,
                account.City,
                account.Gender,
                account.ReferralCode,
                account.BirthDate,
                account.AgeEligible,
                account.CreatedAt,
                account.UpdatedAt,
                account.DeletedAt,
                account.SuspendedAt,
                account.ShadowBannedAt,
                status
            ),
            new UserComplianceWallet(
                promo + earned,
                promo,
                earned,
                pendingWd
            ),
            new UserComplianceCounts(
                photos.Count,
                matches,
                messages,
                swipes,
                tokens,
                openWd
            ),
            photos,
            about,
            filed,
            ledger
        );
    }

    public async Task<EraseUserResponse> EraseUserAsync(
        Guid accountId,
        EraseUserRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSuperadmin(staff);
        if (!body.Confirm)
        {
            throw new AuthException(
                400,
                "Confirmation required.",
                "Set confirm=true to scrub PII and ban the account."
            );
        }

        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");

        if (AdminAccount.IsAdminPhone(account.PhoneE164))
        {
            throw new AuthException(400, "System account.", "Cannot erase the admin ledger account.");
        }

        var reason = string.IsNullOrWhiteSpace(body.Reason)
            ? "Staff compliance erasure"
            : body.Reason.Trim();

        // Unique phone: +d + 14 hex (fits MaxLength 16).
        var tombstone = "+d" + account.Id.ToString("N")[..14];
        account.PhoneE164 = tombstone;
        account.DisplayName = "Deleted";
        account.Bio = null;
        account.Interests = [];
        account.City = null;
        account.BirthDate = null;
        account.AgeEligible = null;
        account.AgeCheckedAt = null;
        account.ReferralCode = null;
        account.DeletedAt ??= Now;
        account.SuspendedAt = null;
        account.ShadowBannedAt = null;
        account.UpdatedAt = Now;

        var photos = await db.Photos.Where(p => p.AccountId == accountId).ToListAsync(ct);
        foreach (var photo in photos)
        {
            photo.HiddenAt ??= Now;
            photo.ReviewStatus = "rejected";
            photo.ReviewReason = "erasure";
            photo.ReviewedAt = Now;
            photo.ReviewedByEmail = staff.RequireStaffEmail();
        }

        var tokens = await db.RefreshTokens
            .Where(t => t.AccountId == accountId && t.RevokedAt == null)
            .ToListAsync(ct);
        foreach (var token in tokens)
        {
            token.RevokedAt = Now;
        }

        // Decline open withdrawal holds so balances are not stuck mid-flight.
        var openWd = await db.WithdrawalRequests
            .Where(w => w.AccountId == accountId && w.Status == "recorded")
            .ToListAsync(ct);
        foreach (var wd in openWd)
        {
            wd.Status = "declined";
            wd.ResolvedAt = Now;
            db.WalletEntries.Add(
                new WalletEntry
                {
                    Id = Guid.NewGuid(),
                    AccountId = accountId,
                    Points = wd.Points,
                    Bucket = "earned",
                    Kind = "withdrawalRelease",
                    Title = "Withdrawal released (account erasure)",
                    Detail = reason,
                    OccurredAt = Now,
                    SourceId = wd.Id.ToString("D") + ":erase",
                }
            );
        }

        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "user.erase",
                TargetType = "account",
                TargetId = account.Id.ToString(),
                Detail = reason,
                CreatedAt = Now,
            }
        );

        await db.SaveChangesAsync(ct);
        return new EraseUserResponse(
            account.Id.ToString(),
            "Account banned and PII scrubbed. Photo bytes may remain until media GC; metadata is hidden.",
            Now
        );
    }
}
