using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Inbox;
using SocialDating.Api.Ops;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Admin;

public interface IAdminAppealService
{
    Task<AdminAppealListResponse> ListAsync(string? status, string? sla, CancellationToken ct);

    Task<AdminAppealItem> CreateForUserAsync(
        Guid accountId,
        CreateAppealRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );

    Task<AdminAppealItem> CreateMineAsync(
        Guid accountId,
        CreateAppealRequest body,
        CancellationToken ct
    );

    Task<AdminAppealItem> ResolveAsync(
        Guid id,
        ResolveAppealRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );

    Task<ClientAppConfigResponse> ClientConfigAsync(CancellationToken ct);
}

public sealed class AdminAppealService(
    AppDbContext db,
    IAdminService admin,
    IAdminTrustService trust,
    IAppConfigService config,
    IInboxService inbox,
    IOptions<AdminOptions> options,
    TimeProvider time
) : IAdminAppealService
{
    DateTimeOffset Now => time.GetUtcNow();
    int AppealSlaHours => Math.Max(1, options.Value.AppealSlaHours);

    public async Task<ClientAppConfigResponse> ClientConfigAsync(CancellationToken ct)
    {
        var row = await config.GetAsync(ct);
        return new ClientAppConfigResponse(
            row.MaintenanceMode,
            row.MinClientBuild,
            row.BannerEnabled,
            row.BannerTitle,
            row.BannerBody,
            row.UpdatedAt
        );
    }

    public async Task<AdminAppealListResponse> ListAsync(
        string? status,
        string? sla,
        CancellationToken ct
    )
    {
        var query = db.ModerationAppeals.AsQueryable();
        if (!string.IsNullOrWhiteSpace(status))
        {
            var s = status.Trim().ToLowerInvariant();
            query = query.Where(a => a.Status == s);
        }

        var rows = await query.OrderByDescending(a => a.CreatedAt).Take(200).ToListAsync(ct);
        var ids = rows.Select(r => r.AccountId).Distinct().ToList();
        var names = await db.Accounts.IgnoreQueryFilters()
            .Where(a => ids.Contains(a.Id))
            .ToDictionaryAsync(a => a.Id, a => a.DisplayName, ct);

        var items = rows.Select(r => ToItem(r, names.GetValueOrDefault(r.AccountId))).ToList();
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

        return new AdminAppealListResponse(items);
    }

    public async Task<AdminAppealItem> CreateForUserAsync(
        Guid accountId,
        CreateAppealRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "User not found.", "No account matches that id.");

        if (AdminAccount.IsAdminPhone(account.PhoneE164))
        {
            throw new AuthException(400, "System account.", "Cannot file an appeal for the admin ledger.");
        }

        var kind = ResolveKind(account, body.Kind);
        var text = RequireBody(body.Body);
        await EnsureNoOpenAsync(accountId, ct);

        var row = new ModerationAppeal
        {
            Id = Guid.NewGuid(),
            AccountId = accountId,
            Kind = kind,
            Body = text,
            Status = "open",
            CreatedAt = Now,
            FiledBy = "staff",
        };
        db.ModerationAppeals.Add(row);
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "appeal.create",
                TargetType = "appeal",
                TargetId = row.Id.ToString(),
                Detail = $"{kind}: {text}",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
        return ToItem(row, account.DisplayName);
    }

    public async Task<AdminAppealItem> CreateMineAsync(
        Guid accountId,
        CreateAppealRequest body,
        CancellationToken ct
    )
    {
        var account = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(404, "Account not found.", "Sign in again.");

        if (account.DeletedAt is null
            && account.SuspendedAt is null
            && account.ShadowBannedAt is null)
        {
            throw new AuthException(
                400,
                "Nothing to appeal.",
                "Appeals are only for suspended, shadow-banned, or banned accounts."
            );
        }

        // Banned accounts (DeletedAt) may still hold a JWT until refresh — allow appeal.
        var kind = ResolveKind(account, body.Kind);
        var text = RequireBody(body.Body);
        await EnsureNoOpenAsync(accountId, ct);

        var row = new ModerationAppeal
        {
            Id = Guid.NewGuid(),
            AccountId = accountId,
            Kind = kind,
            Body = text,
            Status = "open",
            CreatedAt = Now,
            FiledBy = "user",
        };
        db.ModerationAppeals.Add(row);
        await db.SaveChangesAsync(ct);
        return ToItem(row, account.DisplayName);
    }

    public async Task<AdminAppealItem> ResolveAsync(
        Guid id,
        ResolveAppealRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var decision = body.Decision?.Trim().ToLowerInvariant() ?? "";
        if (decision is not ("accept" or "reject"))
        {
            throw new AuthException(400, "Invalid decision.", "Use accept or reject.");
        }

        var row = await db.ModerationAppeals.FirstOrDefaultAsync(a => a.Id == id, ct)
            ?? throw new AuthException(404, "Appeal not found.", "That appeal is gone.");

        if (row.Status != "open")
        {
            throw new AuthException(400, "Already resolved.", "This appeal is closed.");
        }

        row.Status = decision == "accept" ? "accepted" : "rejected";
        row.ResolvedAt = Now;
        row.ResolvedByStaffId = staff.RequireStaffId();
        row.ResolutionNote = body.Note?.Trim() ?? "";

        if (decision == "accept")
        {
            if (row.Kind == "ban")
            {
                StaffRoles.RequireSuperadmin(staff);
            }
            await LiftRestrictionAsync(row.AccountId, row.Kind, staff, ct);
        }

        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = decision == "accept" ? "appeal.accept" : "appeal.reject",
                TargetType = "appeal",
                TargetId = row.Id.ToString(),
                Detail = row.ResolutionNote,
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);

        var note = string.IsNullOrWhiteSpace(row.ResolutionNote)
            ? ""
            : $" {row.ResolutionNote}";
        await inbox.NotifySystemAsync(
            row.AccountId,
            decision == "accept" ? "Appeal accepted" : "Appeal rejected",
            decision == "accept"
                ? $"Your {row.Kind} appeal was accepted and the restriction was lifted.{note}"
                : $"Your {row.Kind} appeal was reviewed and not accepted.{note}",
            ct
        );

        var name = await db.Accounts.IgnoreQueryFilters()
            .Where(a => a.Id == row.AccountId)
            .Select(a => a.DisplayName)
            .FirstOrDefaultAsync(ct);
        return ToItem(row, name);
    }

    async Task LiftRestrictionAsync(
        Guid accountId,
        string kind,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        switch (kind)
        {
            case "ban":
                await admin.UnbanUserAsync(accountId, staff, ct);
                break;
            case "suspend":
                await admin.UnsuspendUserAsync(accountId, staff, ct);
                break;
            case "shadowBan":
                await trust.UnshadowBanAsync(accountId, staff, ct);
                break;
        }
    }

    async Task EnsureNoOpenAsync(Guid accountId, CancellationToken ct)
    {
        var open = await db.ModerationAppeals.AnyAsync(
            a => a.AccountId == accountId && a.Status == "open",
            ct
        );
        if (open)
        {
            throw new AuthException(
                409,
                "Appeal already open.",
                "Resolve or wait for the existing appeal first."
            );
        }
    }

    static string RequireBody(string? body)
    {
        var text = body?.Trim() ?? "";
        if (text.Length < 8)
        {
            throw new AuthException(
                400,
                "Explain your appeal.",
                "Write at least a short reason (8+ characters)."
            );
        }
        if (text.Length > 1000) text = text[..1000];
        return text;
    }

    static string ResolveKind(Account account, string? requested)
    {
        var req = requested?.Trim();
        if (!string.IsNullOrEmpty(req))
        {
            var n = req.ToLowerInvariant() switch
            {
                "ban" or "banned" => "ban",
                "suspend" or "suspended" => "suspend",
                "shadow" or "shadowban" or "shadow_ban" or "shadowbanned" => "shadowBan",
                _ => null,
            };
            if (n is not null) return n;
        }

        if (account.DeletedAt is not null) return "ban";
        if (account.SuspendedAt is not null) return "suspend";
        if (account.ShadowBannedAt is not null) return "shadowBan";
        return "suspend";
    }

    AdminAppealItem ToItem(ModerationAppeal r, string? name)
    {
        var open = r.Status == "open";
        var due = r.CreatedAt.AddHours(AppealSlaHours);
        var ageHours = Math.Round((Now - r.CreatedAt).TotalHours, 1);
        var warnAt = AppealSlaHours * 0.75;
        string state;
        if (!open) state = "closed";
        else if (Now >= due) state = "overdue";
        else if (ageHours >= warnAt) state = "due_soon";
        else state = "ok";

        return new AdminAppealItem(
            r.Id.ToString(),
            r.AccountId.ToString(),
            name,
            r.Kind,
            r.Body,
            r.Status,
            r.FiledBy,
            r.CreatedAt,
            r.ResolvedAt,
            open ? due : null,
            state,
            ageHours
        );
    }
}
