using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Ops;

namespace SocialDating.Api.Wallet;

public interface IWalletService
{
    Task<PointBalanceResponse> FetchSummaryAsync(Guid accountId, CancellationToken ct);
    Task<WalletTransactionListResponse> FetchTransactionsAsync(Guid accountId, CancellationToken ct);
    Task<WalletTransactionResponse> FetchTransactionAsync(Guid accountId, Guid id, CancellationToken ct);
    Task<WithdrawalEligibilityResponse> FetchEligibilityAsync(Guid accountId, CancellationToken ct);
    Task<WithdrawalListResponse> FetchWithdrawalsAsync(Guid accountId, CancellationToken ct);
    Task<WithdrawalRequestResponse> FetchWithdrawalAsync(Guid accountId, Guid id, CancellationToken ct);
    Task<WithdrawalRequestResponse> SubmitWithdrawalAsync(
        Guid accountId,
        SubmitWithdrawalRequest body,
        CancellationToken ct
    );
    Task<WithdrawalRequestResponse> CancelWithdrawalAsync(Guid accountId, Guid id, CancellationToken ct);
    Task EnsureWelcomeAsync(Account account, CancellationToken ct);
    Task EnsureDailyFreePointsAsync(Account account, CancellationToken ct);
    Task CreditEarnedAsync(
        Guid accountId,
        int points,
        string kind,
        string title,
        string detail,
        string sourceId,
        CancellationToken ct
    );
    Task<int> SpendableAsync(Guid accountId, CancellationToken ct);
    Task<ChargeResult> TryChargeAsync(
        Account account,
        int costPaisa,
        string kind,
        string title,
        string detail,
        string sourceId,
        CancellationToken ct
    );
    /// <summary>Debits the payer and credits the admin ledger for the same amount.</summary>
    Task<ChargeResult> ChargeToAdminAsync(
        Account account,
        int costPaisa,
        string kind,
        string title,
        string detail,
        string sourceId,
        CancellationToken ct
    );
    Task RefundAsync(Guid accountId, string sourceId, CancellationToken ct);
}

public readonly record struct ChargeResult(bool Ok, int ChargedPaisa, int BalancePaisa);

public sealed class WalletService(AppDbContext db, TimeProvider time, IAppConfigService? appConfig = null)
    : IWalletService
{
    public const int WelcomeBonusPoints = 1000;
    /// <summary>Daily promotional grant for males without a paid subscription.</summary>
    public const int DailyFreePointsMale = 100;
    public const int PremiumActionPricePoints = 100;
    public const int MinWithdrawalPoints = 500;
    public const int WithdrawalFeePoints = 0;

    DateTimeOffset Now => time.GetUtcNow();

    public async Task<PointBalanceResponse> FetchSummaryAsync(Guid accountId, CancellationToken ct)
    {
        var account = await RequireAccount(accountId, ct);
        await EnsureWelcomeAsync(account, ct);
        await EnsureDailyFreePointsAsync(account, ct);
        await db.SaveChangesAsync(ct);
        var (promo, earned) = await BalancesAsync(accountId, ct);
        var pending = await PendingPointsAsync(accountId, ct);
        return new PointBalanceResponse(promo, earned, pending);
    }

    public async Task<WalletTransactionListResponse> FetchTransactionsAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        await EnsureWelcomeAsync(account, ct);
        await db.SaveChangesAsync(ct);
        var rows = (await db.WalletEntries
            .Where(e => e.AccountId == accountId)
            .ToListAsync(ct))
            .OrderByDescending(e => e.OccurredAt)
            .ThenByDescending(e => e.Id)
            .Select(ToResponse)
            .ToList();
        return new WalletTransactionListResponse(rows);
    }

    public async Task<WalletTransactionResponse> FetchTransactionAsync(
        Guid accountId,
        Guid id,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        var row = await db.WalletEntries.FirstOrDefaultAsync(
            e => e.Id == id && e.AccountId == accountId,
            ct
        );
        if (row is null)
        {
            throw new AuthException(404, "That activity is gone.", "That wallet record is no longer available.");
        }

        return ToResponse(row);
    }

    public async Task<WithdrawalEligibilityResponse> FetchEligibilityAsync(
        Guid accountId,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        await EnsureWelcomeAsync(account, ct);
        await db.SaveChangesAsync(ct);
        return await EligibilityFor(account, ct);
    }

    public async Task<WithdrawalListResponse> FetchWithdrawalsAsync(Guid accountId, CancellationToken ct)
    {
        await RequireAccount(accountId, ct);
        var rows = (await db.WithdrawalRequests
            .Where(w => w.AccountId == accountId)
            .ToListAsync(ct))
            .OrderByDescending(w => w.CreatedAt)
            .ThenByDescending(w => w.Id)
            .Select(ToWithdrawal)
            .ToList();
        return new WithdrawalListResponse(rows);
    }

    public async Task<WithdrawalRequestResponse> FetchWithdrawalAsync(
        Guid accountId,
        Guid id,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        var row = await db.WithdrawalRequests.FirstOrDefaultAsync(
            w => w.Id == id && w.AccountId == accountId,
            ct
        );
        if (row is null)
        {
            throw new AuthException(404, "That request is gone.", "That withdrawal record is no longer available.");
        }

        return ToWithdrawal(row);
    }

    public async Task<WithdrawalRequestResponse> SubmitWithdrawalAsync(
        Guid accountId,
        SubmitWithdrawalRequest body,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        await EnsureWelcomeAsync(account, ct);
        if (appConfig is not null)
        {
            var cfg = await appConfig.GetAsync(ct);
            if (cfg.KillWithdrawals)
            {
                throw new AuthException(
                    503,
                    "Withdrawals paused.",
                    "Withdrawals are temporarily unavailable."
                );
            }
        }

        if (!body.Confirmed)
        {
            throw new AuthException(
                400,
                "Confirm first.",
                "Confirm that this request will not be paid before recording it."
            );
        }

        var eligibility = await EligibilityFor(account, ct);
        if (!eligibility.EligibleAccount)
        {
            throw new AuthException(400, "Not available.", eligibility.Explanation);
        }

        var minPoints = eligibility.MinimumPoints;
        if (body.Points < minPoints)
        {
            throw new AuthException(
                400,
                "Below the minimum.",
                $"The configured minimum is {minPoints} earned points. Promotional points do not count."
            );
        }

        if (body.Points > eligibility.EarnedAvailable)
        {
            throw new AuthException(
                400,
                "Not enough earned points.",
                "There are not enough earned, withdrawable points for this request. Promotional points cannot be used."
            );
        }

        if (await HasOpenRequest(accountId, ct))
        {
            throw new AuthException(
                400,
                "Already recorded.",
                "A withdrawal request is already recorded. Cancel it before recording another. Nothing has been sent to a bank."
            );
        }

        var request = new Data.WithdrawalRequest
        {
            Id = Guid.NewGuid(),
            AccountId = accountId,
            Points = body.Points,
            FeePoints = WithdrawalFeePoints,
            NetPoints = body.Points - WithdrawalFeePoints,
            Status = "recorded",
            CreatedAt = Now,
        };
        db.WithdrawalRequests.Add(request);
        AddDebit(
            accountId,
            body.Points,
            "earned",
            "withdrawalHold",
            "Withdrawal hold",
            "Earned points held for a recorded request. Not sent to a bank or payout provider.",
            request.Id.ToString("D")
        );
        await db.SaveChangesAsync(ct);
        return ToWithdrawal(request);
    }

    public async Task<WithdrawalRequestResponse> CancelWithdrawalAsync(
        Guid accountId,
        Guid id,
        CancellationToken ct
    )
    {
        await RequireAccount(accountId, ct);
        var row = await db.WithdrawalRequests.FirstOrDefaultAsync(
            w => w.Id == id && w.AccountId == accountId,
            ct
        );
        if (row is null)
        {
            throw new AuthException(404, "That request is gone.", "That withdrawal record is no longer available.");
        }

        if (row.Status != "recorded")
        {
            throw new AuthException(
                400,
                "Already closed.",
                "That withdrawal is no longer recorded as open."
            );
        }

        row.Status = "cancelled";
        row.ResolvedAt = Now;
        db.WalletEntries.Add(new WalletEntry
        {
            Id = Guid.NewGuid(),
            AccountId = accountId,
            Points = row.Points,
            Bucket = "earned",
            Kind = "withdrawalRelease",
            Title = "Withdrawal released",
            Detail = "The hold was released. Nothing was sent to a bank or payout provider.",
            OccurredAt = Now,
            SourceId = row.Id.ToString("D") + ":release",
        });
        await db.SaveChangesAsync(ct);
        return ToWithdrawal(row);
    }

    public async Task EnsureWelcomeAsync(Account account, CancellationToken ct)
    {
        if (AdminAccount.IsAdmin(account)) return;
        if (account.DisplayName is null || account.City is null || account.Gender is null)
        {
            return;
        }

        var exists = await db.WalletEntries.AnyAsync(
            e => e.AccountId == account.Id && e.Kind == "welcomeBonus",
            ct
        ) || db.WalletEntries.Local.Any(e => e.AccountId == account.Id && e.Kind == "welcomeBonus");
        if (exists) return;

        db.WalletEntries.Add(new WalletEntry
        {
            Id = Guid.NewGuid(),
            AccountId = account.Id,
            Points = WelcomeBonusPoints,
            Bucket = "promotional",
            Kind = "welcomeBonus",
            Title = "Welcome bonus",
            Detail = "Promotional welcome points. Not cash and not withdrawable.",
            OccurredAt = Now,
            SourceId = "welcome",
        });
    }

    public async Task EnsureDailyFreePointsAsync(Account account, CancellationToken ct)
    {
        if (AdminAccount.IsAdmin(account)) return;
        if (!ProfileRules.NeedsPaidSubscription(account)) return;
        if (account.DisplayName is null || account.City is null || account.Gender is null) return;

        var dayKey = Discovery.NepalTime.DayKey(Now);
        var sourceId = $"dailyFree:{dayKey}";
        var exists = await db.WalletEntries.AnyAsync(
            e => e.AccountId == account.Id && e.SourceId == sourceId,
            ct
        ) || db.WalletEntries.Local.Any(e => e.AccountId == account.Id && e.SourceId == sourceId);
        if (exists) return;

        var points = DailyFreePointsMale;
        if (appConfig is not null)
        {
            var cfg = await appConfig.GetAsync(ct);
            points = cfg.DailyFreePointsMale;
        }

        db.WalletEntries.Add(new WalletEntry
        {
            Id = Guid.NewGuid(),
            AccountId = account.Id,
            Points = points,
            Bucket = "promotional",
            Kind = "dailyFreePoints",
            Title = "Daily free points",
            Detail =
                $"{points} promotional points for today. Resets each Nepal calendar day. Not cash and not withdrawable.",
            OccurredAt = Now,
            SourceId = sourceId,
        });
    }

    public async Task<ChargeResult> ChargeToAdminAsync(
        Account account,
        int costPaisa,
        string kind,
        string title,
        string detail,
        string sourceId,
        CancellationToken ct
    )
    {
        if (appConfig is not null)
        {
            var cfg = await appConfig.GetAsync(ct);
            if (cfg.KillPremiumCharges)
            {
                throw new AuthException(
                    503,
                    "Premium paused.",
                    "Paid premium actions are temporarily unavailable."
                );
            }
        }

        var charge = await TryChargeAsync(account, costPaisa, kind, title, detail, sourceId, ct);
        if (!charge.Ok || charge.ChargedPaisa <= 0) return charge;

        var admin = await AdminAccount.EnsureAsync(db, Now, ct);
        await CreditEarnedAsync(
            admin.Id,
            charge.ChargedPaisa,
            "adminReceive",
            title,
            detail,
            sourceId + ":admin",
            ct
        );
        return charge;
    }

    public async Task CreditEarnedAsync(
        Guid accountId,
        int points,
        string kind,
        string title,
        string detail,
        string sourceId,
        CancellationToken ct
    )
    {
        if (points <= 0) return;
        var exists = await db.WalletEntries.AnyAsync(
            e => e.AccountId == accountId && e.SourceId == sourceId,
            ct
        ) || db.WalletEntries.Local.Any(e => e.AccountId == accountId && e.SourceId == sourceId);
        if (exists) return;

        db.WalletEntries.Add(new WalletEntry
        {
            Id = Guid.NewGuid(),
            AccountId = accountId,
            Points = points,
            Bucket = "earned",
            Kind = kind,
            Title = title,
            Detail = detail,
            OccurredAt = Now,
            SourceId = sourceId,
        });
    }

    public async Task<int> SpendableAsync(Guid accountId, CancellationToken ct)
    {
        var (promo, earned) = await BalancesAsync(accountId, ct);
        return promo + earned;
    }

    public async Task<ChargeResult> TryChargeAsync(
        Account account,
        int costPaisa,
        string kind,
        string title,
        string detail,
        string sourceId,
        CancellationToken ct
    )
    {
        await EnsureWelcomeAsync(account, ct);
        await EnsureDailyFreePointsAsync(account, ct);
        if (costPaisa <= 0)
        {
            return new ChargeResult(true, 0, await SpendableAsync(account.Id, ct));
        }

        var (promo, earned) = await BalancesAsync(account.Id, ct);
        if (promo + earned < costPaisa)
        {
            return new ChargeResult(false, 0, promo + earned);
        }

        var fromPromo = Math.Min(promo, costPaisa);
        var fromEarned = costPaisa - fromPromo;
        if (fromPromo > 0)
        {
            AddDebit(account.Id, fromPromo, "promotional", kind, title, detail, sourceId);
        }

        if (fromEarned > 0)
        {
            AddDebit(account.Id, fromEarned, "earned", kind, title, detail, sourceId);
        }

        return new ChargeResult(true, costPaisa, promo + earned - costPaisa);
    }

    public async Task RefundAsync(Guid accountId, string sourceId, CancellationToken ct)
    {
        var refundKey = sourceId + ":refund";
        var already = await db.WalletEntries.AnyAsync(
            e => e.AccountId == accountId && e.SourceId == refundKey,
            ct
        );
        if (already) return;

        var debits = (await db.WalletEntries
            .Where(e => e.AccountId == accountId && e.SourceId == sourceId)
            .ToListAsync(ct))
            .Where(e => e.Points < 0)
            .ToList();
        if (debits.Count == 0) return;

        foreach (var debit in debits)
        {
            db.WalletEntries.Add(new WalletEntry
            {
                Id = Guid.NewGuid(),
                AccountId = accountId,
                Points = -debit.Points,
                Bucket = debit.Bucket,
                Kind = "other",
                Title = "Paid action refunded",
                Detail = "Staff or system returned these points.",
                OccurredAt = Now,
                SourceId = refundKey,
            });
        }

        // Claw back the matching adminReceive credit when this was ChargeToAdmin.
        var adminSource = sourceId + ":admin";
        var adminRefundKey = adminSource + ":refund";
        var adminAlready = await db.WalletEntries.AnyAsync(
            e => e.SourceId == adminRefundKey,
            ct
        );
        if (adminAlready) return;

        var adminCredits = (await db.WalletEntries
            .Where(e => e.SourceId == adminSource)
            .ToListAsync(ct))
            .Where(e => e.Points > 0)
            .ToList();
        foreach (var credit in adminCredits)
        {
            db.WalletEntries.Add(new WalletEntry
            {
                Id = Guid.NewGuid(),
                AccountId = credit.AccountId,
                Points = -credit.Points,
                Bucket = credit.Bucket,
                Kind = "other",
                Title = "Admin credit reversed",
                Detail = "Matching refund of a premium charge.",
                OccurredAt = Now,
                SourceId = adminRefundKey,
            });
        }
    }

    async Task<WithdrawalEligibilityResponse> EligibilityFor(Account account, CancellationToken ct)
    {
        var (_, earned) = await BalancesAsync(account.Id, ct);
        var minPoints = MinWithdrawalPoints;
        var withdrawalsKilled = false;
        if (appConfig is not null)
        {
            var cfg = await appConfig.GetAsync(ct);
            minPoints = cfg.MinWithdrawalPoints;
            withdrawalsKilled = cfg.KillWithdrawals;
        }

        var eligibleAccount = ProfileRules.CanWithdraw(account.Gender);
        var belowMinimum = earned < minPoints;
        var hasOpen = await HasOpenRequest(account.Id, ct);
        var canSubmit =
            eligibleAccount && !belowMinimum && !hasOpen && earned > 0 && !withdrawalsKilled;
        var explanation = withdrawalsKilled
            ? "Withdrawals are temporarily unavailable."
            : !eligibleAccount
                ? "Withdrawals are only available to female, LGBTQ+ and other accounts. Promotional points never count."
                : belowMinimum
                    ? $"You need at least {minPoints} earned, withdrawable points. You have {earned} earned points. Promotional points never count toward this threshold."
                    : hasOpen
                        ? "A withdrawal request is already recorded. Cancel it before recording another. Nothing has been sent to a bank."
                        : "You can record a withdrawal of earned points. Promotional points are excluded. A displayed equivalent is not cash. Payouts are not enabled.";
        return new WithdrawalEligibilityResponse(
            eligibleAccount,
            earned,
            minPoints,
            WithdrawalFeePoints,
            canSubmit,
            explanation,
            false,
            true
        );
    }

    async Task<bool> HasOpenRequest(Guid accountId, CancellationToken ct)
    {
        return await db.WithdrawalRequests.AnyAsync(
            w => w.AccountId == accountId && w.Status == "recorded",
            ct
        ) || db.WithdrawalRequests.Local.Any(w => w.AccountId == accountId && w.Status == "recorded");
    }

    async Task<int> PendingPointsAsync(Guid accountId, CancellationToken ct)
    {
        var stored = await db.WithdrawalRequests
            .Where(w => w.AccountId == accountId && w.Status == "recorded")
            .SumAsync(w => (int?)w.Points, ct) ?? 0;
        var local = db.WithdrawalRequests.Local
            .Where(w => w.AccountId == accountId && w.Status == "recorded" && db.Entry(w).State == EntityState.Added)
            .Sum(w => w.Points);
        return stored + local;
    }

    async Task<(int Promo, int Earned)> BalancesAsync(Guid accountId, CancellationToken ct)
    {
        var rows = await db.WalletEntries.Where(e => e.AccountId == accountId).ToListAsync(ct);
        foreach (var local in db.WalletEntries.Local)
        {
            if (local.AccountId != accountId) continue;
            if (rows.Any(r => r.Id == local.Id)) continue;
            rows.Add(local);
        }

        var promo = rows.Where(e => e.Bucket == "promotional").Sum(e => e.Points);
        var earned = rows.Where(e => e.Bucket == "earned").Sum(e => e.Points);
        return (promo, earned);
    }

    void AddDebit(
        Guid accountId,
        int amount,
        string bucket,
        string kind,
        string title,
        string detail,
        string sourceId
    )
    {
        db.WalletEntries.Add(new WalletEntry
        {
            Id = Guid.NewGuid(),
            AccountId = accountId,
            Points = -amount,
            Bucket = bucket,
            Kind = kind,
            Title = title,
            Detail = detail,
            OccurredAt = Now,
            SourceId = sourceId,
        });
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

    static WalletTransactionResponse ToResponse(WalletEntry entry) =>
        new(
            entry.Id.ToString(),
            entry.Title,
            entry.Points,
            entry.OccurredAt,
            entry.Bucket,
            entry.Kind,
            entry.Detail
        );

    static WithdrawalRequestResponse ToWithdrawal(Data.WithdrawalRequest row) =>
        new(
            row.Id.ToString(),
            row.Points,
            row.FeePoints,
            row.NetPoints,
            row.Status,
            row.CreatedAt,
            row.ResolvedAt,
            false,
            true
        );
}
