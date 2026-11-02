using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Data;
using SocialDating.Api.Discovery;
using SocialDating.Api.Wallet;

namespace SocialDating.Api.Ops;

public interface IAppConfigService
{
    Task<AppRuntimeSettings> GetAsync(CancellationToken ct);
    Task<AppRuntimeSettings> EnsureAsync(CancellationToken ct);
}

public sealed class AppConfigService(AppDbContext db, TimeProvider time) : IAppConfigService
{
    static readonly Guid SettingsId = Guid.Parse("11111111-1111-1111-1111-111111111111");

    public async Task<AppRuntimeSettings> GetAsync(CancellationToken ct) =>
        await EnsureAsync(ct);

    public async Task<AppRuntimeSettings> EnsureAsync(CancellationToken ct)
    {
        var row = await db.AppRuntimeSettings.FirstOrDefaultAsync(s => s.Id == SettingsId, ct);
        if (row is not null) return row;

        row = new AppRuntimeSettings
        {
            Id = SettingsId,
            PremiumActionPoints = WalletService.PremiumActionPricePoints,
            ExtraSwipePoints = DiscoveryService.ExtraSwipePricePaisa,
            DailyFreePointsMale = WalletService.DailyFreePointsMale,
            FreeDailySwipesMale = DiscoveryService.FreeDailySwipesMale,
            MinWithdrawalPoints = WalletService.MinWithdrawalPoints,
            UpdatedAt = time.GetUtcNow(),
        };
        db.AppRuntimeSettings.Add(row);
        await db.SaveChangesAsync(ct);
        return row;
    }
}
