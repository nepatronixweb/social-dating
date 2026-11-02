using System.Security.Claims;
using System.Text;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Inbox;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Admin;

public interface IAdminService
{
    Task<AdminOverviewResponse> OverviewAsync(CancellationToken ct);
    Task<AdminUserListResponse> ListUsersAsync(
        string? q,
        string? gender,
        string? status,
        string? city,
        bool? incomplete,
        int take,
        CancellationToken ct
    );
    Task<AdminUserDetailResponse> GetUserAsync(Guid accountId, CancellationToken ct);
    Task<AdminLedgerListResponse> AdminLedgerAsync(int take, CancellationToken ct);
    Task<AdminWithdrawalListResponse> ListWithdrawalsAsync(string? status, CancellationToken ct);
    Task<AdminWithdrawalItem> ResolveWithdrawalAsync(
        Guid id,
        ResolveWithdrawalRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<AdminReportListResponse> ListReportsAsync(
        string? status,
        string? sla,
        string? claim,
        Guid? staffId,
        CancellationToken ct
    );
    Task<AdminReportItem> ClaimReportAsync(Guid id, ClaimsPrincipal staff, CancellationToken ct);
    Task<AdminReportItem> UnclaimReportAsync(Guid id, ClaimsPrincipal staff, CancellationToken ct);
    Task<AdminReportItem> ResolveReportAsync(
        Guid id,
        ResolveReportRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<string> UsersCsvAsync(
        string? q,
        string? gender,
        string? status,
        string? city,
        bool? incomplete,
        int take,
        CancellationToken ct
    );
    Task BanUserAsync(Guid accountId, BanUserRequest body, ClaimsPrincipal staff, CancellationToken ct);
    Task UnbanUserAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task SuspendUserAsync(Guid accountId, SuspendUserRequest body, ClaimsPrincipal staff, CancellationToken ct);
    Task UnsuspendUserAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task WarnUserAsync(Guid accountId, WarnUserRequest body, ClaimsPrincipal staff, CancellationToken ct);
    Task ClearPhotosAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task UnmatchAllAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task ResetSwipeDayAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task<ForceLogoutResponse> ForceLogoutAsync(
        Guid accountId,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<RefundChargeResponse> RefundChargeAsync(
        Guid accountId,
        RefundChargeRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<AdminRefundListResponse> ListRefundsAsync(string? status, CancellationToken ct);
    Task<AdminRefundItem> ResolveRefundAsync(
        Guid id,
        ResolveRefundRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<AdminReferralInviteListResponse> ListReferralInvitesAsync(CancellationToken ct);
    Task<AdminReferralCommissionListResponse> ListReferralCommissionsAsync(
        string? status,
        CancellationToken ct
    );
    Task ClawbackCommissionAsync(Guid id, string? note, ClaimsPrincipal staff, CancellationToken ct);
    Task<AdminDailyGrantListResponse> DailyFreeGrantsAsync(string? dayKey, CancellationToken ct);
    Task<AdminSubscriptionOverviewResponse> SubscriptionOverviewAsync(CancellationToken ct);
    Task SetComplimentaryAsync(
        Guid accountId,
        bool enabled,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<string> WithdrawalsCsvAsync(string? status, CancellationToken ct);
    Task AdjustPointsAsync(
        Guid accountId,
        AdjustPointsRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<AdminAuditListResponse> ListAuditAsync(
        string? q,
        string? action,
        string? staffEmail,
        int take,
        CancellationToken ct
    );
    Task<string> AuditCsvAsync(
        string? q,
        string? action,
        string? staffEmail,
        int take,
        CancellationToken ct
    );
}

public sealed class AdminService(
    AppDbContext db,
    IWalletService wallet,
    PhotoService photos,
    IInboxService inbox,
    TimeProvider time,
    IOptions<AdminOptions> adminOptions
) : IAdminService
{
    DateTimeOffset Now => time.GetUtcNow();
    int RefundThreshold => Math.Max(1, adminOptions.Value.RefundDualControlThresholdPoints);
    int ReportSlaHours => Math.Max(1, adminOptions.Value.ReportSlaHours);
    int ReportSlaWarnHours => Math.Clamp(
        adminOptions.Value.ReportSlaWarnHours,
        1,
        Math.Max(1, adminOptions.Value.ReportSlaHours - 1)
    );

    public async Task<AdminOverviewResponse> OverviewAsync(CancellationToken ct)
    {
        var dayKey = NepalTime.DayKey(Now);
        var startOfUtcDay = Now.UtcDateTime.Date;
        var admin = await AdminAccount.EnsureAsync(db, Now, ct);
        await db.SaveChangesAsync(ct);

        var adminBalance = await wallet.SpendableAsync(admin.Id, ct);
        var premiumToday = await db.WalletEntries
            .Where(e => e.AccountId == admin.Id && e.OccurredAt >= startOfUtcDay && e.Points > 0)
            .SumAsync(e => (int?)e.Points, ct) ?? 0;

        return new AdminOverviewResponse(
            await db.Accounts.IgnoreQueryFilters().CountAsync(ct),
            await db.Accounts.CountAsync(a => a.CreatedAt >= startOfUtcDay, ct),
            await db.ModerationReports.CountAsync(r => r.Status == "open" || r.Status == "investigating", ct),
            await db.WithdrawalRequests.CountAsync(w => w.Status == "recorded", ct),
            adminBalance,
            premiumToday,
            dayKey
        );
    }

    public async Task<AdminUserListResponse> ListUsersAsync(
        string? q,
        string? gender,
        string? status,
        string? city,
        bool? incomplete,
        int take,
        CancellationToken ct
    )
    {
        take = Math.Clamp(take, 1, 100);
        var query = db.Accounts.IgnoreQueryFilters().AsQueryable();
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim().ToLowerInvariant();
            query = query.Where(a =>
                (a.DisplayName != null && a.DisplayName.ToLower().Contains(term))
                || a.PhoneE164.Contains(term)
                || (a.City != null && a.City.ToLower().Contains(term))
                || a.Id.ToString().Contains(term)
            );
        }

        if (!string.IsNullOrWhiteSpace(city))
        {
            var c = city.Trim().ToLowerInvariant();
            query = query.Where(a => a.City != null && a.City.ToLower().Contains(c));
        }

        if (incomplete == true)
        {
            query = query.Where(a =>
                a.DeletedAt == null
                && (a.DisplayName == null || a.City == null || a.BirthDate == null || a.Gender == null));
        }

        var statusKey = (status ?? "").Trim().ToLowerInvariant();
        query = statusKey switch
        {
            "banned" => query.Where(a => a.DeletedAt != null),
            "suspended" => query.Where(a => a.DeletedAt == null && a.SuspendedAt != null),
            "shadowbanned" => query.Where(a =>
                a.DeletedAt == null && a.SuspendedAt == null && a.ShadowBannedAt != null),
            "active" => query.Where(a =>
                a.DeletedAt == null && a.SuspendedAt == null && a.ShadowBannedAt == null),
            _ => query,
        };

        var genderKey = ProfileRules.CanonicalGender(gender);
        var rows = await query
            .OrderByDescending(a => a.CreatedAt)
            .Take(genderKey is null ? take : Math.Min(take * 4, 400))
            .ToListAsync(ct);
        if (genderKey is not null)
        {
            rows = rows
                .Where(a => ProfileRules.CanonicalGender(a.Gender) == genderKey)
                .Take(take)
                .ToList();
        }

        var items = new List<AdminUserSummary>();
        foreach (var account in rows)
        {
            var (promo, earned) = await Balances(account.Id, ct);
            items.Add(
                new AdminUserSummary(
                    account.Id.ToString(),
                    account.DisplayName,
                    account.Gender,
                    account.City,
                    MaskPhone(account.PhoneE164),
                    promo + earned,
                    promo,
                    earned,
                    StatusOf(account),
                    account.CreatedAt,
                    account.DeletedAt,
                    account.SuspendedAt,
                    account.ShadowBannedAt
                )
            );
        }

        return new AdminUserListResponse(items);
    }

    public async Task<AdminUserDetailResponse> GetUserAsync(Guid accountId, CancellationToken ct)
    {
        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");

        var (promo, earned) = await Balances(account.Id, ct);
        var pending = await db.WithdrawalRequests
            .Where(w => w.AccountId == account.Id && w.Status == "recorded")
            .SumAsync(w => (int?)w.Points, ct) ?? 0;

        var ledger = await db.WalletEntries
            .Where(e => e.AccountId == account.Id)
            .OrderByDescending(e => e.OccurredAt)
            .Take(40)
            .ToListAsync(ct);

        var photoRows = await db.Photos.AsNoTracking()
            .Where(p => p.AccountId == account.Id && p.Kind == "profile")
            .OrderBy(p => p.SortOrder)
            .ToListAsync(ct);
        var photoUrls = photoRows.Select(p => photos.SignedUrl(p.Id)).ToArray();
        var dayKey = NepalTime.DayKey(Now);
        var swipeDay = await db.SwipeDays.FindAsync([account.Id, dayKey], ct);

        var activeMatches = await db.Matches.CountAsync(
            m =>
                m.UnmatchedAt == null
                && (m.AccountLowId == account.Id || m.AccountHighId == account.Id),
            ct
        );
        var blockedBy = await db.Blocks.CountAsync(b => b.BlockedAccountId == account.Id, ct);
        var blocking = await db.Blocks.CountAsync(b => b.BlockerAccountId == account.Id, ct);

        return new AdminUserDetailResponse(
            account.Id.ToString(),
            account.DisplayName,
            account.Gender,
            account.City,
            account.Bio,
            MaskPhone(account.PhoneE164),
            account.PhoneE164,
            promo + earned,
            promo,
            earned,
            pending,
            StatusOf(account),
            account.CreatedAt,
            account.DeletedAt,
            account.SuspendedAt,
            account.ShadowBannedAt,
            account.LastWarnedAt,
            account.TermsAcceptedAt,
            account.AgeEligible,
            ProfileRules.HasComplimentaryPremium(account),
            photoUrls.Length,
            photoUrls,
            activeMatches,
            blockedBy,
            blocking,
            swipeDay?.DayKey,
            swipeDay?.PreviewUsed ?? 0,
            swipeDay?.DailyUsed ?? 0,
            ledger.Select(e => ToLedgerItem(e)).ToList()
        );
    }

    public async Task<AdminLedgerListResponse> AdminLedgerAsync(int take, CancellationToken ct)
    {
        take = Math.Clamp(take, 1, 200);
        var admin = await AdminAccount.EnsureAsync(db, Now, ct);
        await db.SaveChangesAsync(ct);

        var rows = await db.WalletEntries
            .Where(e => e.AccountId == admin.Id)
            .OrderByDescending(e => e.OccurredAt)
            .Take(take)
            .ToListAsync(ct);

        return new AdminLedgerListResponse(
            rows.Select(e => ToLedgerItem(e, "Admin")).ToList()
        );
    }

    public async Task<AdminWithdrawalListResponse> ListWithdrawalsAsync(
        string? status,
        CancellationToken ct
    )
    {
        var query = db.WithdrawalRequests.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
        {
            var s = status.Trim().ToLowerInvariant();
            query = query.Where(w => w.Status == s);
        }

        var rows = await query.OrderByDescending(w => w.CreatedAt).Take(100).ToListAsync(ct);
        var accountIds = rows.Select(r => r.AccountId).Distinct().ToList();
        var accounts = await db.Accounts.IgnoreQueryFilters()
            .Where(a => accountIds.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, ct);

        var items = new List<AdminWithdrawalItem>();
        foreach (var w in rows)
        {
            accounts.TryGetValue(w.AccountId, out var account);
            items.Add(await ToWithdrawalItem(w, account, ct));
        }

        return new AdminWithdrawalListResponse(items);
    }

    public async Task<string> WithdrawalsCsvAsync(string? status, CancellationToken ct)
    {
        var list = await ListWithdrawalsAsync(status, ct);
        var sb = new StringBuilder();
        sb.AppendLine(
            "id,accountId,accountName,phoneMasked,gender,points,feePoints,netPoints,status,statusLabel,currentEarnedPoints,genderEligible,eligibilityLooksOk,createdAt,resolvedAt"
        );
        foreach (var w in list.Items)
        {
            sb.Append(Csv(w.Id)).Append(',')
                .Append(Csv(w.AccountId)).Append(',')
                .Append(Csv(w.AccountName)).Append(',')
                .Append(Csv(w.PhoneMasked)).Append(',')
                .Append(Csv(w.Gender)).Append(',')
                .Append(w.Points).Append(',')
                .Append(w.FeePoints).Append(',')
                .Append(w.NetPoints).Append(',')
                .Append(Csv(w.Status)).Append(',')
                .Append(Csv(w.StatusLabel)).Append(',')
                .Append(w.CurrentEarnedPoints).Append(',')
                .Append(w.GenderEligible).Append(',')
                .Append(w.EligibilityLooksOk).Append(',')
                .Append(Csv(w.CreatedAt.ToString("o"))).Append(',')
                .Append(Csv(w.ResolvedAt?.ToString("o"))).AppendLine();
        }

        return sb.ToString();
    }

    public async Task<AdminWithdrawalItem> ResolveWithdrawalAsync(
        Guid id,
        ResolveWithdrawalRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var decision = body.Decision?.Trim().ToLowerInvariant() ?? "";
        if (decision is not ("decline" or "markpaid"))
        {
            throw new AuthException(
                400,
                "Invalid decision.",
                "Use decision \"decline\" or \"markPaid\"."
            );
        }

        var row = await db.WithdrawalRequests.FirstOrDefaultAsync(w => w.Id == id, ct)
            ?? throw new AuthException(404, "Withdrawal not found.", "That withdrawal is gone.");

        if (row.Status != "recorded")
        {
            throw new AuthException(400, "Already resolved.", "Only recorded withdrawals can be resolved.");
        }

        if (decision == "decline")
        {
            row.Status = "declined";
            row.ResolvedAt = Now;
            db.WalletEntries.Add(
                new WalletEntry
                {
                    Id = Guid.NewGuid(),
                    AccountId = row.AccountId,
                    Points = row.Points,
                    Bucket = "earned",
                    Kind = "withdrawalRelease",
                    Title = "Withdrawal declined",
                    Detail = string.IsNullOrWhiteSpace(body.Note)
                        ? "Admin declined the withdrawal and released the hold."
                        : body.Note.Trim(),
                    OccurredAt = Now,
                    SourceId = row.Id.ToString("D") + ":admin-decline",
                }
            );
        }
        else
        {
            row.Status = "paid";
            row.ResolvedAt = Now;
            db.WalletEntries.Add(
                new WalletEntry
                {
                    Id = Guid.NewGuid(),
                    AccountId = row.AccountId,
                    Points = 0,
                    Bucket = "earned",
                    Kind = "other",
                    Title = "Withdrawal marked paid (ops)",
                    Detail = string.IsNullOrWhiteSpace(body.Note)
                        ? "Staff marked this withdrawal as paid outside the app. Hold was already deducted."
                        : body.Note.Trim(),
                    OccurredAt = Now,
                    SourceId = row.Id.ToString("D") + ":admin-paid",
                }
            );
        }

        await Audit(
            staff,
            decision == "decline" ? "withdrawal.decline" : "withdrawal.markPaid",
            "withdrawal",
            row.Id.ToString(),
            body.Note ?? "",
            ct
        );
        await db.SaveChangesAsync(ct);

        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == row.AccountId, ct);
        return await ToWithdrawalItem(row, account, ct);
    }

    public async Task<AdminReportListResponse> ListReportsAsync(
        string? status,
        string? sla,
        string? claim,
        Guid? staffId,
        CancellationToken ct
    )
    {
        var query = db.ModerationReports.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
        {
            var s = status.Trim().ToLowerInvariant();
            query = query.Where(r => r.Status == s);
        }

        var claimFilter = claim?.Trim().ToLowerInvariant();
        if (claimFilter == "unclaimed")
        {
            query = query.Where(r => r.ClaimedByStaffId == null);
        }
        else if (claimFilter == "mine" && staffId is Guid mine)
        {
            query = query.Where(r => r.ClaimedByStaffId == mine);
        }
        else if (claimFilter == "claimed")
        {
            query = query.Where(r => r.ClaimedByStaffId != null);
        }

        var rows = await query.OrderByDescending(r => r.CreatedAt).Take(200).ToListAsync(ct);
        var ids = rows.Select(r => r.ReportedAccountId).Distinct().ToList();
        var names = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);

        var items = rows
            .Select(r => ToReportItem(r, names.GetValueOrDefault(r.ReportedAccountId)))
            .ToList();

        var slaFilter = sla?.Trim().ToLowerInvariant();
        if (slaFilter is "overdue" or "due_soon" or "ok" or "closed")
        {
            items = items.Where(i => i.SlaState == slaFilter).ToList();
        }

        items = items
            .OrderBy(i => i.SlaState switch
            {
                "overdue" => 0,
                "due_soon" => 1,
                "ok" => 2,
                _ => 3,
            })
            .ThenBy(i => i.CreatedAt)
            .Take(100)
            .ToList();

        return new AdminReportListResponse(items);
    }

    AdminReportItem ToReportItem(ModerationReport r, string? reportedName)
    {
        var open = r.Status is "open" or "investigating";
        var due = r.CreatedAt.AddHours(ReportSlaHours);
        var ageHours = Math.Round((Now - r.CreatedAt).TotalHours, 1);
        string state;
        if (!open)
        {
            state = "closed";
        }
        else if (Now >= due)
        {
            state = "overdue";
        }
        else if (ageHours >= ReportSlaWarnHours)
        {
            state = "due_soon";
        }
        else
        {
            state = "ok";
        }

        return new AdminReportItem(
            r.Id.ToString(),
            r.ReporterAccountId.ToString(),
            r.ReportedAccountId.ToString(),
            reportedName,
            r.Reason,
            r.Detail,
            r.Status,
            r.CreatedAt,
            r.ResolvedAt,
            open ? due : null,
            state,
            ageHours,
            r.ClaimedByStaffId?.ToString(),
            r.ClaimedByEmail,
            r.ClaimedAt
        );
    }

    public async Task<AdminReportItem> ClaimReportAsync(
        Guid id,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var row = await db.ModerationReports.FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new AuthException(404, "Report not found.", "That report is gone.");

        if (row.Status is "actioned" or "dismissed")
        {
            throw new AuthException(400, "Already closed.", "Closed reports cannot be claimed.");
        }

        var staffId = staff.RequireStaffId();
        if (row.ClaimedByStaffId is Guid existing && existing != staffId)
        {
            throw new AuthException(
                409,
                "Already claimed.",
                $"Claimed by {row.ClaimedByEmail ?? "another staff"}."
            );
        }

        row.ClaimedByStaffId = staffId;
        row.ClaimedByEmail = staff.RequireStaffEmail();
        row.ClaimedAt = Now;
        if (row.Status == "open") row.Status = "investigating";

        await Audit(staff, "report.claim", "report", row.Id.ToString(), row.ClaimedByEmail ?? "", ct);
        await db.SaveChangesAsync(ct);

        var name = await db.Accounts.IgnoreQueryFilters()
            .Where(a => a.Id == row.ReportedAccountId)
            .Select(a => a.DisplayName)
            .FirstOrDefaultAsync(ct);
        return ToReportItem(row, name);
    }

    public async Task<AdminReportItem> UnclaimReportAsync(
        Guid id,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var row = await db.ModerationReports.FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new AuthException(404, "Report not found.", "That report is gone.");

        var staffId = staff.RequireStaffId();
        var isOwner = row.ClaimedByStaffId == staffId;
        if (!isOwner && !StaffRoles.CanSuperadminWrite(staff.RequireStaffRole()))
        {
            throw new AuthException(403, "Not your claim.", "Only the claimant or a superadmin can unclaim.");
        }

        row.ClaimedByStaffId = null;
        row.ClaimedByEmail = null;
        row.ClaimedAt = null;
        await Audit(staff, "report.unclaim", "report", row.Id.ToString(), "", ct);
        await db.SaveChangesAsync(ct);

        var name = await db.Accounts.IgnoreQueryFilters()
            .Where(a => a.Id == row.ReportedAccountId)
            .Select(a => a.DisplayName)
            .FirstOrDefaultAsync(ct);
        return ToReportItem(row, name);
    }

    public async Task<AdminReportItem> ResolveReportAsync(
        Guid id,
        ResolveReportRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var status = body.Status?.Trim().ToLowerInvariant() ?? "";
        if (status is not ("investigating" or "actioned" or "dismissed"))
        {
            throw new AuthException(
                400,
                "Invalid status.",
                "Use investigating, actioned, or dismissed."
            );
        }

        var row = await db.ModerationReports.FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new AuthException(404, "Report not found.", "That report is gone.");

        row.Status = status;
        row.ResolvedAt = status is "actioned" or "dismissed" ? Now : null;
        row.ResolvedByStaffId = staff.RequireStaffId();
        row.ResolutionNote = body.Note?.Trim() ?? "";

        if (status == "actioned")
        {
            var action = body.ModerationAction?.Trim().ToLowerInvariant() ?? "none";
            if ((action is "ban" or "suspend") && !StaffRoles.CanDestructiveModeration(staff.RequireStaffRole()))
            {
                throw new AuthException(
                    403,
                    "Superadmin required.",
                    "Ban and suspend from a report require superadmin. Warn or dismiss instead."
                );
            }

            await ApplyModerationAction(
                row.ReportedAccountId,
                action,
                body.Note,
                staff,
                ct
            );
        }

        await Audit(
            staff,
            "report.resolve",
            "report",
            row.Id.ToString(),
            $"{status}/{body.ModerationAction ?? "none"}: {row.ResolutionNote}",
            ct
        );
        await db.SaveChangesAsync(ct);

        if (status is "actioned" or "dismissed")
        {
            var note = string.IsNullOrWhiteSpace(row.ResolutionNote)
                ? ""
                : $" Note: {row.ResolutionNote}";
            await inbox.NotifySystemAsync(
                row.ReporterAccountId,
                status == "actioned" ? "Report update" : "Report dismissed",
                status == "actioned"
                    ? $"Your report was reviewed and actioned.{note}"
                    : $"Your report was reviewed and dismissed.{note}",
                ct
            );

            if (status == "actioned")
            {
                var action = body.ModerationAction?.Trim().ToLowerInvariant() ?? "none";
                if (action is "warn" or "suspend" or "ban")
                {
                    await inbox.NotifySystemAsync(
                        row.ReportedAccountId,
                        "Account notice",
                        action switch
                        {
                            "warn" => "A moderator issued a warning on your account.",
                            "suspend" => "Your account was suspended after a report review.",
                            "ban" => "Your account was banned after a report review.",
                            _ => "Your account was reviewed by staff.",
                        },
                        ct
                    );
                }
            }
        }

        var name = await db.Accounts.IgnoreQueryFilters()
            .Where(a => a.Id == row.ReportedAccountId)
            .Select(a => a.DisplayName)
            .FirstOrDefaultAsync(ct);

        return ToReportItem(row, name);
    }

    public async Task BanUserAsync(
        Guid accountId,
        BanUserRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var account = await RequireMember(accountId, ct);
        account.DeletedAt ??= Now;
        account.SuspendedAt = null;
        account.ShadowBannedAt = null;
        account.UpdatedAt = Now;
        await Audit(staff, "user.ban", "account", account.Id.ToString(), body.Reason?.Trim() ?? "Banned by staff.", ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task UnbanUserAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct)
    {
        var account = await RequireMember(accountId, ct);
        account.DeletedAt = null;
        account.UpdatedAt = Now;
        await Audit(staff, "user.unban", "account", account.Id.ToString(), "Ban lifted.", ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task SuspendUserAsync(
        Guid accountId,
        SuspendUserRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var account = await RequireMember(accountId, ct);
        if (account.DeletedAt is not null)
        {
            throw new AuthException(400, "Account banned.", "Unban before suspending.");
        }

        account.SuspendedAt ??= Now;
        account.UpdatedAt = Now;
        await Audit(
            staff,
            "user.suspend",
            "account",
            account.Id.ToString(),
            body.Reason?.Trim() ?? "Hidden from discovery.",
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task UnsuspendUserAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct)
    {
        var account = await RequireMember(accountId, ct);
        account.SuspendedAt = null;
        account.UpdatedAt = Now;
        await Audit(staff, "user.unsuspend", "account", account.Id.ToString(), "Suspension lifted.", ct);
        await db.SaveChangesAsync(ct);
    }

    public async Task WarnUserAsync(
        Guid accountId,
        WarnUserRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var account = await RequireMember(accountId, ct);
        account.LastWarnedAt = Now;
        account.UpdatedAt = Now;
        await Audit(
            staff,
            "user.warn",
            "account",
            account.Id.ToString(),
            body.Reason?.Trim() ?? "Staff warning.",
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task ClearPhotosAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct)
    {
        await RequireMember(accountId, ct);
        var cleared = await photos.ClearProfilePhotosAsync(accountId, ct);
        await Audit(
            staff,
            "user.clearPhotos",
            "account",
            accountId.ToString(),
            $"Cleared {cleared} profile photo(s).",
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task UnmatchAllAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct)
    {
        await RequireMember(accountId, ct);
        var matches = await db.Matches
            .Where(m =>
                m.UnmatchedAt == null
                && (m.AccountLowId == accountId || m.AccountHighId == accountId))
            .ToListAsync(ct);
        foreach (var match in matches)
        {
            match.UnmatchedAt = Now;
        }

        await Audit(
            staff,
            "user.unmatchAll",
            "account",
            accountId.ToString(),
            $"Unmatched {matches.Count} pair(s).",
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<ForceLogoutResponse> ForceLogoutAsync(
        Guid accountId,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        await RequireMember(accountId, ct);
        var revoked = await db.RefreshTokens
            .Where(t => t.AccountId == accountId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, Now), ct);

        await Audit(
            staff,
            "user.forceLogout",
            "account",
            accountId.ToString(),
            $"Revoked {revoked} refresh token(s).",
            ct
        );
        await db.SaveChangesAsync(ct);
        return new ForceLogoutResponse(
            revoked,
            revoked == 0
                ? "No active sessions to revoke."
                : $"Revoked {revoked} session(s). Access tokens expire on their own TTL."
        );
    }

    public async Task ResetSwipeDayAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct)
    {
        await RequireMember(accountId, ct);
        var dayKey = NepalTime.DayKey(Now);
        var day = await db.SwipeDays.FindAsync([accountId, dayKey], ct);
        if (day is not null)
        {
            day.PreviewUsed = 0;
            day.DailyUsed = 0;
        }

        await Audit(
            staff,
            "user.resetSwipeDay",
            "account",
            accountId.ToString(),
            $"Reset swipe counters for {dayKey}.",
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<RefundChargeResponse> RefundChargeAsync(
        Guid accountId,
        RefundChargeRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        await RequireMember(accountId, ct);
        var sourceId = body.SourceId?.Trim() ?? "";
        if (string.IsNullOrEmpty(sourceId))
        {
            throw new AuthException(400, "Source required.", "Provide the charge sourceId to refund.");
        }

        var alreadyRefunded = await db.WalletEntries.AnyAsync(
            e => e.AccountId == accountId && e.SourceId == sourceId + ":refund",
            ct
        );
        if (alreadyRefunded)
        {
            throw new AuthException(400, "Already refunded.", "That charge was already refunded.");
        }

        var points = Math.Abs(
            await db.WalletEntries
                .Where(e => e.AccountId == accountId && e.SourceId == sourceId && e.Points < 0)
                .SumAsync(e => (int?)e.Points, ct) ?? 0
        );
        if (points <= 0)
        {
            throw new AuthException(400, "No charge found.", "No debit matches that sourceId.");
        }

        if (points >= RefundThreshold)
        {
            var pending = await db.AdminRefundRequests.FirstOrDefaultAsync(
                r =>
                    r.AccountId == accountId
                    && r.SourceId == sourceId
                    && r.Status == "pending",
                ct
            );
            if (pending is not null)
            {
                return new RefundChargeResponse(
                    true,
                    true,
                    pending.Id.ToString(),
                    $"Refund already awaiting second approval ({points} points ≥ {RefundThreshold})."
                );
            }

            var req = new AdminRefundRequest
            {
                Id = Guid.NewGuid(),
                AccountId = accountId,
                SourceId = sourceId,
                Points = points,
                RequestedByStaffId = staff.RequireStaffId(),
                RequestedByEmail = staff.RequireStaffEmail(),
                Status = "pending",
                Note = body.Note?.Trim() ?? "",
                CreatedAt = Now,
            };
            db.AdminRefundRequests.Add(req);
            await Audit(
                staff,
                "wallet.refund.request",
                "account",
                accountId.ToString(),
                $"{sourceId} {points} pts pending dual control",
                ct
            );
            await db.SaveChangesAsync(ct);
            return new RefundChargeResponse(
                true,
                true,
                req.Id.ToString(),
                $"Refund queued for second staff approval ({points} points ≥ {RefundThreshold})."
            );
        }

        await wallet.RefundAsync(accountId, sourceId, ct);
        await Audit(
            staff,
            "wallet.refund",
            "account",
            accountId.ToString(),
            $"{sourceId}: {body.Note?.Trim() ?? "Staff refund"}",
            ct
        );
        await db.SaveChangesAsync(ct);
        return new RefundChargeResponse(true, false, null, "Refund applied.");
    }

    public async Task<AdminRefundListResponse> ListRefundsAsync(string? status, CancellationToken ct)
    {
        var query = db.AdminRefundRequests.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
        {
            var s = status.Trim().ToLowerInvariant();
            query = query.Where(r => r.Status == s);
        }

        var rows = await query.OrderByDescending(r => r.CreatedAt).Take(100).ToListAsync(ct);
        var ids = rows.Select(r => r.AccountId).Distinct().ToList();
        var names = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);

        return new AdminRefundListResponse(
            rows.Select(r => new AdminRefundItem(
                    r.Id.ToString(),
                    r.AccountId.ToString(),
                    names.GetValueOrDefault(r.AccountId),
                    r.SourceId,
                    r.Points,
                    r.Status,
                    r.RequestedByEmail,
                    r.ResolvedByEmail,
                    r.Note,
                    r.CreatedAt,
                    r.ResolvedAt
                ))
                .ToList()
        );
    }

    public async Task<AdminRefundItem> ResolveRefundAsync(
        Guid id,
        ResolveRefundRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var decision = body.Decision?.Trim().ToLowerInvariant() ?? "";
        if (decision is not ("approve" or "reject"))
        {
            throw new AuthException(400, "Invalid decision.", "Use approve or reject.");
        }

        var row = await db.AdminRefundRequests.FirstOrDefaultAsync(r => r.Id == id, ct)
            ?? throw new AuthException(404, "Refund request not found.", "That request is gone.");

        if (row.Status != "pending")
        {
            throw new AuthException(400, "Already resolved.", "Only pending refunds can be resolved.");
        }

        var staffId = staff.RequireStaffId();
        if (staffId == row.RequestedByStaffId)
        {
            throw new AuthException(
                400,
                "Second staff required.",
                "A different staff member must approve or reject this refund."
            );
        }

        row.ResolvedByStaffId = staffId;
        row.ResolvedByEmail = staff.RequireStaffEmail();
        row.ResolvedAt = Now;
        if (!string.IsNullOrWhiteSpace(body.Note))
        {
            row.Note = string.IsNullOrEmpty(row.Note)
                ? body.Note.Trim()
                : $"{row.Note} | {body.Note.Trim()}";
        }

        if (decision == "reject")
        {
            row.Status = "rejected";
            await Audit(staff, "wallet.refund.reject", "refund", row.Id.ToString(), row.Note, ct);
            await db.SaveChangesAsync(ct);
        }
        else
        {
            row.Status = "approved";
            await wallet.RefundAsync(row.AccountId, row.SourceId, ct);
            await Audit(staff, "wallet.refund.approve", "refund", row.Id.ToString(), row.Note, ct);
            await db.SaveChangesAsync(ct);
        }

        var name = await db.Accounts.IgnoreQueryFilters()
            .Where(a => a.Id == row.AccountId)
            .Select(a => a.DisplayName)
            .FirstOrDefaultAsync(ct);

        return new AdminRefundItem(
            row.Id.ToString(),
            row.AccountId.ToString(),
            name,
            row.SourceId,
            row.Points,
            row.Status,
            row.RequestedByEmail,
            row.ResolvedByEmail,
            row.Note,
            row.CreatedAt,
            row.ResolvedAt
        );
    }

    public async Task<AdminReferralInviteListResponse> ListReferralInvitesAsync(CancellationToken ct)
    {
        var rows = await db.ReferralInvites
            .OrderByDescending(i => i.CreatedAt)
            .Take(100)
            .ToListAsync(ct);
        var ids = rows.SelectMany(r => new[] { r.ReferrerAccountId, r.InviteeAccountId })
            .Distinct()
            .ToList();
        var names = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);

        return new AdminReferralInviteListResponse(
            rows.Select(r => new AdminReferralInviteItem(
                    r.Id.ToString(),
                    r.ReferrerAccountId.ToString(),
                    names.GetValueOrDefault(r.ReferrerAccountId),
                    r.InviteeAccountId.ToString(),
                    names.GetValueOrDefault(r.InviteeAccountId),
                    r.CodeUsed,
                    r.Status,
                    r.CreatedAt,
                    r.PurchasedAt,
                    r.RefundedAt
                ))
                .ToList()
        );
    }

    public async Task<AdminReferralCommissionListResponse> ListReferralCommissionsAsync(
        string? status,
        CancellationToken ct
    )
    {
        var query = db.ReferralCommissions.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
        {
            var s = status.Trim().ToLowerInvariant();
            query = query.Where(c => c.Status == s);
        }

        var rows = await query.OrderByDescending(c => c.CreatedAt).Take(100).ToListAsync(ct);
        var ids = rows.Select(r => r.ReferrerAccountId).Distinct().ToList();
        var names = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);

        return new AdminReferralCommissionListResponse(
            rows.Select(r => new AdminReferralCommissionItem(
                    r.Id.ToString(),
                    r.InviteId.ToString(),
                    r.ReferrerAccountId.ToString(),
                    names.GetValueOrDefault(r.ReferrerAccountId),
                    r.AmountPaisa,
                    r.Status,
                    r.Detail,
                    r.CreatedAt,
                    r.ResolvedAt
                ))
                .ToList()
        );
    }

    public async Task ClawbackCommissionAsync(
        Guid id,
        string? note,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var row = await db.ReferralCommissions.FirstOrDefaultAsync(c => c.Id == id, ct)
            ?? throw new AuthException(404, "Commission not found.", "That commission is gone.");

        if (row.Status is "reversed")
        {
            throw new AuthException(400, "Already reversed.", "Commission was already clawed back.");
        }

        row.Status = "reversed";
        row.ResolvedAt = Now;
        row.Detail = string.IsNullOrWhiteSpace(note)
            ? "Clawed back by staff."
            : note.Trim();

        var invite = await db.ReferralInvites.FirstOrDefaultAsync(i => i.Id == row.InviteId, ct);
        if (invite is not null && invite.Status == "purchased")
        {
            invite.Status = "refunded";
            invite.RefundedAt = Now;
        }

        await Audit(
            staff,
            "referral.clawback",
            "commission",
            row.Id.ToString(),
            row.Detail,
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<AdminDailyGrantListResponse> DailyFreeGrantsAsync(
        string? dayKey,
        CancellationToken ct
    )
    {
        var key = string.IsNullOrWhiteSpace(dayKey) ? NepalTime.DayKey(Now) : dayKey.Trim();
        var sourceId = $"dailyFree:{key}";
        var rows = await db.WalletEntries
            .Where(e => e.Kind == "dailyFreePoints" && e.SourceId == sourceId)
            .OrderByDescending(e => e.OccurredAt)
            .Take(500)
            .ToListAsync(ct);

        var ids = rows.Select(r => r.AccountId).Distinct().ToList();
        var accounts = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, ct);

        return new AdminDailyGrantListResponse(
            key,
            WalletService.DailyFreePointsMale,
            rows.Count,
            rows.Sum(r => r.Points),
            rows.Select(r =>
                {
                    accounts.TryGetValue(r.AccountId, out var account);
                    return new AdminDailyGrantItem(
                        r.AccountId.ToString(),
                        account?.DisplayName,
                        account?.Gender,
                        r.Points,
                        r.OccurredAt,
                        r.SourceId ?? sourceId
                    );
                })
                .ToList()
        );
    }

    public async Task<AdminSubscriptionOverviewResponse> SubscriptionOverviewAsync(
        CancellationToken ct
    )
    {
        var accounts = await db.Accounts.IgnoreQueryFilters()
            .Where(a => a.DeletedAt == null && !AdminAccount.IsAdminPhone(a.PhoneE164))
            .Select(a => new { a.Gender, a.StaffComplimentaryPremium })
            .ToListAsync(ct);

        var male = accounts.Count(a => ProfileRules.IsMale(a.Gender));
        var byGender = accounts.Count(a => ProfileRules.HasComplimentaryPremium(a.Gender));
        var staffOverride = accounts.Count(a => a.StaffComplimentaryPremium);
        var needingPaid = accounts.Count(a =>
            ProfileRules.IsMale(a.Gender) && !a.StaffComplimentaryPremium
        );

        return new AdminSubscriptionOverviewResponse(
            male,
            byGender,
            staffOverride,
            needingPaid,
            false,
            "Khalti/card checkout is not enabled. Staff can grant complimentary Premium to male accounts; female/LGBTQ+/other already include Premium."
        );
    }

    public async Task SetComplimentaryAsync(
        Guid accountId,
        bool enabled,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var account = await RequireMember(accountId, ct);
        if (!ProfileRules.IsMale(account.Gender))
        {
            throw new AuthException(
                400,
                "Not applicable.",
                "Female, LGBTQ+ and other accounts already include Premium."
            );
        }

        account.StaffComplimentaryPremium = enabled;
        account.UpdatedAt = Now;
        await Audit(
            staff,
            enabled ? "subscription.grantComplimentary" : "subscription.revokeComplimentary",
            "account",
            account.Id.ToString(),
            enabled ? "Staff complimentary Premium granted." : "Staff complimentary Premium revoked.",
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task AdjustPointsAsync(
        Guid accountId,
        AdjustPointsRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        if (body.Points == 0)
        {
            throw new AuthException(400, "Points required.", "Provide a non-zero points adjustment.");
        }

        var bucket = body.Bucket?.Trim().ToLowerInvariant() ?? "";
        if (bucket is not ("promotional" or "earned"))
        {
            throw new AuthException(400, "Invalid bucket.", "Use promotional or earned.");
        }

        var account = await RequireMember(accountId, ct);
        var title = string.IsNullOrWhiteSpace(body.Title) ? "Admin adjustment" : body.Title.Trim();
        db.WalletEntries.Add(
            new WalletEntry
            {
                Id = Guid.NewGuid(),
                AccountId = account.Id,
                Points = body.Points,
                Bucket = bucket,
                Kind = "other",
                Title = title,
                Detail = body.Detail?.Trim() ?? "Manual staff ledger adjustment.",
                OccurredAt = Now,
                SourceId = $"admin-adjust:{staff.RequireStaffId():D}:{Guid.NewGuid():N}",
            }
        );

        await Audit(
            staff,
            "wallet.adjust",
            "account",
            account.Id.ToString(),
            $"{body.Points} {bucket}: {title}",
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<AdminAuditListResponse> ListAuditAsync(
        string? q,
        string? action,
        string? staffEmail,
        int take,
        CancellationToken ct
    )
    {
        take = Math.Clamp(take, 1, 500);
        var rows = await QueryAudit(q, action, staffEmail, take, ct);
        return new AdminAuditListResponse(
            rows.Select(e => new AdminAuditItem(
                    e.Id.ToString(),
                    e.StaffEmail,
                    e.Action,
                    e.TargetType,
                    e.TargetId,
                    e.Detail,
                    e.CreatedAt
                ))
                .ToList()
        );
    }

    public async Task<string> AuditCsvAsync(
        string? q,
        string? action,
        string? staffEmail,
        int take,
        CancellationToken ct
    )
    {
        take = Math.Clamp(take, 1, 2000);
        var rows = await QueryAudit(q, action, staffEmail, take, ct);
        var sb = new StringBuilder();
        sb.AppendLine("id,staffEmail,action,targetType,targetId,detail,createdAt");
        foreach (var e in rows)
        {
            sb.Append(Csv(e.Id.ToString())).Append(',')
                .Append(Csv(e.StaffEmail)).Append(',')
                .Append(Csv(e.Action)).Append(',')
                .Append(Csv(e.TargetType)).Append(',')
                .Append(Csv(e.TargetId)).Append(',')
                .Append(Csv(e.Detail)).Append(',')
                .Append(Csv(e.CreatedAt.ToString("o"))).AppendLine();
        }

        return sb.ToString();
    }

    public async Task<string> UsersCsvAsync(
        string? q,
        string? gender,
        string? status,
        string? city,
        bool? incomplete,
        int take,
        CancellationToken ct
    )
    {
        take = Math.Clamp(take, 1, 2000);
        var list = await ListUsersAsync(q, gender, status, city, incomplete, take, ct);
        var sb = new StringBuilder();
        sb.AppendLine(
            "id,displayName,gender,city,status,spendablePoints,promotionalPoints,earnedPoints,createdAt"
        );
        foreach (var u in list.Items)
        {
            sb.Append(Csv(u.Id)).Append(',')
                .Append(Csv(u.DisplayName)).Append(',')
                .Append(Csv(u.Gender)).Append(',')
                .Append(Csv(u.City)).Append(',')
                .Append(Csv(u.Status)).Append(',')
                .Append(u.SpendablePoints).Append(',')
                .Append(u.PromotionalPoints).Append(',')
                .Append(u.EarnedPoints).Append(',')
                .Append(Csv(u.CreatedAt.ToString("o"))).AppendLine();
        }

        return sb.ToString();
    }

    async Task<List<AdminAuditEvent>> QueryAudit(
        string? q,
        string? action,
        string? staffEmail,
        int take,
        CancellationToken ct
    )
    {
        var query = db.AdminAuditEvents.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(action))
        {
            var a = action.Trim().ToLowerInvariant();
            query = query.Where(e => e.Action.ToLower().Contains(a));
        }

        if (!string.IsNullOrWhiteSpace(staffEmail))
        {
            var email = staffEmail.Trim().ToLowerInvariant();
            query = query.Where(e => e.StaffEmail.ToLower().Contains(email));
        }

        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim().ToLowerInvariant();
            query = query.Where(e =>
                e.Detail.ToLower().Contains(term)
                || (e.TargetId != null && e.TargetId.ToLower().Contains(term))
                || (e.TargetType != null && e.TargetType.ToLower().Contains(term))
                || e.Action.ToLower().Contains(term)
            );
        }

        return await query.OrderByDescending(e => e.CreatedAt).Take(take).ToListAsync(ct);
    }

    async Task ApplyModerationAction(
        Guid accountId,
        string action,
        string? note,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        switch (action)
        {
            case "ban":
                await BanUserAsync(accountId, new BanUserRequest(note), staff, ct);
                break;
            case "suspend":
                await SuspendUserAsync(accountId, new SuspendUserRequest(note), staff, ct);
                break;
            case "warn":
                await WarnUserAsync(accountId, new WarnUserRequest(note), staff, ct);
                break;
            case "none":
            case "":
                break;
            default:
                throw new AuthException(
                    400,
                    "Invalid moderation action.",
                    "Use warn, suspend, ban, or none."
                );
        }
    }

    async Task<Account> RequireMember(Guid accountId, CancellationToken ct)
    {
        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");

        if (AdminAccount.IsAdmin(account))
        {
            throw new AuthException(400, "Protected account.", "The system admin ledger cannot be moderated.");
        }

        return account;
    }

    async Task Audit(
        ClaimsPrincipal staff,
        string action,
        string? targetType,
        string? targetId,
        string detail,
        CancellationToken ct
    )
    {
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = action,
                TargetType = targetType,
                TargetId = targetId,
                Detail = detail.Length > 500 ? detail[..500] : detail,
                CreatedAt = Now,
            }
        );
        await Task.CompletedTask;
    }

    async Task<(int promo, int earned)> Balances(Guid accountId, CancellationToken ct)
    {
        var rows = await db.WalletEntries.Where(e => e.AccountId == accountId).ToListAsync(ct);
        var promo = rows.Where(e => e.Bucket == "promotional").Sum(e => e.Points);
        var earned = rows.Where(e => e.Bucket == "earned").Sum(e => e.Points);
        return (promo, earned);
    }

    static string StatusOf(Account account)
    {
        if (account.DeletedAt is not null) return "banned";
        if (account.SuspendedAt is not null) return "suspended";
        if (account.ShadowBannedAt is not null) return "shadowBanned";
        return "active";
    }

    static AdminLedgerItem ToLedgerItem(WalletEntry e, string? name = null) =>
        new(
            e.Id.ToString(),
            e.AccountId.ToString(),
            name,
            e.Points,
            e.Bucket,
            e.Kind,
            e.Title,
            e.Detail,
            e.OccurredAt,
            e.SourceId
        );

    async Task<AdminWithdrawalItem> ToWithdrawalItem(
        WithdrawalRequest w,
        Account? account,
        CancellationToken ct
    )
    {
        var (_, earned) = account is null
            ? (0, 0)
            : await Balances(account.Id, ct);
        var genderEligible = ProfileRules.CanWithdraw(account?.Gender);
        var min = WalletService.MinWithdrawalPoints;
        var eligibilityOk = genderEligible && (w.Status != "recorded" || earned + w.Points >= min);
        var eligibilityNote = !genderEligible
            ? "Gender not eligible for withdrawal."
            : w.Status == "recorded" && earned + w.Points < min
                ? $"Earned balance after hold release would be below min {min}."
                : w.Status == "paid"
                    ? "Ops-marked paid only — this API never sent money to a bank."
                    : "Eligibility snapshot looks consistent.";

        return new AdminWithdrawalItem(
            w.Id.ToString(),
            w.AccountId.ToString(),
            account?.DisplayName,
            MaskPhone(account?.PhoneE164 ?? ""),
            account?.Gender,
            w.Points,
            w.FeePoints,
            w.NetPoints,
            w.Status,
            StatusLabel(w.Status),
            earned,
            min,
            genderEligible,
            eligibilityOk,
            eligibilityNote,
            w.CreatedAt,
            w.ResolvedAt
        );
    }

    static string StatusLabel(string status) =>
        status switch
        {
            "recorded" => "Recorded hold (not paid)",
            "paid" => "Ops-marked paid (not a bank transfer)",
            "declined" => "Declined — hold released",
            "cancelled" => "Cancelled by user",
            _ => status,
        };

    static string Csv(string? value)
    {
        var v = value ?? "";
        if (v.Contains('"') || v.Contains(',') || v.Contains('\n'))
        {
            return "\"" + v.Replace("\"", "\"\"") + "\"";
        }

        return v;
    }

    static string MaskPhone(string phone)
    {
        if (string.IsNullOrEmpty(phone) || phone.Length < 6) return "••••";
        return phone[..4] + new string('•', Math.Max(0, phone.Length - 7)) + phone[^3..];
    }
}
