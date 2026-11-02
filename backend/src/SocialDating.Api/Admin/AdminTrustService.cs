using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Admin;

public interface IAdminTrustService
{
    Task<AdminUserTimelineResponse> TimelineAsync(Guid accountId, CancellationToken ct);
    Task AddCaseNoteAsync(Guid accountId, AddCaseNoteRequest body, ClaimsPrincipal staff, CancellationToken ct);
    Task<AdminFraudDeskResponse> FraudDeskAsync(CancellationToken ct);
    Task ShadowBanAsync(Guid accountId, ShadowBanRequest body, ClaimsPrincipal staff, CancellationToken ct);
    Task UnshadowBanAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task<AdminKeywordHitListResponse> ListKeywordHitsAsync(string? status, CancellationToken ct);
    Task<AdminKeywordHitItem> ResolveKeywordHitAsync(
        Guid id,
        ResolveKeywordHitRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<StaffWatchListResponse> ListWatchAsync(ClaimsPrincipal staff, CancellationToken ct);
    Task<StaffWatchItem> AddWatchAsync(
        Guid accountId,
        AddWatchRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task RemoveWatchAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task<CasePacketResponse> CasePacketAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct);
    Task<LinkedAccountsResponse> LinkedAccountsAsync(Guid accountId, CancellationToken ct);
    Task<AuthBlockListResponse> ListAuthBlocksAsync(bool? activeOnly, CancellationToken ct);
    Task<AuthBlockItem> AddAuthBlockAsync(AddAuthBlockRequest body, ClaimsPrincipal staff, CancellationToken ct);
    Task ClearAuthBlockAsync(Guid id, ClaimsPrincipal staff, CancellationToken ct);
}

public sealed class AdminTrustService(AppDbContext db, TimeProvider time) : IAdminTrustService
{
    DateTimeOffset Now => time.GetUtcNow();

    public async Task<AdminUserTimelineResponse> TimelineAsync(Guid accountId, CancellationToken ct)
    {
        _ = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");

        var idStr = accountId.ToString();
        var items = new List<AdminTimelineItem>();

        var audits = await db.AdminAuditEvents
            .AsNoTracking()
            .Where(e => e.TargetId == idStr || e.Detail.Contains(idStr))
            .OrderByDescending(e => e.CreatedAt)
            .Take(80)
            .ToListAsync(ct);
        foreach (var e in audits.Where(a => a.TargetId == idStr || a.TargetType == "account"))
        {
            items.Add(
                new AdminTimelineItem(
                    e.Id.ToString(),
                    "audit",
                    e.Action,
                    e.Detail,
                    e.StaffEmail,
                    e.TargetId,
                    e.CreatedAt
                )
            );
        }

        var reports = await db.ModerationReports
            .AsNoTracking()
            .Where(r => r.ReportedAccountId == accountId || r.ReporterAccountId == accountId)
            .OrderByDescending(r => r.CreatedAt)
            .Take(40)
            .ToListAsync(ct);
        foreach (var r in reports)
        {
            var asReporter = r.ReporterAccountId == accountId;
            items.Add(
                new AdminTimelineItem(
                    r.Id.ToString(),
                    "report",
                    asReporter ? "Filed report" : "Reported",
                    $"{r.Reason}: {r.Detail} ({r.Status})",
                    null,
                    asReporter ? r.ReportedAccountId.ToString() : r.ReporterAccountId.ToString(),
                    r.CreatedAt
                )
            );
        }

        var withdrawals = await db.WithdrawalRequests
            .AsNoTracking()
            .Where(w => w.AccountId == accountId)
            .OrderByDescending(w => w.CreatedAt)
            .Take(40)
            .ToListAsync(ct);
        foreach (var w in withdrawals)
        {
            items.Add(
                new AdminTimelineItem(
                    w.Id.ToString(),
                    "withdrawal",
                    $"Withdrawal {w.Status}",
                    $"{w.Points} points · fee {w.FeePoints}",
                    null,
                    w.Id.ToString(),
                    w.ResolvedAt ?? w.CreatedAt
                )
            );
        }

        var refunds = await db.AdminRefundRequests
            .AsNoTracking()
            .Where(r => r.AccountId == accountId)
            .OrderByDescending(r => r.CreatedAt)
            .Take(40)
            .ToListAsync(ct);
        foreach (var r in refunds)
        {
            items.Add(
                new AdminTimelineItem(
                    r.Id.ToString(),
                    "refund",
                    $"Refund {r.Status}",
                    $"{r.Points} pts · source {r.SourceId} · {r.Note}",
                    r.ResolvedByEmail ?? r.RequestedByEmail,
                    r.Id.ToString(),
                    r.ResolvedAt ?? r.CreatedAt
                )
            );
        }

        var notes = await db.StaffCaseNotes
            .AsNoTracking()
            .Where(n => n.AccountId == accountId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(40)
            .ToListAsync(ct);
        foreach (var n in notes)
        {
            items.Add(
                new AdminTimelineItem(
                    n.Id.ToString(),
                    "note",
                    "Staff note",
                    n.Body,
                    n.StaffEmail,
                    null,
                    n.CreatedAt
                )
            );
        }

        var account = await db.Accounts.IgnoreQueryFilters()
            .AsNoTracking()
            .FirstAsync(a => a.Id == accountId, ct);
        if (account.ShadowBannedAt is DateTimeOffset sb)
        {
            items.Add(
                new AdminTimelineItem(
                    "shadow",
                    "status",
                    "Shadow banned",
                    "Soft ban active — empty deck, muted send.",
                    null,
                    null,
                    sb
                )
            );
        }

        if (account.SuspendedAt is DateTimeOffset sus)
        {
            items.Add(
                new AdminTimelineItem(
                    "suspend",
                    "status",
                    "Suspended",
                    "Hidden from discovery.",
                    null,
                    null,
                    sus
                )
            );
        }

        if (account.DeletedAt is DateTimeOffset ban)
        {
            items.Add(
                new AdminTimelineItem(
                    "ban",
                    "status",
                    "Banned",
                    "Soft-deleted account.",
                    null,
                    null,
                    ban
                )
            );
        }

        if (account.LastWarnedAt is DateTimeOffset warn)
        {
            items.Add(
                new AdminTimelineItem(
                    "warn",
                    "status",
                    "Last warned",
                    "See audit for note.",
                    null,
                    null,
                    warn
                )
            );
        }

        return new AdminUserTimelineResponse(
            items.OrderByDescending(i => i.At).Take(120).ToList()
        );
    }

    public async Task AddCaseNoteAsync(
        Guid accountId,
        AddCaseNoteRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        _ = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");

        var text = (body.Body ?? "").Trim();
        if (text.Length < 2 || text.Length > 1000)
        {
            throw new AuthException(400, "Check your details.", "Note must be 2–1000 characters.");
        }

        db.StaffCaseNotes.Add(
            new StaffCaseNote
            {
                Id = Guid.NewGuid(),
                AccountId = accountId,
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Body = text,
                CreatedAt = Now,
            }
        );
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "user.caseNote",
                TargetType = "account",
                TargetId = accountId.ToString(),
                Detail = text.Length > 200 ? text[..200] : text,
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<AdminFraudDeskResponse> FraudDeskAsync(CancellationToken ct)
    {
        var signals = new List<AdminFraudSignal>();
        var start7d = Now.AddDays(-7);
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

        // Repeat reporters (7d)
        var reporterGroups = await db.ModerationReports
            .AsNoTracking()
            .Where(r => r.CreatedAt >= start7d)
            .GroupBy(r => r.ReporterAccountId)
            .Select(g => new { AccountId = g.Key, Count = g.Count() })
            .Where(g => g.Count >= 3)
            .OrderByDescending(g => g.Count)
            .Take(25)
            .ToListAsync(ct);
        var reporterIds = reporterGroups.Select(g => g.AccountId).ToList();
        var reporterNames = await Names(reporterIds, ct);
        foreach (var g in reporterGroups)
        {
            signals.Add(
                new AdminFraudSignal(
                    $"repeat-reporter:{g.AccountId}",
                    "repeatReporter",
                    g.Count >= 8 ? "high" : "medium",
                    "Repeat reporter",
                    $"{g.Count} reports in 7 days.",
                    g.AccountId.ToString(),
                    reporterNames.GetValueOrDefault(g.AccountId),
                    g.Count,
                    Now
                )
            );
        }

        // Same-day swipe spam
        var swipeSpam = await db.Swipes
            .AsNoTracking()
            .Where(s => s.CreatedAt >= dayStart && s.UndoneAt == null)
            .GroupBy(s => s.FromAccountId)
            .Select(g => new { AccountId = g.Key, Count = g.Count() })
            .Where(g => g.Count >= 80)
            .OrderByDescending(g => g.Count)
            .Take(25)
            .ToListAsync(ct);
        var spamIds = swipeSpam.Select(g => g.AccountId).ToList();
        var spamNames = await Names(spamIds, ct);
        foreach (var g in swipeSpam)
        {
            signals.Add(
                new AdminFraudSignal(
                    $"swipe-spam:{g.AccountId}:{dayKey}",
                    "swipeSpam",
                    g.Count >= 200 ? "high" : "medium",
                    "Same-day swipe spam",
                    $"{g.Count} swipes today (Nepal {dayKey}).",
                    g.AccountId.ToString(),
                    spamNames.GetValueOrDefault(g.AccountId),
                    g.Count,
                    Now
                )
            );
        }

        // Referral rings: referrer → many incomplete males
        var invites = await db.ReferralInvites
            .AsNoTracking()
            .Where(i => i.CreatedAt >= start7d)
            .ToListAsync(ct);
        var inviteeIds = invites.Select(i => i.InviteeAccountId).Distinct().ToList();
        var invitees = await db.Accounts.IgnoreQueryFilters()
            .AsNoTracking()
            .Where(a => inviteeIds.Contains(a.Id))
            .ToListAsync(ct);
        var inviteeMap = invitees.ToDictionary(a => a.Id);
        var ringGroups = invites
            .GroupBy(i => i.ReferrerAccountId)
            .Select(g =>
            {
                var incompleteMales = g.Count(i =>
                {
                    if (!inviteeMap.TryGetValue(i.InviteeAccountId, out var a)) return false;
                    return ProfileRules.IsMale(a.Gender)
                        && (a.DisplayName is null || a.City is null || a.BirthDate is null);
                });
                return new { ReferrerId = g.Key, Total = g.Count(), IncompleteMales = incompleteMales };
            })
            .Where(x => x.IncompleteMales >= 3)
            .OrderByDescending(x => x.IncompleteMales)
            .Take(25)
            .ToList();
        var ringIds = ringGroups.Select(x => x.ReferrerId).ToList();
        var ringNames = await Names(ringIds, ct);
        foreach (var g in ringGroups)
        {
            signals.Add(
                new AdminFraudSignal(
                    $"referral-ring:{g.ReferrerId}",
                    "referralRing",
                    g.IncompleteMales >= 8 ? "high" : "medium",
                    "Referral ring (incomplete males)",
                    $"{g.IncompleteMales} incomplete male invitees of {g.Total} in 7 days.",
                    g.ReferrerId.ToString(),
                    ringNames.GetValueOrDefault(g.ReferrerId),
                    g.IncompleteMales,
                    Now
                )
            );
        }

        // Withdraw-then-ban / suspend
        var recentWithdrawals = await db.WithdrawalRequests
            .AsNoTracking()
            .Where(w =>
                w.CreatedAt >= start7d && (w.Status == "recorded" || w.Status == "paid"))
            .ToListAsync(ct);
        var wdAccountIds = recentWithdrawals.Select(w => w.AccountId).Distinct().ToList();
        var flaggedAccounts = await db.Accounts.IgnoreQueryFilters()
            .AsNoTracking()
            .Where(a =>
                wdAccountIds.Contains(a.Id)
                && (a.DeletedAt != null || a.SuspendedAt != null || a.ShadowBannedAt != null))
            .ToListAsync(ct);
        foreach (var a in flaggedAccounts)
        {
            var w = recentWithdrawals
                .Where(x => x.AccountId == a.Id)
                .OrderByDescending(x => x.CreatedAt)
                .First();
            var flag =
                a.DeletedAt != null ? "banned"
                : a.SuspendedAt != null ? "suspended"
                : "shadow-banned";
            signals.Add(
                new AdminFraudSignal(
                    $"withdraw-then-flag:{a.Id}",
                    "withdrawThenBan",
                    "high",
                    "Withdraw then restricted",
                    $"Withdrawal {w.Status} ({w.Points} pts) then account {flag}.",
                    a.Id.ToString(),
                    a.DisplayName,
                    w.Points,
                    a.DeletedAt ?? a.SuspendedAt ?? a.ShadowBannedAt ?? Now
                )
            );
        }

        // Multi-account by shared device id (7d sessions)
        var deviceGroups = await db.RefreshTokens
            .AsNoTracking()
            .Where(t => t.CreatedAt >= start7d && t.DeviceId != null && t.DeviceId != "")
            .GroupBy(t => t.DeviceId!)
            .Select(g => new
            {
                DeviceId = g.Key,
                AccountCount = g.Select(x => x.AccountId).Distinct().Count(),
            })
            .Where(g => g.AccountCount >= 3)
            .OrderByDescending(g => g.AccountCount)
            .Take(25)
            .ToListAsync(ct);
        foreach (var g in deviceGroups)
        {
            var sampleAccount = await db.RefreshTokens
                .AsNoTracking()
                .Where(t => t.DeviceId == g.DeviceId && t.CreatedAt >= start7d)
                .Select(t => t.AccountId)
                .FirstAsync(ct);
            var name = (await Names([sampleAccount], ct)).GetValueOrDefault(sampleAccount);
            signals.Add(
                new AdminFraudSignal(
                    $"multi-device:{g.DeviceId}",
                    "multiAccountDevice",
                    g.AccountCount >= 5 ? "high" : "medium",
                    "Multi-account (device)",
                    $"{g.AccountCount} accounts shared device id in 7 days.",
                    sampleAccount.ToString(),
                    name,
                    g.AccountCount,
                    Now
                )
            );
        }

        // Multi-account by shared IP (7d) — noisier; higher threshold
        var ipGroups = await db.RefreshTokens
            .AsNoTracking()
            .Where(t => t.CreatedAt >= start7d && t.IpAddress != null && t.IpAddress != "")
            .GroupBy(t => t.IpAddress!)
            .Select(g => new
            {
                Ip = g.Key,
                AccountCount = g.Select(x => x.AccountId).Distinct().Count(),
            })
            .Where(g => g.AccountCount >= 5)
            .OrderByDescending(g => g.AccountCount)
            .Take(15)
            .ToListAsync(ct);
        foreach (var g in ipGroups)
        {
            var sampleAccount = await db.RefreshTokens
                .AsNoTracking()
                .Where(t => t.IpAddress == g.Ip && t.CreatedAt >= start7d)
                .Select(t => t.AccountId)
                .FirstAsync(ct);
            var name = (await Names([sampleAccount], ct)).GetValueOrDefault(sampleAccount);
            signals.Add(
                new AdminFraudSignal(
                    $"multi-ip:{g.Ip}",
                    "multiAccountIp",
                    g.AccountCount >= 10 ? "high" : "medium",
                    "Multi-account (IP)",
                    $"{g.AccountCount} accounts shared IP {g.Ip} in 7 days.",
                    sampleAccount.ToString(),
                    name,
                    g.AccountCount,
                    Now
                )
            );
        }

        return new AdminFraudDeskResponse(
            signals
                .OrderByDescending(s => s.Severity == "high")
                .ThenByDescending(s => s.Score)
                .Take(80)
                .ToList()
        );
    }

    public async Task ShadowBanAsync(
        Guid accountId,
        ShadowBanRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var account = await RequireMember(accountId, ct);
        if (account.DeletedAt is not null)
        {
            throw new AuthException(400, "Account banned.", "Unban before shadow-banning.");
        }

        account.ShadowBannedAt ??= Now;
        account.UpdatedAt = Now;
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "user.shadowBan",
                TargetType = "account",
                TargetId = account.Id.ToString(),
                Detail = body.Reason?.Trim() ?? "Shadow ban — empty deck, muted chat.",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task UnshadowBanAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct)
    {
        StaffRoles.RequireSupportWrite(staff);
        var account = await RequireMember(accountId, ct);
        account.ShadowBannedAt = null;
        account.UpdatedAt = Now;
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "user.unshadowBan",
                TargetType = "account",
                TargetId = account.Id.ToString(),
                Detail = "Shadow ban lifted.",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<AdminKeywordHitListResponse> ListKeywordHitsAsync(
        string? status,
        CancellationToken ct
    )
    {
        var query = db.ChatKeywordHits.AsNoTracking().AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
        {
            var s = status.Trim().ToLowerInvariant();
            query = query.Where(h => h.Status == s);
        }

        var rows = await query.OrderByDescending(h => h.CreatedAt).Take(100).ToListAsync(ct);
        var names = await Names(rows.Select(r => r.SenderAccountId).Distinct().ToList(), ct);
        return new AdminKeywordHitListResponse(
            rows.Select(h => new AdminKeywordHitItem(
                    h.Id.ToString(),
                    h.MessageId.ToString(),
                    h.MatchId.ToString(),
                    h.SenderAccountId.ToString(),
                    names.GetValueOrDefault(h.SenderAccountId),
                    h.Keyword,
                    h.MessageBody,
                    h.Status,
                    h.CreatedAt,
                    h.ResolvedAt
                ))
                .ToList()
        );
    }

    public async Task<AdminKeywordHitItem> ResolveKeywordHitAsync(
        Guid id,
        ResolveKeywordHitRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var decision = body.Decision?.Trim().ToLowerInvariant() ?? "";
        if (decision is not ("dismiss" or "actioned"))
        {
            throw new AuthException(400, "Invalid decision.", "Use dismiss or actioned.");
        }

        var row = await db.ChatKeywordHits.FirstOrDefaultAsync(h => h.Id == id, ct)
            ?? throw new AuthException(404, "Hit not found.", "That keyword hit is gone.");

        if (row.Status != "open")
        {
            throw new AuthException(400, "Already resolved.", "This hit is closed.");
        }

        row.Status = decision == "dismiss" ? "dismissed" : "actioned";
        row.ResolvedAt = Now;
        row.ResolvedByStaffId = staff.RequireStaffId();
        row.ResolutionNote = body.Note?.Trim() ?? "";

        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = decision == "dismiss" ? "keyword.dismiss" : "keyword.actioned",
                TargetType = "keywordHit",
                TargetId = row.Id.ToString(),
                Detail = $"{row.Keyword}: {row.ResolutionNote}",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);

        var names = await Names([row.SenderAccountId], ct);
        return new AdminKeywordHitItem(
            row.Id.ToString(),
            row.MessageId.ToString(),
            row.MatchId.ToString(),
            row.SenderAccountId.ToString(),
            names.GetValueOrDefault(row.SenderAccountId),
            row.Keyword,
            row.MessageBody,
            row.Status,
            row.CreatedAt,
            row.ResolvedAt
        );
    }

    public async Task<StaffWatchListResponse> ListWatchAsync(
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var staffId = staff.RequireStaffId();
        var rows = await db.StaffWatchEntries.AsNoTracking()
            .Where(w => w.StaffUserId == staffId)
            .OrderByDescending(w => w.CreatedAt)
            .Take(100)
            .ToListAsync(ct);
        var accounts = await db.Accounts.IgnoreQueryFilters()
            .Where(a => rows.Select(r => r.AccountId).Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, ct);

        return new StaffWatchListResponse(
            rows.Select(w =>
                {
                    accounts.TryGetValue(w.AccountId, out var a);
                    var status =
                        a is null ? null
                        : a.DeletedAt != null ? "banned"
                        : a.SuspendedAt != null ? "suspended"
                        : a.ShadowBannedAt != null ? "shadowBanned"
                        : "active";
                    return new StaffWatchItem(
                        w.Id.ToString(),
                        w.AccountId.ToString(),
                        a?.DisplayName,
                        status,
                        w.Note,
                        w.CreatedAt
                    );
                })
                .ToList()
        );
    }

    public async Task<StaffWatchItem> AddWatchAsync(
        Guid accountId,
        AddWatchRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var account = await RequireMember(accountId, ct);
        var staffId = staff.RequireStaffId();
        var existing = await db.StaffWatchEntries.FirstOrDefaultAsync(
            w => w.StaffUserId == staffId && w.AccountId == accountId,
            ct
        );
        if (existing is not null)
        {
            existing.Note = body.Note?.Trim() ?? existing.Note;
            await db.SaveChangesAsync(ct);
            return new StaffWatchItem(
                existing.Id.ToString(),
                accountId.ToString(),
                account.DisplayName,
                account.DeletedAt != null ? "banned"
                    : account.SuspendedAt != null ? "suspended"
                    : account.ShadowBannedAt != null ? "shadowBanned"
                    : "active",
                existing.Note,
                existing.CreatedAt
            );
        }

        var row = new StaffWatchEntry
        {
            Id = Guid.NewGuid(),
            StaffUserId = staffId,
            AccountId = accountId,
            Note = body.Note?.Trim() ?? "",
            CreatedAt = Now,
        };
        db.StaffWatchEntries.Add(row);
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staffId,
                StaffEmail = staff.RequireStaffEmail(),
                Action = "watch.add",
                TargetType = "account",
                TargetId = accountId.ToString(),
                Detail = row.Note,
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
        return new StaffWatchItem(
            row.Id.ToString(),
            accountId.ToString(),
            account.DisplayName,
            account.DeletedAt != null ? "banned"
                : account.SuspendedAt != null ? "suspended"
                : account.ShadowBannedAt != null ? "shadowBanned"
                : "active",
            row.Note,
            row.CreatedAt
        );
    }

    public async Task RemoveWatchAsync(Guid accountId, ClaimsPrincipal staff, CancellationToken ct)
    {
        StaffRoles.RequireSupportWrite(staff);
        var staffId = staff.RequireStaffId();
        var row = await db.StaffWatchEntries.FirstOrDefaultAsync(
            w => w.StaffUserId == staffId && w.AccountId == accountId,
            ct
        );
        if (row is null) return;
        db.StaffWatchEntries.Remove(row);
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staffId,
                StaffEmail = staff.RequireStaffEmail(),
                Action = "watch.remove",
                TargetType = "account",
                TargetId = accountId.ToString(),
                Detail = "",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<CasePacketResponse> CasePacketAsync(
        Guid accountId,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        var account = await RequireMember(accountId, ct);
        var staffId = staff.RequireStaffId();
        var onWatch = await db.StaffWatchEntries.AnyAsync(
            w => w.StaffUserId == staffId && w.AccountId == accountId,
            ct
        );

        var status =
            account.DeletedAt != null ? "banned"
            : account.SuspendedAt != null ? "suspended"
            : account.ShadowBannedAt != null ? "shadowBanned"
            : "active";

        var openReports = await db.ModerationReports.CountAsync(
            r =>
                r.ReportedAccountId == accountId
                && (r.Status == "open" || r.Status == "investigating"),
            ct
        );
        var openAppeals = await db.ModerationAppeals.CountAsync(
            a => a.AccountId == accountId && a.Status == "open",
            ct
        );
        var openHits = await db.ChatKeywordHits.CountAsync(
            h => h.SenderAccountId == accountId && h.Status == "open",
            ct
        );
        var matches = await db.Matches.CountAsync(
            m =>
                m.UnmatchedAt == null
                && (m.AccountLowId == accountId || m.AccountHighId == accountId),
            ct
        );
        var week = Now.AddDays(-7);
        var msgs = await db.Messages.CountAsync(
            m => m.SenderAccountId == accountId && m.CreatedAt >= week,
            ct
        );

        var reports = await db.ModerationReports.AsNoTracking()
            .Where(r => r.ReportedAccountId == accountId)
            .OrderByDescending(r => r.CreatedAt)
            .Take(8)
            .Select(r => new CasePacketLine(
                r.Id.ToString(),
                "report",
                r.Reason,
                $"{r.Status}: {r.Detail}",
                r.CreatedAt
            ))
            .ToListAsync(ct);

        var appeals = await db.ModerationAppeals.AsNoTracking()
            .Where(a => a.AccountId == accountId)
            .OrderByDescending(a => a.CreatedAt)
            .Take(8)
            .Select(a => new CasePacketLine(
                a.Id.ToString(),
                "appeal",
                a.Kind,
                $"{a.Status}: {a.Body}",
                a.CreatedAt
            ))
            .ToListAsync(ct);

        var hits = await db.ChatKeywordHits.AsNoTracking()
            .Where(h => h.SenderAccountId == accountId)
            .OrderByDescending(h => h.CreatedAt)
            .Take(8)
            .Select(h => new CasePacketLine(
                h.Id.ToString(),
                "keyword",
                h.Keyword,
                $"{h.Status}: {h.MessageBody}",
                h.CreatedAt
            ))
            .ToListAsync(ct);

        var notes = await db.StaffCaseNotes.AsNoTracking()
            .Where(n => n.AccountId == accountId)
            .OrderByDescending(n => n.CreatedAt)
            .Take(8)
            .Select(n => new CasePacketLine(
                n.Id.ToString(),
                "note",
                n.StaffEmail,
                n.Body,
                n.CreatedAt
            ))
            .ToListAsync(ct);

        return new CasePacketResponse(
            accountId.ToString(),
            account.DisplayName,
            status,
            onWatch,
            openReports,
            openAppeals,
            openHits,
            matches,
            msgs,
            reports,
            appeals,
            hits,
            notes
        );
    }

    public async Task<LinkedAccountsResponse> LinkedAccountsAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        _ = await RequireMember(accountId, ct);
        var since = Now.AddDays(-90);
        var mine = await db.RefreshTokens.AsNoTracking()
            .Where(t => t.AccountId == accountId && t.CreatedAt >= since)
            .Select(t => new { t.DeviceId, t.IpAddress, t.CreatedAt })
            .ToListAsync(ct);

        var devices = mine
            .Select(x => x.DeviceId)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.Ordinal)
            .Cast<string>()
            .ToList();
        var ips = mine
            .Select(x => x.IpAddress)
            .Where(x => !string.IsNullOrWhiteSpace(x))
            .Distinct(StringComparer.Ordinal)
            .Cast<string>()
            .ToList();

        var items = new List<LinkedAccountItem>();
        if (devices.Count > 0)
        {
            var byDevice = await db.RefreshTokens.AsNoTracking()
                .Where(t =>
                    t.AccountId != accountId
                    && t.CreatedAt >= since
                    && t.DeviceId != null
                    && devices.Contains(t.DeviceId)
                )
                .GroupBy(t => new { t.AccountId, t.DeviceId })
                .Select(g => new
                {
                    g.Key.AccountId,
                    Value = g.Key.DeviceId!,
                    LastSeen = g.Max(x => x.CreatedAt),
                })
                .OrderByDescending(x => x.LastSeen)
                .Take(50)
                .ToListAsync(ct);
            var names = await Names(byDevice.Select(x => x.AccountId).Distinct().ToList(), ct);
            var accounts = await db.Accounts.IgnoreQueryFilters()
                .AsNoTracking()
                .Where(a => byDevice.Select(x => x.AccountId).Contains(a.Id))
                .ToDictionaryAsync(a => a.Id, ct);
            foreach (var row in byDevice)
            {
                accounts.TryGetValue(row.AccountId, out var a);
                var st =
                    a is null ? "unknown"
                    : a.DeletedAt != null ? "banned"
                    : a.SuspendedAt != null ? "suspended"
                    : a.ShadowBannedAt != null ? "shadowBanned"
                    : "active";
                items.Add(
                    new LinkedAccountItem(
                        row.AccountId.ToString(),
                        names.GetValueOrDefault(row.AccountId),
                        st,
                        "device",
                        row.Value,
                        row.LastSeen
                    )
                );
            }
        }

        if (ips.Count > 0)
        {
            var byIp = await db.RefreshTokens.AsNoTracking()
                .Where(t =>
                    t.AccountId != accountId
                    && t.CreatedAt >= since
                    && t.IpAddress != null
                    && ips.Contains(t.IpAddress)
                )
                .GroupBy(t => new { t.AccountId, t.IpAddress })
                .Select(g => new
                {
                    g.Key.AccountId,
                    Value = g.Key.IpAddress!,
                    LastSeen = g.Max(x => x.CreatedAt),
                })
                .OrderByDescending(x => x.LastSeen)
                .Take(50)
                .ToListAsync(ct);
            var names = await Names(byIp.Select(x => x.AccountId).Distinct().ToList(), ct);
            var accounts = await db.Accounts.IgnoreQueryFilters()
                .AsNoTracking()
                .Where(a => byIp.Select(x => x.AccountId).Contains(a.Id))
                .ToDictionaryAsync(a => a.Id, ct);
            foreach (var row in byIp)
            {
                var idStr = row.AccountId.ToString();
                accounts.TryGetValue(row.AccountId, out var a);
                var st =
                    a is null ? "unknown"
                    : a.DeletedAt != null ? "banned"
                    : a.SuspendedAt != null ? "suspended"
                    : a.ShadowBannedAt != null ? "shadowBanned"
                    : "active";
                items.Add(
                    new LinkedAccountItem(
                        idStr,
                        names.GetValueOrDefault(row.AccountId),
                        st,
                        "ip",
                        row.Value,
                        row.LastSeen
                    )
                );
            }
        }

        return new LinkedAccountsResponse(
            accountId.ToString(),
            devices,
            ips,
            items.OrderByDescending(i => i.LastSeenAt).Take(80).ToList()
        );
    }

    public async Task<AuthBlockListResponse> ListAuthBlocksAsync(
        bool? activeOnly,
        CancellationToken ct
    )
    {
        var query = db.AuthBlockEntries.AsNoTracking().AsQueryable();
        if (activeOnly == true)
        {
            query = query.Where(b => b.Active);
        }

        var rows = await query.OrderByDescending(b => b.CreatedAt).Take(200).ToListAsync(ct);
        return new AuthBlockListResponse(
            rows.Select(b => new AuthBlockItem(
                    b.Id.ToString(),
                    b.Kind,
                    b.Value,
                    b.Reason,
                    b.Active,
                    b.CreatedAt,
                    b.ClearedAt
                ))
                .ToList()
        );
    }

    public async Task<AuthBlockItem> AddAuthBlockAsync(
        AddAuthBlockRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var kind = (body.Kind ?? "").Trim().ToLowerInvariant();
        if (kind is not ("device" or "ip"))
        {
            throw new AuthException(400, "Invalid kind.", "Use device or ip.");
        }

        var value = (body.Value ?? "").Trim();
        if (value.Length is < 3 or > 128)
        {
            throw new AuthException(400, "Invalid value.", "Provide a device id or IP (3–128 chars).");
        }

        var existing = await db.AuthBlockEntries.FirstOrDefaultAsync(
            b => b.Kind == kind && b.Value == value && b.Active,
            ct
        );
        if (existing is not null)
        {
            existing.Reason = body.Reason?.Trim() ?? existing.Reason;
            await db.SaveChangesAsync(ct);
            return new AuthBlockItem(
                existing.Id.ToString(),
                existing.Kind,
                existing.Value,
                existing.Reason,
                existing.Active,
                existing.CreatedAt,
                existing.ClearedAt
            );
        }

        var row = new AuthBlockEntry
        {
            Id = Guid.NewGuid(),
            Kind = kind,
            Value = value,
            Reason = body.Reason?.Trim() ?? "",
            Active = true,
            CreatedAt = Now,
            CreatedByStaffId = staff.RequireStaffId(),
        };
        db.AuthBlockEntries.Add(row);
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "authBlock.add",
                TargetType = kind,
                TargetId = value,
                Detail = row.Reason,
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
        return new AuthBlockItem(
            row.Id.ToString(),
            row.Kind,
            row.Value,
            row.Reason,
            row.Active,
            row.CreatedAt,
            row.ClearedAt
        );
    }

    public async Task ClearAuthBlockAsync(Guid id, ClaimsPrincipal staff, CancellationToken ct)
    {
        StaffRoles.RequireSupportWrite(staff);
        var row = await db.AuthBlockEntries.FirstOrDefaultAsync(b => b.Id == id, ct)
            ?? throw new AuthException(404, "Block not found.", "That block entry is gone.");
        if (!row.Active) return;
        row.Active = false;
        row.ClearedAt = Now;
        row.ClearedByStaffId = staff.RequireStaffId();
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "authBlock.clear",
                TargetType = row.Kind,
                TargetId = row.Value,
                Detail = row.Reason,
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    async Task<Account> RequireMember(Guid accountId, CancellationToken ct)
    {
        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");
        if (AdminAccount.IsAdmin(account))
        {
            throw new AuthException(400, "Not allowed.", "Cannot moderate the admin ledger account.");
        }

        return account;
    }

    async Task<Dictionary<Guid, string?>> Names(List<Guid> ids, CancellationToken ct)
    {
        if (ids.Count == 0) return [];
        return await db.Accounts.IgnoreQueryFilters()
            .AsNoTracking()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);
    }
}
