using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Data;

namespace SocialDating.Api.Admin;

public static class AdminEndpoints
{
    public static void MapAdminEndpoints(this WebApplication app)
    {
        var admin = app.MapGroup("/v1/admin").WithTags("Admin");

        admin.MapPost("/auth/login", Login).AllowAnonymous();

        // Reads — any staff role
        var read = admin.MapGroup("").RequireAuthorization(StaffClaims.PolicyName);
        read.MapGet("/me", Me);
        read.MapGet("/users", ListUsers);
        read.MapGet("/users/{id:guid}", GetUser);
        read.MapGet("/ledger/admin", AdminLedger);
        read.MapGet("/withdrawals", ListWithdrawals);
        read.MapGet("/withdrawals/export.csv", ExportWithdrawals);
        read.MapGet("/refunds", ListRefunds);
        read.MapGet("/referrals/invites", ListReferralInvites);
        read.MapGet("/referrals/commissions", ListReferralCommissions);
        read.MapGet("/grants/daily-free", DailyFreeGrants);
        read.MapGet("/subscriptions/overview", SubscriptionOverview);
        read.MapGet("/reports", ListReports);
        read.MapGet("/users/export.csv", ExportUsers);
        read.MapGet("/audit", ListAudit);
        read.MapGet("/audit/export.csv", ExportAudit);
        read.MapGet("/staff", ListStaff);

        // Support / trust / superadmin — moderation + light help
        var support = admin.MapGroup("").RequireAuthorization(StaffClaims.SupportWritePolicy);
        support.MapPost("/users/{id:guid}/warn", WarnUser);
        support.MapPost("/users/{id:guid}/reset-swipe-day", ResetSwipeDay);
        support.MapPost("/users/{id:guid}/force-logout", ForceLogout);
        support.MapPost("/reports/{id:guid}/claim", ClaimReport);
        support.MapPost("/reports/{id:guid}/unclaim", UnclaimReport);
        support.MapPost("/reports/{id:guid}/resolve", ResolveReport);

        // Finance / superadmin — money
        var finance = admin.MapGroup("").RequireAuthorization(StaffClaims.FinanceWritePolicy);
        finance.MapPost("/users/{id:guid}/refund-charge", RefundCharge);
        finance.MapPost("/users/{id:guid}/adjust-points", AdjustPoints);
        finance.MapPost("/users/{id:guid}/complimentary-premium", SetComplimentary);
        finance.MapPost("/withdrawals/{id:guid}/resolve", ResolveWithdrawal);
        finance.MapPost("/refunds/{id:guid}/resolve", ResolveRefund);
        finance.MapPost("/referrals/commissions/{id:guid}/clawback", ClawbackCommission);

        // Superadmin only — destructive moderation + staff management
        var super = admin.MapGroup("").RequireAuthorization(StaffClaims.SuperadminPolicy);
        super.MapPost("/users/{id:guid}/ban", BanUser);
        super.MapPost("/users/{id:guid}/unban", UnbanUser);
        super.MapPost("/users/{id:guid}/suspend", SuspendUser);
        super.MapPost("/users/{id:guid}/unsuspend", UnsuspendUser);
        super.MapPost("/users/{id:guid}/clear-photos", ClearPhotos);
        super.MapPost("/users/{id:guid}/unmatch-all", UnmatchAll);
        super.MapPost("/staff", CreateStaff);
        super.MapPost("/staff/{id:guid}/reset-password", ResetStaffPassword);
        super.MapPost("/staff/{id:guid}/disable", DisableStaff);
        super.MapPost("/staff/{id:guid}/enable", EnableStaff);
        super.MapPost("/staff/{id:guid}/role", SetStaffRole);
        super.MapPost("/staff/{id:guid}/revoke-sessions", RevokeStaffSessions);

        AdminOpsEndpoints.MapAdminOpsEndpoints(read, support, super);
        AdminTrustEndpoints.MapAdminTrustEndpoints(read, support);
        AdminDeskEndpoints.MapAdminDeskEndpoints(read, finance);
        AdminGrowthEndpoints.MapAdminGrowthEndpoints(read, support, finance);
        AdminComplianceEndpoints.MapAdminComplianceEndpoints(read, super);
        AdminAppealEndpoints.MapAdminAppealEndpoints(read, support);
    }

    static async Task<IResult> Login(
        StaffLoginRequest body,
        IAdminAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.LoginAsync(body, ct));

    static async Task<IResult> Me(
        ClaimsPrincipal user,
        AppDbContext db,
        CancellationToken ct
    )
    {
        var id = user.RequireStaffId();
        var staff = await db.StaffUsers.FirstOrDefaultAsync(s => s.Id == id, ct);
        return Results.Ok(
            new StaffProfileResponse(
                id.ToString(),
                user.RequireStaffEmail(),
                staff?.DisplayName ?? user.RequireStaffEmail(),
                user.RequireStaffRole()
            )
        );
    }

    static async Task<IResult> ListUsers(
        IAdminService admin,
        string? q,
        string? gender,
        string? status,
        string? city,
        bool? incomplete,
        int? take,
        CancellationToken ct
    ) =>
        Results.Ok(
            await admin.ListUsersAsync(q, gender, status, city, incomplete, take ?? 50, ct)
        );

    static async Task<IResult> GetUser(Guid id, IAdminService admin, CancellationToken ct) =>
        Results.Ok(await admin.GetUserAsync(id, ct));

    static async Task<IResult> BanUser(
        Guid id,
        BanUserRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.BanUserAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> UnbanUser(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.UnbanUserAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> SuspendUser(
        Guid id,
        SuspendUserRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.SuspendUserAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> UnsuspendUser(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.UnsuspendUserAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> WarnUser(
        Guid id,
        WarnUserRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.WarnUserAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> ClearPhotos(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.ClearPhotosAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> UnmatchAll(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.UnmatchAllAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> ResetSwipeDay(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.ResetSwipeDayAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> ForceLogout(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    ) => Results.Ok(await admin.ForceLogoutAsync(id, http.User, ct));

    static async Task<IResult> RefundCharge(
        Guid id,
        RefundChargeRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    ) => Results.Ok(await admin.RefundChargeAsync(id, body, http.User, ct));

    static async Task<IResult> SetComplimentary(
        Guid id,
        ComplimentaryPremiumRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.SetComplimentaryAsync(id, body.Enabled, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> AdjustPoints(
        Guid id,
        AdjustPointsRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.AdjustPointsAsync(id, body, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> AdminLedger(
        IAdminService admin,
        int? take,
        CancellationToken ct
    ) => Results.Ok(await admin.AdminLedgerAsync(take ?? 50, ct));

    static async Task<IResult> ListWithdrawals(
        IAdminService admin,
        string? status,
        CancellationToken ct
    ) => Results.Ok(await admin.ListWithdrawalsAsync(status, ct));

    static async Task<IResult> ExportWithdrawals(
        IAdminService admin,
        string? status,
        CancellationToken ct
    )
    {
        var csv = await admin.WithdrawalsCsvAsync(status, ct);
        return Results.Text(csv, "text/csv", System.Text.Encoding.UTF8);
    }

    static async Task<IResult> ResolveWithdrawal(
        Guid id,
        ResolveWithdrawalRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    ) => Results.Ok(await admin.ResolveWithdrawalAsync(id, body, http.User, ct));

    static async Task<IResult> ListRefunds(
        IAdminService admin,
        string? status,
        CancellationToken ct
    ) => Results.Ok(await admin.ListRefundsAsync(status, ct));

    static async Task<IResult> ResolveRefund(
        Guid id,
        ResolveRefundRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    ) => Results.Ok(await admin.ResolveRefundAsync(id, body, http.User, ct));

    static async Task<IResult> ListReferralInvites(IAdminService admin, CancellationToken ct) =>
        Results.Ok(await admin.ListReferralInvitesAsync(ct));

    static async Task<IResult> ListReferralCommissions(
        IAdminService admin,
        string? status,
        CancellationToken ct
    ) => Results.Ok(await admin.ListReferralCommissionsAsync(status, ct));

    static async Task<IResult> ClawbackCommission(
        Guid id,
        ClawbackCommissionRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    )
    {
        await admin.ClawbackCommissionAsync(id, body.Note, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> DailyFreeGrants(
        IAdminService admin,
        string? dayKey,
        CancellationToken ct
    ) => Results.Ok(await admin.DailyFreeGrantsAsync(dayKey, ct));

    static async Task<IResult> SubscriptionOverview(IAdminService admin, CancellationToken ct) =>
        Results.Ok(await admin.SubscriptionOverviewAsync(ct));

    static async Task<IResult> ListReports(
        IAdminService admin,
        HttpContext http,
        string? status,
        string? sla,
        string? claim,
        CancellationToken ct
    )
    {
        Guid? staffId = null;
        try
        {
            staffId = http.User.RequireStaffId();
        }
        catch
        {
            // Policy already requires staff; ignore parse edge.
        }

        return Results.Ok(await admin.ListReportsAsync(status, sla, claim, staffId, ct));
    }

    static async Task<IResult> ClaimReport(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    ) => Results.Ok(await admin.ClaimReportAsync(id, http.User, ct));

    static async Task<IResult> UnclaimReport(
        Guid id,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    ) => Results.Ok(await admin.UnclaimReportAsync(id, http.User, ct));

    static async Task<IResult> ResolveReport(
        Guid id,
        ResolveReportRequest body,
        HttpContext http,
        IAdminService admin,
        CancellationToken ct
    ) => Results.Ok(await admin.ResolveReportAsync(id, body, http.User, ct));

    static async Task<IResult> ExportUsers(
        IAdminService admin,
        string? q,
        string? gender,
        string? status,
        string? city,
        bool? incomplete,
        int? take,
        CancellationToken ct
    )
    {
        var csv = await admin.UsersCsvAsync(q, gender, status, city, incomplete, take ?? 500, ct);
        return Results.File(
            System.Text.Encoding.UTF8.GetBytes(csv),
            "text/csv",
            "users.csv"
        );
    }

    static async Task<IResult> ListAudit(
        IAdminService admin,
        string? q,
        string? action,
        string? staffEmail,
        int? take,
        CancellationToken ct
    ) => Results.Ok(await admin.ListAuditAsync(q, action, staffEmail, take ?? 80, ct));

    static async Task<IResult> ExportAudit(
        IAdminService admin,
        string? q,
        string? action,
        string? staffEmail,
        int? take,
        CancellationToken ct
    )
    {
        var csv = await admin.AuditCsvAsync(q, action, staffEmail, take ?? 500, ct);
        return Results.Text(csv, "text/csv");
    }

    static async Task<IResult> ListStaff(IAdminAuthService auth, CancellationToken ct) =>
        Results.Ok(await auth.ListStaffAsync(ct));

    static async Task<IResult> CreateStaff(
        CreateStaffRequest body,
        HttpContext http,
        IAdminAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.CreateStaffAsync(body, http.User, ct));

    static async Task<IResult> ResetStaffPassword(
        Guid id,
        ResetStaffPasswordRequest body,
        HttpContext http,
        IAdminAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.ResetPasswordAsync(id, body, http.User, ct));

    static async Task<IResult> DisableStaff(
        Guid id,
        HttpContext http,
        IAdminAuthService auth,
        CancellationToken ct
    )
    {
        await auth.SetDisabledAsync(id, true, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> EnableStaff(
        Guid id,
        HttpContext http,
        IAdminAuthService auth,
        CancellationToken ct
    )
    {
        await auth.SetDisabledAsync(id, false, http.User, ct);
        return Results.Ok(new { ok = true });
    }

    static async Task<IResult> SetStaffRole(
        Guid id,
        SetStaffRoleRequest body,
        HttpContext http,
        IAdminAuthService auth,
        CancellationToken ct
    ) => Results.Ok(await auth.SetRoleAsync(id, body, http.User, ct));

    static async Task<IResult> RevokeStaffSessions(
        Guid id,
        HttpContext http,
        IAdminAuthService auth,
        CancellationToken ct
    )
    {
        await auth.RevokeSessionsAsync(id, http.User, ct);
        return Results.Ok(new { ok = true });
    }
}
