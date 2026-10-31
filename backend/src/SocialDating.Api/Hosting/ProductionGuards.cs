using SocialDating.Api.Auth;

namespace SocialDating.Api.Hosting;

public static class ProductionGuards
{
    public static void Ensure(IHostEnvironment environment, AuthOptions auth)
    {
        if (!environment.IsProduction()) return;
        if (auth.LogOtps)
        {
            throw new InvalidOperationException("Auth:LogOtps must be false in Production. OTP codes must not be written to logs.");
        }
    }
}
