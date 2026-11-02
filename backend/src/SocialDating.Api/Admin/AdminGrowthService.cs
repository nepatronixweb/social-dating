using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Inbox;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Admin;

public interface IAdminGrowthService
{
    Task<AdminPromoCodeListResponse> ListPromoCodesAsync(CancellationToken ct);
    Task<AdminPromoCodeItem> CreatePromoCodeAsync(
        CreatePromoCodeRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task SetPromoActiveAsync(
        Guid id,
        SetPromoActiveRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
    Task<RedeemPromoResponse> RedeemPromoAsync(
        Guid accountId,
        RedeemPromoRequest body,
        CancellationToken ct
    );
    Task<BroadcastResponse> BroadcastAsync(
        BroadcastRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    );
}

public sealed class AdminGrowthService(
    AppDbContext db,
    IWalletService wallet,
    IInboxService inbox,
    TimeProvider time
) : IAdminGrowthService
{
    public const int BroadcastCap = 5000;
    DateTimeOffset Now => time.GetUtcNow();

    public async Task<AdminPromoCodeListResponse> ListPromoCodesAsync(CancellationToken ct)
    {
        var rows = await db.PromoCodes
            .AsNoTracking()
            .OrderByDescending(p => p.CreatedAt)
            .Take(100)
            .ToListAsync(ct);
        return new AdminPromoCodeListResponse(rows.Select(ToItem).ToList());
    }

    public async Task<AdminPromoCodeItem> CreatePromoCodeAsync(
        CreatePromoCodeRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireFinanceWrite(staff);
        var code = NormalizeCode(body.Code);
        if (code is null)
        {
            throw new AuthException(
                400,
                "Check your details.",
                "Code must be 4–32 letters or digits."
            );
        }

        if (body.Points is < 1 or > 100_000)
        {
            throw new AuthException(400, "Check your details.", "Points must be 1–100000.");
        }

        var bucket = (body.Bucket ?? "promotional").Trim().ToLowerInvariant();
        if (bucket is not ("promotional" or "earned"))
        {
            throw new AuthException(400, "Check your details.", "Bucket must be promotional or earned.");
        }

        var max = body.MaxRedemptions ?? 1000;
        if (max is < 1 or > 1_000_000)
        {
            throw new AuthException(400, "Check your details.", "Max redemptions must be 1–1000000.");
        }

        if (await db.PromoCodes.AnyAsync(p => p.Code == code, ct))
        {
            throw new AuthException(400, "Code taken.", "That promo code already exists.");
        }

        var row = new PromoCode
        {
            Id = Guid.NewGuid(),
            Code = code,
            Points = body.Points,
            Bucket = bucket,
            MaxRedemptions = max,
            RedemptionCount = 0,
            ExpiresAt = body.ExpiresAt,
            Active = true,
            CreatedByEmail = staff.RequireStaffEmail(),
            CreatedAt = Now,
        };
        db.PromoCodes.Add(row);
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "promo.create",
                TargetType = "promo",
                TargetId = row.Id.ToString(),
                Detail = $"{code} · {body.Points} {bucket}",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
        return ToItem(row);
    }

    public async Task SetPromoActiveAsync(
        Guid id,
        SetPromoActiveRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireFinanceWrite(staff);
        var row = await db.PromoCodes.FirstOrDefaultAsync(p => p.Id == id, ct)
            ?? throw new AuthException(404, "Promo not found.", "That code is gone.");
        row.Active = body.Active;
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = body.Active ? "promo.enable" : "promo.disable",
                TargetType = "promo",
                TargetId = row.Id.ToString(),
                Detail = row.Code,
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<RedeemPromoResponse> RedeemPromoAsync(
        Guid accountId,
        RedeemPromoRequest body,
        CancellationToken ct
    )
    {
        var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == accountId, ct)
            ?? throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        if (AdminAccount.IsAdmin(account))
        {
            throw new AuthException(400, "Not available.", "Admin ledger cannot redeem promos.");
        }

        var code = NormalizeCode(body.Code)
            ?? throw new AuthException(400, "Check your details.", "Enter a valid promo code.");

        var promo = await db.PromoCodes.FirstOrDefaultAsync(p => p.Code == code, ct);
        if (promo is null || !promo.Active)
        {
            throw new AuthException(400, "Invalid code.", "That promo code is not valid.");
        }

        if (promo.ExpiresAt is DateTimeOffset exp && exp <= Now)
        {
            throw new AuthException(400, "Code expired.", "That promo code has expired.");
        }

        if (promo.RedemptionCount >= promo.MaxRedemptions)
        {
            throw new AuthException(400, "Code exhausted.", "That promo code has no redemptions left.");
        }

        var already = await db.PromoRedemptions.AnyAsync(
            r => r.PromoCodeId == promo.Id && r.AccountId == accountId,
            ct
        );
        if (already)
        {
            throw new AuthException(400, "Already redeemed.", "You already used this promo code.");
        }

        promo.RedemptionCount++;
        db.PromoRedemptions.Add(
            new PromoRedemption
            {
                Id = Guid.NewGuid(),
                PromoCodeId = promo.Id,
                AccountId = accountId,
                CreatedAt = Now,
            }
        );

        var sourceId = $"promo:{promo.Id:D}:{accountId:D}";
        if (promo.Bucket == "earned")
        {
            await wallet.CreditEarnedAsync(
                accountId,
                promo.Points,
                "promoRedeem",
                "Promo code",
                $"Redeemed {promo.Code}.",
                sourceId,
                ct
            );
        }
        else
        {
            db.WalletEntries.Add(
                new WalletEntry
                {
                    Id = Guid.NewGuid(),
                    AccountId = accountId,
                    Points = promo.Points,
                    Bucket = "promotional",
                    Kind = "promoRedeem",
                    Title = "Promo code",
                    Detail = $"Redeemed {promo.Code}. Not cash and not withdrawable.",
                    OccurredAt = Now,
                    SourceId = sourceId,
                }
            );
        }

        await db.SaveChangesAsync(ct);
        var spendable = await wallet.SpendableAsync(accountId, ct);
        return new RedeemPromoResponse(promo.Points, promo.Bucket, spendable);
    }

    public async Task<BroadcastResponse> BroadcastAsync(
        BroadcastRequest body,
        ClaimsPrincipal staff,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSupportWrite(staff);
        var title = (body.Title ?? "").Trim();
        var text = (body.Body ?? "").Trim();
        if (title.Length is < 2 or > 80)
        {
            throw new AuthException(400, "Check your details.", "Title must be 2–80 characters.");
        }

        if (text.Length is < 2 or > 300)
        {
            throw new AuthException(400, "Check your details.", "Body must be 2–300 characters.");
        }

        var query = db.Accounts.AsQueryable()
            .Where(a => a.PhoneE164 != AdminAccount.PhoneE164);

        if (!string.IsNullOrWhiteSpace(body.City))
        {
            var city = body.City.Trim().ToLowerInvariant();
            query = query.Where(a => a.City != null && a.City.ToLower() == city);
        }

        if (body.IncompleteOnly)
        {
            query = query.Where(a =>
                a.DisplayName == null || a.City == null || a.BirthDate == null || a.Gender == null);
        }

        var gender = ProfileRules.CanonicalGender(body.Gender);
        var candidates = await query
            .Select(a => new { a.Id, a.Gender })
            .Take(BroadcastCap * 3)
            .ToListAsync(ct);
        if (gender is not null)
        {
            candidates = candidates
                .Where(a => ProfileRules.CanonicalGender(a.Gender) == gender)
                .ToList();
        }

        if (candidates.Count > BroadcastCap)
        {
            throw new AuthException(
                400,
                "Audience too large.",
                $"Narrow the segment — max {BroadcastCap} recipients per send."
            );
        }

        var recipientIds = candidates.Select(a => a.Id).ToList();
        await inbox.NotifySystemBulkAsync(recipientIds, title, text, ct);

        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.RequireStaffId(),
                StaffEmail = staff.RequireStaffEmail(),
                Action = "broadcast.send",
                TargetType = "broadcast",
                TargetId = null,
                Detail = $"{recipientIds.Count} · {title}",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);

        return new BroadcastResponse(
            recipientIds.Count,
            $"Sent to {recipientIds.Count} account(s)."
        );
    }

    static string? NormalizeCode(string? raw)
    {
        var code = (raw ?? "").Trim().ToUpperInvariant();
        if (code.Length is < 4 or > 32) return null;
        if (!code.All(char.IsLetterOrDigit)) return null;
        return code;
    }

    static AdminPromoCodeItem ToItem(PromoCode p) =>
        new(
            p.Id.ToString(),
            p.Code,
            p.Points,
            p.Bucket,
            p.MaxRedemptions,
            p.RedemptionCount,
            p.ExpiresAt,
            p.Active,
            p.CreatedByEmail,
            p.CreatedAt
        );
}
