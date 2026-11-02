using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Ops;
using SocialDating.Api.Wallet; // AdminAccount

namespace SocialDating.Api.Admin;

public interface IAdminDeskService
{
    Task<AttentionQueueResponse> AttentionAsync(CancellationToken ct);
    Task<PayoutRunSummaryResponse> PayoutRunAsync(CancellationToken ct);
    Task<MarkPayoutRunResponse> MarkPayoutRunAsync(
        MarkPayoutRunRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<RevenueSnapshotResponse> RevenueAsync(CancellationToken ct);
    Task<StaffActivityResponse> StaffActivityAsync(CancellationToken ct);
}

public sealed class AdminDeskService(
    AppDbContext db,
    IAdminService admin,
    IAdminTrustService trust,
    IAppConfigService config,
    Microsoft.Extensions.Options.IOptions<AdminOptions> adminOptions,
    TimeProvider time
) : IAdminDeskService
{
    DateTimeOffset Now => time.GetUtcNow();

    public async Task<AttentionQueueResponse> AttentionAsync(CancellationToken ct)
    {
        var openReports = await db.ModerationReports.CountAsync(
            r => r.Status == "open" || r.Status == "investigating",
            ct
        );
        var slaHours = Math.Max(1, adminOptions.Value.ReportSlaHours);
        var slaCut = Now.AddHours(-slaHours);
        var overdueReports = await db.ModerationReports.CountAsync(
            r =>
                (r.Status == "open" || r.Status == "investigating")
                && r.CreatedAt <= slaCut,
            ct
        );
        var openAppeals = await db.ModerationAppeals.CountAsync(a => a.Status == "open", ct);
        var openKeywordHits = await db.ChatKeywordHits.CountAsync(h => h.Status == "open", ct);
        var appealSlaHours = Math.Max(1, adminOptions.Value.AppealSlaHours);
        var appealCut = Now.AddHours(-appealSlaHours);
        var overdueAppeals = await db.ModerationAppeals.CountAsync(
            a => a.Status == "open" && a.CreatedAt <= appealCut,
            ct
        );
        var openWithdrawals = await db.WithdrawalRequests.CountAsync(w => w.Status == "recorded", ct);
        var pendingRefunds = await db.AdminRefundRequests.CountAsync(r => r.Status == "pending", ct);
        var pendingPhotos = await db.Photos.CountAsync(
            p => p.Kind == "profile" && p.HiddenAt == null && p.ReviewStatus == "pending",
            ct
        );

        var cfg = await config.GetAsync(ct);
        var kills = 0;
        if (cfg.KillDiscovery) kills++;
        if (cfg.KillChatMessaging) kills++;
        if (cfg.KillPremiumCharges) kills++;
        if (cfg.KillWithdrawals) kills++;
        if (cfg.KillReferrals) kills++;
        if (cfg.MaintenanceMode) kills++;

        var fraud = await trust.FraudDeskAsync(ct);
        var fraudCount = fraud.Items.Count;

        var items = new List<AttentionItem>();
        if (overdueReports > 0)
        {
            items.Add(
                new AttentionItem(
                    "reports_sla",
                    "high",
                    "Reports past SLA",
                    $"{overdueReports} open longer than {slaHours}h.",
                    "/reports?sla=overdue",
                    null
                )
            );
        }

        if (overdueAppeals > 0)
        {
            items.Add(
                new AttentionItem(
                    "appeals_sla",
                    "high",
                    "Appeals past SLA",
                    $"{overdueAppeals} open longer than {appealSlaHours}h.",
                    "/appeals?sla=overdue",
                    null
                )
            );
        }

        if (openAppeals > 0)
        {
            items.Add(
                new AttentionItem(
                    "appeals",
                    openAppeals >= 5 ? "high" : "medium",
                    "Open appeals",
                    $"{openAppeals} restriction appeal(s) waiting.",
                    "/appeals",
                    null
                )
            );
        }

        if (openKeywordHits > 0)
        {
            items.Add(
                new AttentionItem(
                    "keywords",
                    openKeywordHits >= 20 ? "high" : "medium",
                    "Chat keyword hits",
                    $"{openKeywordHits} flagged message(s).",
                    "/keywords",
                    null
                )
            );
        }

        if (openReports > 0)
        {
            items.Add(
                new AttentionItem(
                    "reports",
                    openReports >= 10 ? "high" : "medium",
                    "Open reports",
                    $"{openReports} awaiting trust review.",
                    "/reports",
                    null
                )
            );
        }

        if (cfg.MaintenanceMode)
        {
            items.Add(
                new AttentionItem(
                    "maintenance",
                    "high",
                    "Maintenance mode on",
                    "Clients should show a maintenance screen.",
                    "/config",
                    null
                )
            );
        }

        if (openWithdrawals > 0)
        {
            items.Add(
                new AttentionItem(
                    "withdrawals",
                    openWithdrawals >= 10 ? "high" : "medium",
                    "Recorded withdrawals",
                    $"{openWithdrawals} in payout queue.",
                    "/payouts",
                    null
                )
            );
        }

        if (pendingRefunds > 0)
        {
            items.Add(
                new AttentionItem(
                    "refunds",
                    "high",
                    "Dual-control refunds",
                    $"{pendingRefunds} need a second staff approval.",
                    "/refunds",
                    null
                )
            );
        }

        if (pendingPhotos > 0)
        {
            items.Add(
                new AttentionItem(
                    "photos",
                    pendingPhotos >= 20 ? "high" : "medium",
                    "Photos pending review",
                    $"{pendingPhotos} profile photos waiting.",
                    "/photos",
                    null
                )
            );
        }

        if (kills > 0)
        {
            items.Add(
                new AttentionItem(
                    "kills",
                    "high",
                    "Kill switches active",
                    $"{kills} feature kill(s) are on.",
                    "/config",
                    null
                )
            );
        }

        if (fraudCount > 0)
        {
            items.Add(
                new AttentionItem(
                    "fraud",
                    fraud.Items.Any(i => i.Severity == "high") ? "high" : "medium",
                    "Fraud signals",
                    $"{fraudCount} heuristic signal(s).",
                    "/fraud",
                    null
                )
            );
        }

        return new AttentionQueueResponse(
            openReports,
            overdueReports,
            openAppeals,
            openKeywordHits,
            openWithdrawals,
            pendingRefunds,
            pendingPhotos,
            kills,
            fraudCount,
            items
        );
    }

    public async Task<PayoutRunSummaryResponse> PayoutRunAsync(CancellationToken ct)
    {
        var list = await admin.ListWithdrawalsAsync("recorded", ct);
        var total = list.Items.Sum(i => i.Points);
        var fees = list.Items.Sum(i => i.FeePoints);
        var net = list.Items.Sum(i => i.NetPoints);
        return new PayoutRunSummaryResponse(
            NepalTime.DayKey(Now),
            list.Items.Count,
            total,
            fees,
            net,
            list.Items
        );
    }

    public async Task<MarkPayoutRunResponse> MarkPayoutRunAsync(
        MarkPayoutRunRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireFinanceWrite(staff);
        var ids = (body.Ids ?? [])
            .Select(raw => Guid.TryParse(raw, out var id) ? id : (Guid?)null)
            .Where(id => id is not null)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();

        if (ids.Count == 0)
        {
            throw new AuthException(400, "Check your details.", "Select at least one withdrawal id.");
        }

        var rows = await db.WithdrawalRequests
            .Where(w => ids.Contains(w.Id))
            .ToListAsync(ct);

        var recorded = rows.Where(w => w.Status == "recorded").ToList();
        var total = recorded.Sum(w => w.Points);
        if (body.ExpectedTotalPoints is int expected && expected != total)
        {
            throw new AuthException(
                400,
                "Checksum mismatch.",
                $"Expected {expected} points but selected recorded total is {total}."
            );
        }

        var skipped = ids
            .Where(id => rows.All(r => r.Id != id) || rows.Any(r => r.Id == id && r.Status != "recorded"))
            .Select(id => id.ToString())
            .ToList();

        var note = string.IsNullOrWhiteSpace(body.Note)
            ? $"Payout run — marked {recorded.Count} paid (ops only)."
            : body.Note.Trim();

        foreach (var row in recorded)
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
                    Detail = note,
                    OccurredAt = Now,
                    SourceId = row.Id.ToString("D") + ":admin-paid-batch",
                }
            );
            db.AdminAuditEvents.Add(
                new AdminAuditEvent
                {
                    Id = Guid.NewGuid(),
                    StaffUserId = staff.RequireStaffId(),
                    StaffEmail = staff.RequireStaffEmail(),
                    Action = "withdrawal.markPaidBatch",
                    TargetType = "withdrawal",
                    TargetId = row.Id.ToString(),
                    Detail = note,
                    CreatedAt = Now,
                }
            );
        }

        await db.SaveChangesAsync(ct);
        return new MarkPayoutRunResponse(
            recorded.Count,
            total,
            skipped,
            recorded.Count == 0
                ? "Nothing marked — no recorded withdrawals in the selection."
                : $"Marked {recorded.Count} withdrawal(s) paid ({total} points). Ops marker only."
        );
    }

    public async Task<StaffActivityResponse> StaffActivityAsync(CancellationToken ct)
    {
        var dayKey = NepalTime.DayKey(Now);
        var nepal = Now.ToOffset(NepalTime.Offset);
        var dayStart = new DateTimeOffset(
            nepal.Year,
            nepal.Month,
            nepal.Day,
            0,
            0,
            0,
            NepalTime.Offset
        ).ToUniversalTime();
        var weekStart = dayStart.AddDays(-6);

        var todayEvents = await db.AdminAuditEvents.AsNoTracking()
            .Where(e => e.CreatedAt >= dayStart)
            .Select(e => new { e.StaffEmail, e.Action })
            .ToListAsync(ct);

        var weekCount = await db.AdminAuditEvents.CountAsync(e => e.CreatedAt >= weekStart, ct);

        var roles = await db.StaffUsers.AsNoTracking()
            .ToDictionaryAsync(s => s.Email, s => s.Role, ct);

        var byStaff = todayEvents
            .GroupBy(e => e.StaffEmail)
            .Select(g => new StaffActivityRow(
                g.Key,
                roles.GetValueOrDefault(g.Key),
                g.Count()
            ))
            .OrderByDescending(r => r.Actions)
            .Take(20)
            .ToList();

        var topActions = todayEvents
            .GroupBy(e => e.Action)
            .Select(g => new StaffActivityActionRow(g.Key, g.Count()))
            .OrderByDescending(r => r.Count)
            .Take(15)
            .ToList();

        return new StaffActivityResponse(
            dayKey,
            todayEvents.Count,
            weekCount,
            byStaff,
            topActions
        );
    }

    public async Task<RevenueSnapshotResponse> RevenueAsync(CancellationToken ct)
    {
        var dayKey = NepalTime.DayKey(Now);
        var nepal = Now.ToOffset(NepalTime.Offset);
        var dayStart = new DateTimeOffset(
            nepal.Year,
            nepal.Month,
            nepal.Day,
            0,
            0,
            0,
            NepalTime.Offset
        ).ToUniversalTime();

        var spendKinds = new[]
        {
            "swipeSpend",
            "messageSpend",
            "superLikeSpend",
            "rewindSpend",
            "discoveryMessageSpend",
            "premiumAction",
        };

        var spends = await db.WalletEntries
            .AsNoTracking()
            .Where(e => e.OccurredAt >= dayStart && e.Points < 0 && spendKinds.Contains(e.Kind))
            .GroupBy(e => e.Kind)
            .Select(g => new { Kind = g.Key, Count = g.Count(), Points = g.Sum(x => -x.Points) })
            .ToListAsync(ct);

        var admin = await AdminAccount.EnsureAsync(db, Now, ct);
        await db.SaveChangesAsync(ct);
        var adminReceive =
            await db.WalletEntries
                .Where(e =>
                    e.AccountId == admin.Id
                    && e.OccurredAt >= dayStart
                    && e.Points > 0
                    && e.Kind == "adminReceive")
                .SumAsync(e => (int?)e.Points, ct) ?? 0;

        var rows = spends
            .OrderByDescending(s => s.Points)
            .Select(s => new RevenueKindRow(s.Kind, s.Count, s.Points))
            .ToList();
        var totalSpend = rows.Sum(r => r.Points);

        return new RevenueSnapshotResponse(dayKey, totalSpend, adminReceive, rows);
    }
}
