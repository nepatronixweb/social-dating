using System.Security.Claims;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Ops;
using SocialDating.Api.Photos;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Admin;

public interface IAdminOpsService
{
    Task<AdminOpsOverviewResponse> LiveOverviewAsync(CancellationToken ct);
    Task<AdminMarketplaceHealthResponse> MarketplaceHealthAsync(CancellationToken ct);
    Task<AdminRuntimeConfigResponse> GetConfigAsync(CancellationToken ct);
    Task<AdminConfigHistoryResponse> ConfigHistoryAsync(CancellationToken ct);
    Task<AdminRuntimeConfigResponse> UpdateConfigAsync(
        UpdateRuntimeConfigRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<AdminPhotoQueueResponse> PhotoQueueAsync(string? filter, CancellationToken ct);
    Task SetPhotoHiddenAsync(
        Guid photoId,
        ModerationHideRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task ReviewPhotoAsync(
        Guid photoId,
        ReviewPhotoRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<BulkReviewPhotosResponse> BulkReviewPhotosAsync(
        BulkReviewPhotosRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<AdminMessageQueueResponse> MessageQueueAsync(string? q, CancellationToken ct);
    Task SetMessageHiddenAsync(
        Guid messageId,
        ModerationHideRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
}

public sealed class AdminOpsService(
    AppDbContext db,
    IWalletService wallet,
    IAppConfigService config,
    PhotoService photos,
    TimeProvider time
) : IAdminOpsService
{
    DateTimeOffset Now => time.GetUtcNow();

    public async Task<AdminOpsOverviewResponse> LiveOverviewAsync(CancellationToken ct)
    {
        var dayKey = NepalTime.DayKey(Now);
        var startUtc = Now.AddHours(-24);
        var cfg = await config.GetAsync(ct);
        var admin = await AdminAccount.EnsureAsync(db, Now, ct);
        await db.SaveChangesAsync(ct);

        var swipeAccountIds = await db.Swipes
            .Where(s => s.CreatedAt >= startUtc)
            .Select(s => s.FromAccountId)
            .Distinct()
            .ToListAsync(ct);
        var messageAccountIds = await db.Messages
            .Where(m => m.CreatedAt >= startUtc)
            .Select(m => m.SenderAccountId)
            .Distinct()
            .ToListAsync(ct);
        var activeToday = swipeAccountIds.Concat(messageAccountIds).Distinct().Count();

        var matchesToday = await db.Matches.CountAsync(m => m.CreatedAt >= startUtc, ct);
        var swipesToday = await db.Swipes.CountAsync(s => s.CreatedAt >= startUtc, ct);
        var messagesToday = await db.Messages.CountAsync(m => m.CreatedAt >= startUtc, ct);
        var paidActionsToday = await db.WalletEntries.CountAsync(
            e =>
                e.OccurredAt >= startUtc
                && e.Points < 0
                && (e.Kind == "swipeSpend" || e.Kind == "messageSpend" || e.Kind == "premiumAction"
                    || e.Kind.Contains("super") || e.Kind.Contains("rewind") || e.Kind.Contains("undo")),
            ct
        );
        // Broader paid action count via adminReceive credits today
        var paidViaAdmin = await db.WalletEntries.CountAsync(
            e => e.AccountId == admin.Id && e.OccurredAt >= startUtc && e.Kind == "adminReceive",
            ct
        );
        if (paidViaAdmin > paidActionsToday) paidActionsToday = paidViaAdmin;

        var openReports = await db.ModerationReports.CountAsync(
            r => r.Status == "open" || r.Status == "investigating",
            ct
        );
        var openWithdrawals = await db.WithdrawalRequests.CountAsync(w => w.Status == "recorded", ct);
        var pendingRefunds = await db.AdminRefundRequests.CountAsync(r => r.Status == "pending", ct);
        var hiddenPhotos = await db.Photos.CountAsync(p => p.HiddenAt != null, ct);
        var hiddenMessages = await db.Messages.CountAsync(m => m.HiddenAt != null, ct);
        var adminBalance = await wallet.SpendableAsync(admin.Id, ct);
        var premiumToday = await db.WalletEntries
            .Where(e => e.AccountId == admin.Id && e.OccurredAt >= startUtc && e.Points > 0)
            .SumAsync(e => (int?)e.Points, ct) ?? 0;

        var startOfUtcDay = Now.UtcDateTime.Date;
        var accountsToday = await db.Accounts.CountAsync(a => a.CreatedAt >= startOfUtcDay, ct);
        var totalAccounts = await db.Accounts.IgnoreQueryFilters().CountAsync(ct);

        var alerts = new List<string>();
        if (openReports >= 10) alerts.Add($"High open reports ({openReports}).");
        if (openWithdrawals >= 10) alerts.Add($"Withdrawal backlog ({openWithdrawals}).");
        if (pendingRefunds > 0) alerts.Add($"{pendingRefunds} refund(s) awaiting dual control.");
        if (cfg.KillDiscovery) alerts.Add("KILL: discovery is off.");
        if (cfg.KillWithdrawals) alerts.Add("KILL: withdrawals are off.");
        if (cfg.KillPremiumCharges) alerts.Add("KILL: premium charges are off.");
        if (cfg.KillReferrals) alerts.Add("KILL: referrals are off.");
        if (cfg.KillChatMessaging) alerts.Add("KILL: chat messaging is off.");

        return new AdminOpsOverviewResponse(
            totalAccounts,
            accountsToday,
            activeToday,
            matchesToday,
            swipesToday,
            messagesToday,
            paidActionsToday,
            openReports,
            openWithdrawals,
            pendingRefunds,
            hiddenPhotos,
            hiddenMessages,
            adminBalance,
            premiumToday,
            dayKey,
            alerts,
            new OpsKillSwitchSnapshot(
                cfg.KillWithdrawals,
                cfg.KillPremiumCharges,
                cfg.KillReferrals,
                cfg.KillDiscovery,
                cfg.KillChatMessaging
            )
        );
    }

    public async Task<AdminMarketplaceHealthResponse> MarketplaceHealthAsync(CancellationToken ct)
    {
        var dayKey = NepalTime.DayKey(Now);
        var startUtc = Now.AddHours(-24);

        var discoverableRows = await db.Accounts
            .Where(a =>
                a.AgeEligible == true
                && a.DisplayName != null
                && a.BirthDate != null
                && a.City != null
                && a.Gender != null
                && a.SuspendedAt == null
                && a.ShadowBannedAt == null
                && a.PhoneE164 != AdminAccount.PhoneE164)
            .Select(a => new { a.Gender, a.City })
            .ToListAsync(ct);

        int Count(string g) =>
            discoverableRows.Count(x => ProfileRules.CanonicalGender(x.Gender) == g);

        var male = Count("male");
        var female = Count("female");
        var lgbtq = Count("lgbtq");
        var other = Count("other");
        var total = discoverableRows.Count;
        var femaleShare = total == 0 ? 0 : (female + lgbtq + other) / (double)total;

        var cities = discoverableRows
            .GroupBy(x => (x.City ?? "").Trim(), StringComparer.OrdinalIgnoreCase)
            .Where(g => g.Key.Length > 0)
            .Select(g =>
            {
                int Cg(string gender) =>
                    g.Count(x => ProfileRules.CanonicalGender(x.Gender) == gender);
                return new CitySupplyRow(
                    g.Key,
                    g.Count(),
                    Cg("male"),
                    Cg("female"),
                    Cg("lgbtq"),
                    Cg("other")
                );
            })
            .OrderByDescending(c => c.Total)
            .Take(40)
            .ToList();

        var incompleteCandidates = await db.Accounts
            .Where(a =>
                a.SuspendedAt == null
                && a.PhoneE164 != AdminAccount.PhoneE164
                && (a.DisplayName == null || a.City == null || a.BirthDate == null))
            .Select(a => a.Gender)
            .ToListAsync(ct);
        var incompleteMale = incompleteCandidates.Count(ProfileRules.IsMale);

        var swipesToday = await db.Swipes.CountAsync(s => s.CreatedAt >= startUtc, ct);
        var likesToday = await db.Swipes.CountAsync(
            s => s.CreatedAt >= startUtc && (s.Direction == "right" || s.Direction == "super"),
            ct
        );
        var matchesToday = await db.Matches.CountAsync(m => m.CreatedAt >= startUtc, ct);

        var alerts = new List<string>();
        if (total > 0 && femaleShare < 0.25)
        {
            alerts.Add("Low non-male share among discoverable profiles — deck quality risk for male demand.");
        }

        if (male > 0 && female + lgbtq + other == 0)
        {
            alerts.Add("No discoverable female/LGBTQ+/other supply.");
        }

        var supplyNote = total == 0
            ? "No discoverable complete profiles yet."
            : $"Non-male share {(femaleShare * 100):0.0}% of discoverable supply.";

        return new AdminMarketplaceHealthResponse(
            dayKey,
            male,
            female,
            lgbtq,
            other,
            total,
            femaleShare,
            swipesToday,
            likesToday,
            matchesToday,
            incompleteMale,
            supplyNote,
            alerts,
            cities
        );
    }

    public async Task<AdminRuntimeConfigResponse> GetConfigAsync(CancellationToken ct)
    {
        var row = await config.GetAsync(ct);
        return ToConfig(row);
    }

    public async Task<AdminConfigHistoryResponse> ConfigHistoryAsync(CancellationToken ct)
    {
        var rows = await db.AppConfigRevisions
            .AsNoTracking()
            .OrderByDescending(r => r.CreatedAt)
            .Take(40)
            .ToListAsync(ct);
        return new AdminConfigHistoryResponse(
            rows.Select(r => new AdminConfigRevisionItem(
                    r.Id.ToString(),
                    r.SnapshotJson,
                    r.ChangedByEmail,
                    r.CreatedAt
                ))
                .ToList()
        );
    }

    public async Task<AdminRuntimeConfigResponse> UpdateConfigAsync(
        UpdateRuntimeConfigRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSuperadmin(staff);
        var row = await config.EnsureAsync(ct);
        var before = ToConfig(row);
        db.AppConfigRevisions.Add(
            new AppConfigRevision
            {
                Id = Guid.NewGuid(),
                SnapshotJson = JsonSerializer.Serialize(before),
                ChangedByEmail = staff.RequireStaffEmail(),
                CreatedAt = Now,
            }
        );

        if (body.PremiumActionPoints is int p && p is >= 1 and <= 100_000)
            row.PremiumActionPoints = p;
        if (body.ExtraSwipePoints is int e && e is >= 0 and <= 100_000)
            row.ExtraSwipePoints = e;
        if (body.DailyFreePointsMale is int d && d is >= 0 and <= 100_000)
            row.DailyFreePointsMale = d;
        if (body.FreeDailySwipesMale is int f && f is >= 0 and <= 1000)
            row.FreeDailySwipesMale = f;
        if (body.MinWithdrawalPoints is int m && m is >= 0 and <= 1_000_000)
            row.MinWithdrawalPoints = m;

        if (body.KillWithdrawals is bool kw) row.KillWithdrawals = kw;
        if (body.KillPremiumCharges is bool kp) row.KillPremiumCharges = kp;
        if (body.KillReferrals is bool kr) row.KillReferrals = kr;
        if (body.KillDiscovery is bool kd) row.KillDiscovery = kd;
        if (body.KillChatMessaging is bool kc) row.KillChatMessaging = kc;

        if (body.MaintenanceMode is bool mm) row.MaintenanceMode = mm;
        if (body.MinClientBuild is int mb && mb is >= 0 and <= 1_000_000_000)
            row.MinClientBuild = mb;
        if (body.BannerEnabled is bool be) row.BannerEnabled = be;
        if (body.BannerTitle is not null)
        {
            var t = body.BannerTitle.Trim();
            row.BannerTitle = t.Length == 0 ? null : (t.Length > 80 ? t[..80] : t);
        }
        if (body.BannerBody is not null)
        {
            var b = body.BannerBody.Trim();
            row.BannerBody = b.Length == 0 ? null : (b.Length > 300 ? b[..300] : b);
        }
        if (body.ChatKeywordList is not null)
        {
            var k = body.ChatKeywordList.Trim();
            row.ChatKeywordList = k.Length > 2000 ? k[..2000] : k;
        }

        row.UpdatedAt = Now;
        row.UpdatedByEmail = staff.RequireStaffEmail();

        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "ops.config",
                TargetType = "runtime",
                TargetId = row.Id.ToString(),
                Detail = "Updated pricing, kills, and/or client ops flags.",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
        return ToConfig(row);
    }

    public async Task<AdminPhotoQueueResponse> PhotoQueueAsync(string? filter, CancellationToken ct)
    {
        var f = (filter ?? "pending").Trim().ToLowerInvariant();
        var query = db.Photos.AsQueryable().Where(p => p.Kind == "profile");
        query = f switch
        {
            "hidden" => query.Where(p => p.HiddenAt != null),
            "approved" => query.Where(p => p.HiddenAt == null && p.ReviewStatus == "approved"),
            "rejected" => query.Where(p => p.ReviewStatus == "rejected"),
            "recent" => query.Where(p => p.HiddenAt == null),
            _ => query.Where(p => p.HiddenAt == null && p.ReviewStatus == "pending"),
        };

        var rows = await query.OrderByDescending(p => p.CreatedAt).Take(80).ToListAsync(ct);
        var ids = rows.Select(r => r.AccountId).Distinct().ToList();
        var names = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);

        return new AdminPhotoQueueResponse(
            rows.Select(p => new AdminPhotoQueueItem(
                    p.Id.ToString(),
                    p.AccountId.ToString(),
                    names.GetValueOrDefault(p.AccountId),
                    photos.SignedUrl(p.Id),
                    p.Kind,
                    p.HiddenAt is not null,
                    p.ReviewStatus,
                    p.ReviewReason,
                    p.CreatedAt
                ))
                .ToList()
        );
    }

    public async Task SetPhotoHiddenAsync(
        Guid photoId,
        ModerationHideRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var row = await db.Photos.FirstOrDefaultAsync(p => p.Id == photoId, ct)
            ?? throw new AuthException(404, "Photo not found.", "That photo is gone.");

        row.HiddenAt = body.Hidden ? Now : null;
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = body.Hidden ? "moderation.hidePhoto" : "moderation.showPhoto",
                TargetType = "photo",
                TargetId = photoId.ToString(),
                Detail = body.Note?.Trim() ?? "",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task ReviewPhotoAsync(
        Guid photoId,
        ReviewPhotoRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var status = (body.Status ?? "").Trim().ToLowerInvariant();
        if (status is not ("pending" or "approved" or "rejected"))
        {
            throw new AuthException(
                400,
                "Check your details.",
                "Status must be pending, approved, or rejected."
            );
        }

        var reason = (body.Reason ?? "").Trim().ToLowerInvariant();
        if (status == "rejected")
        {
            if (reason is not ("nudity" or "fake" or "underage" or "spam" or "other"))
            {
                throw new AuthException(
                    400,
                    "Check your details.",
                    "Rejected photos need reason: nudity, fake, underage, spam, or other."
                );
            }
        }
        else
        {
            reason = "";
        }

        var row = await db.Photos.FirstOrDefaultAsync(p => p.Id == photoId, ct)
            ?? throw new AuthException(404, "Photo not found.", "That photo is gone.");

        row.ReviewStatus = status;
        row.ReviewReason = string.IsNullOrEmpty(reason) ? null : reason;
        row.ReviewedAt = Now;
        row.ReviewedByEmail = staff.RequireStaffEmail();
        if (status == "rejected")
        {
            row.HiddenAt ??= Now;
        }
        else if (status == "approved")
        {
            row.HiddenAt = null;
        }

        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "moderation.reviewPhoto",
                TargetType = "photo",
                TargetId = photoId.ToString(),
                Detail =
                    $"{status}"
                    + (string.IsNullOrEmpty(reason) ? "" : $"/{reason}")
                    + (string.IsNullOrWhiteSpace(body.Note) ? "" : $" — {body.Note.Trim()}"),
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<BulkReviewPhotosResponse> BulkReviewPhotosAsync(
        BulkReviewPhotosRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var status = (body.Status ?? "").Trim().ToLowerInvariant();
        if (status is not ("approved" or "rejected"))
        {
            throw new AuthException(
                400,
                "Check your details.",
                "Bulk review status must be approved or rejected."
            );
        }

        var reason = (body.Reason ?? "").Trim().ToLowerInvariant();
        if (status == "rejected"
            && reason is not ("nudity" or "fake" or "underage" or "spam" or "other"))
        {
            throw new AuthException(
                400,
                "Check your details.",
                "Rejected photos need reason: nudity, fake, underage, spam, or other."
            );
        }
        if (status != "rejected") reason = "";

        var ids = (body.Ids ?? [])
            .Select(raw => Guid.TryParse(raw, out var id) ? id : (Guid?)null)
            .Where(id => id is not null)
            .Select(id => id!.Value)
            .Distinct()
            .Take(100)
            .ToList();

        if (ids.Count == 0)
        {
            throw new AuthException(400, "Nothing selected.", "Pick at least one photo id.");
        }

        var rows = await db.Photos.Where(p => ids.Contains(p.Id)).ToListAsync(ct);
        var found = rows.Select(r => r.Id).ToHashSet();
        var skipped = ids.Where(id => !found.Contains(id)).Select(id => id.ToString()).ToList();
        var email = staff.RequireStaffEmail();
        var note = string.IsNullOrWhiteSpace(body.Note) ? "" : body.Note.Trim();

        foreach (var row in rows)
        {
            row.ReviewStatus = status;
            row.ReviewReason = string.IsNullOrEmpty(reason) ? null : reason;
            row.ReviewedAt = Now;
            row.ReviewedByEmail = email;
            if (status == "rejected") row.HiddenAt ??= Now;
            else row.HiddenAt = null;

            db.AdminAuditEvents.Add(
                new AdminAuditEvent
                {
                    Id = Guid.NewGuid(),
                    StaffUserId = staff.RequireStaffId(),
                    StaffEmail = email,
                    Action = "moderation.reviewPhotoBulk",
                    TargetType = "photo",
                    TargetId = row.Id.ToString(),
                    Detail =
                        $"{status}"
                        + (string.IsNullOrEmpty(reason) ? "" : $"/{reason}")
                        + (note.Length == 0 ? "" : $" — {note}"),
                    CreatedAt = Now,
                }
            );
        }

        await db.SaveChangesAsync(ct);
        return new BulkReviewPhotosResponse(
            rows.Count,
            skipped,
            $"Updated {rows.Count} photo(s) to {status}."
        );
    }

    public async Task<AdminMessageQueueResponse> MessageQueueAsync(string? q, CancellationToken ct)
    {
        var query = db.Messages.AsQueryable();
        if (!string.IsNullOrWhiteSpace(q))
        {
            var term = q.Trim().ToLowerInvariant();
            query = query.Where(m => m.Body.ToLower().Contains(term));
        }

        var rows = await query.OrderByDescending(m => m.CreatedAt).Take(80).ToListAsync(ct);
        var ids = rows.Select(r => r.SenderAccountId).Distinct().ToList();
        var names = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);

        return new AdminMessageQueueResponse(
            rows.Select(m => new AdminMessageQueueItem(
                    m.Id.ToString(),
                    m.MatchId.ToString(),
                    m.SenderAccountId.ToString(),
                    names.GetValueOrDefault(m.SenderAccountId),
                    m.Body,
                    m.HiddenAt is not null,
                    m.CreatedAt
                ))
                .ToList()
        );
    }

    public async Task SetMessageHiddenAsync(
        Guid messageId,
        ModerationHideRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var row = await db.Messages.FirstOrDefaultAsync(m => m.Id == messageId, ct)
            ?? throw new AuthException(404, "Message not found.", "That message is gone.");

        row.HiddenAt = body.Hidden ? Now : null;
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = body.Hidden ? "moderation.hideMessage" : "moderation.showMessage",
                TargetType = "message",
                TargetId = messageId.ToString(),
                Detail = body.Note?.Trim() ?? "",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    static AdminRuntimeConfigResponse ToConfig(AppRuntimeSettings row) =>
        new(
            row.PremiumActionPoints,
            row.ExtraSwipePoints,
            row.DailyFreePointsMale,
            row.FreeDailySwipesMale,
            row.MinWithdrawalPoints,
            row.KillWithdrawals,
            row.KillPremiumCharges,
            row.KillReferrals,
            row.KillDiscovery,
            row.KillChatMessaging,
            row.MaintenanceMode,
            row.MinClientBuild,
            row.BannerEnabled,
            row.BannerTitle,
            row.BannerBody,
            row.ChatKeywordList ?? "",
            row.UpdatedAt,
            row.UpdatedByEmail
        );
}
