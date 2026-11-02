using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Safety;

public interface ISafetyService
{
    Task<SafetyReportResponse> SubmitReportAsync(
        Guid reporterId,
        SubmitReportRequest body,
        CancellationToken ct
    );
}

public sealed class SafetyService(AppDbContext db, TimeProvider time) : ISafetyService
{
    DateTimeOffset Now => time.GetUtcNow();

    public async Task<SafetyReportResponse> SubmitReportAsync(
        Guid reporterId,
        SubmitReportRequest body,
        CancellationToken ct
    )
    {
        if (!Guid.TryParse(body.ReportedAccountId, out var reportedId))
        {
            throw new AuthException(400, "Invalid account.", "Pick a profile to report.");
        }

        if (reportedId == reporterId)
        {
            throw new AuthException(400, "Cannot report yourself.", "Choose someone else's profile.");
        }

        var category = body.Category?.Trim() ?? "";
        if (category.Length is < 2 or > 64)
        {
            throw new AuthException(400, "Category required.", "Choose a report reason.");
        }

        var reported = await db.Accounts.IgnoreQueryFilters()
            .FirstOrDefaultAsync(a => a.Id == reportedId, ct)
            ?? throw new AuthException(404, "User not found.", "That profile is gone.");

        if (AdminAccount.IsAdmin(reported))
        {
            throw new AuthException(400, "Cannot report system account.", "Pick a real member.");
        }

        var detail = (body.Details ?? "").Trim();
        if (detail.Length > 500) detail = detail[..500];

        var row = new ModerationReport
        {
            Id = Guid.NewGuid(),
            ReporterAccountId = reporterId,
            ReportedAccountId = reportedId,
            Reason = category,
            Detail = detail,
            Status = "open",
            CreatedAt = Now,
        };
        db.ModerationReports.Add(row);
        await db.SaveChangesAsync(ct);

        return new SafetyReportResponse(
            row.Id.ToString(),
            row.Reason,
            row.Detail,
            reported.DisplayName,
            row.ReportedAccountId.ToString(),
            row.CreatedAt
        );
    }
}
