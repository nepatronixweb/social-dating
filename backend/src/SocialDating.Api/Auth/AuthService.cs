using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SocialDating.Api.Data;
using SocialDating.Api.Referrals;

namespace SocialDating.Api.Auth;

public interface IAuthService
{
    Task<RequestCodeResponse> RequestCodeAsync(string? phone, CancellationToken ct);
    Task<AuthVerifyResponse> VerifyAsync(
        string? phone,
        string? code,
        CancellationToken ct,
        string? referralCode = null,
        bool login = false,
        ClientContext client = default
    );
    Task<AuthVerifyResponse> RefreshAsync(
        string? refreshToken,
        CancellationToken ct,
        ClientContext client = default
    );
    Task SignOutAsync(Guid accountId, string? refreshToken, CancellationToken ct);
    Task<AccountStateResponse> GetMeAsync(Guid accountId, CancellationToken ct);
    Task<AccountStateResponse> AcceptTermsAsync(Guid accountId, CancellationToken ct);
    Task<AccountStateResponse> SubmitAgeAsync(Guid accountId, string? birthDate, CancellationToken ct);
    Task<AccountStateResponse> SetGenderAsync(Guid accountId, string? gender, CancellationToken ct);
    Task<AccountStateResponse> CompleteProfileAsync(
        Guid accountId,
        CompleteProfileRequest body,
        CancellationToken ct
    );
    Task DeleteAccountAsync(Guid accountId, CancellationToken ct);
}

public sealed class AuthService(
    AppDbContext db,
    IJwtTokenService jwt,
    IOtpGenerator otps,
    IOptions<AuthOptions> authOptions,
    ILogger<AuthService> logger,
    TimeProvider time,
    IReferralService? referrals = null
) : IAuthService
{
    readonly AuthOptions _auth = authOptions.Value;

    DateTimeOffset Now => time.GetUtcNow();

    public async Task<RequestCodeResponse> RequestCodeAsync(string? phone, CancellationToken ct)
    {
        if (!PhoneE164.TryNormalize(phone, out var e164))
        {
            throw new AuthException(400, "Check your details.", "Enter a valid phone number.");
        }

        var cooldown = TimeSpan.FromSeconds(_auth.ResendCooldownSeconds);
        var cutoff = Now - cooldown;
        var recent = (await db.OtpChallenges
            .Where(c => c.PhoneE164 == e164)
            .ToListAsync(ct))
            .OrderByDescending(c => c.CreatedAt)
            .FirstOrDefault(c => c.CreatedAt > cutoff);
        if (recent is not null)
        {
            var wait = (int)Math.Ceiling((recent.CreatedAt + cooldown - Now).TotalSeconds);
            throw new AuthException(
                429,
                "Slow down",
                "Too many attempts. Wait a moment and try again.",
                Math.Max(wait, 1)
            );
        }

        var code = otps.Next();
        var (salt, hash) = SecretHasher.HashOtp(code);
        db.OtpChallenges.Add(
            new OtpChallenge
            {
                Id = Guid.NewGuid(),
                PhoneE164 = e164,
                CodeSalt = salt,
                CodeHash = hash,
                CreatedAt = Now,
                ExpiresAt = Now.AddMinutes(_auth.OtpTtlMinutes),
            }
        );
        await db.SaveChangesAsync(ct);

        if (_auth.SmsEnabled)
        {
            logger.LogInformation("OTP issued for a phone ending {Suffix}.", e164[^4..]);
        }
        else if (_auth.LogOtps && string.IsNullOrWhiteSpace(_auth.StaticOtp))
        {
            logger.LogWarning("DEV OTP for {Phone} is {Code}. SMS is not sent.", e164, code);
        }
        else
        {
            logger.LogInformation(
                "OTP issued for a phone ending {Suffix}. SMS is not sent. Use the static development code.",
                e164[^4..]
            );
        }

        var registered = await db.Accounts.AnyAsync(a => a.PhoneE164 == e164, ct);
        return new RequestCodeResponse(_auth.ResendCooldownSeconds, registered);
    }

    public async Task<AuthVerifyResponse> VerifyAsync(
        string? phone,
        string? code,
        CancellationToken ct,
        string? referralCode = null,
        bool login = false,
        ClientContext client = default
    )
    {
        if (!PhoneE164.TryNormalize(phone, out var e164))
        {
            throw new AuthException(400, "Check your details.", "Enter a valid phone number.");
        }

        var digits = new string((code ?? "").Where(char.IsDigit).ToArray());
        if (digits.Length != 6)
        {
            throw new AuthException(400, "Check your details.", "The code has 6 digits.");
        }

        var challenge = (await db.OtpChallenges
            .Where(c => c.PhoneE164 == e164 && c.ConsumedAt == null)
            .ToListAsync(ct))
            .OrderByDescending(c => c.CreatedAt)
            .FirstOrDefault(c => c.ExpiresAt > Now);

        if (challenge is null)
        {
            throw new AuthException(401, "That code isn't right.", "Request a new code and try again.");
        }

        challenge.AttemptCount++;
        if (challenge.AttemptCount > _auth.OtpMaxAttempts)
        {
            challenge.ConsumedAt = Now;
            await db.SaveChangesAsync(ct);
            throw new AuthException(429, "Slow down", "Too many attempts. Wait a moment and try again.");
        }

        if (!SecretHasher.VerifyOtp(digits, challenge.CodeSalt, challenge.CodeHash))
        {
            await db.SaveChangesAsync(ct);
            throw new AuthException(401, "That code isn't right.", "Check the code and try again.");
        }

        challenge.ConsumedAt = Now;

        var account = await db.Accounts.FirstOrDefaultAsync(a => a.PhoneE164 == e164, ct);
        var returning = account is not null;
        if (account is null)
        {
            account = new Account
            {
                Id = Guid.NewGuid(),
                PhoneE164 = e164,
                CreatedAt = Now,
                UpdatedAt = Now,
            };
            db.Accounts.Add(account);
        }

        // Registered numbers are finished and open the app after the code.
        // New numbers accept terms and age here, then choose gender and name.
        if (login || returning)
        {
            PrepareReturningAccount(account);
        }
        else
        {
            PrepareNewAccount(account);
        }

        await db.SaveChangesAsync(ct);
        if (!returning && referrals is not null)
        {
            await referrals.TryAttributeOnVerifyAsync(account.Id, referralCode, ct);
        }

        if ((login || returning) && referrals is not null)
        {
            await referrals.EnsureCodeAsync(account, ct);
        }

        await EnsureClientNotBlockedAsync(client, ct);
        return await IssueSessionAsync(account, client, ct);
    }

    public async Task<AuthVerifyResponse> RefreshAsync(
        string? refreshToken,
        CancellationToken ct,
        ClientContext client = default
    )
    {
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        }

        var hash = SecretHasher.HashToken(refreshToken);
        var stored = await db.RefreshTokens
            .Include(t => t.Account)
            .FirstOrDefaultAsync(t => t.TokenHash == hash, ct);

        if (stored is null
            || stored.Account is null
            || stored.RevokedAt is not null
            || stored.ExpiresAt.UtcDateTime <= Now.UtcDateTime)
        {
            throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        }

        await EnsureClientNotBlockedAsync(client, ct);
        stored.RevokedAt = Now;
        await db.SaveChangesAsync(ct);
        return await IssueSessionAsync(stored.Account, client, ct);
    }

    public async Task SignOutAsync(Guid accountId, string? refreshToken, CancellationToken ct)
    {
        var tokens = db.RefreshTokens.Where(t => t.AccountId == accountId && t.RevokedAt == null);
        if (!string.IsNullOrWhiteSpace(refreshToken))
        {
            var hash = SecretHasher.HashToken(refreshToken);
            tokens = tokens.Where(t => t.TokenHash == hash);
        }

        await tokens.ExecuteUpdateAsync(
            s => s.SetProperty(t => t.RevokedAt, Now),
            ct
        );
    }

    public async Task<AccountStateResponse> GetMeAsync(Guid accountId, CancellationToken ct)
    {
        var account = await RequireAccount(accountId, ct);
        return ToState(account);
    }

    public async Task<AccountStateResponse> AcceptTermsAsync(Guid accountId, CancellationToken ct)
    {
        var account = await RequireAccount(accountId, ct);
        account.TermsAcceptedAt ??= Now;
        account.UpdatedAt = Now;
        await db.SaveChangesAsync(ct);
        return ToState(account);
    }

    public async Task<AccountStateResponse> SubmitAgeAsync(Guid accountId, string? birthDate, CancellationToken ct)
    {
        var account = await RequireAccount(accountId, ct);
        if (account.AgeCheckedAt is not null)
        {
            return ToState(account);
        }

        if (!DateOnly.TryParse(birthDate, out var date))
        {
            throw new AuthException(400, "Check your details.", "Enter a valid birth date.");
        }

        var today = DateOnly.FromDateTime(Now.UtcDateTime);
        var problem = AgePolicy.Validate(date, today);
        if (problem is not null)
        {
            throw new AuthException(400, "Check your details.", problem);
        }

        account.BirthDate = date;
        account.AgeEligible = AgePolicy.IsEligible(date, today);
        account.AgeCheckedAt = Now;
        account.UpdatedAt = Now;
        await db.SaveChangesAsync(ct);
        return ToState(account);
    }

    public async Task<AccountStateResponse> SetGenderAsync(
        Guid accountId,
        string? gender,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        var genderProblem = ProfileRules.ValidateGender(gender);
        if (genderProblem is not null)
        {
            throw new AuthException(400, "Check your details.", genderProblem);
        }

        account.Gender = ProfileRules.CanonicalGender(gender);
        account.UpdatedAt = Now;
        await db.SaveChangesAsync(ct);
        return ToState(account);
    }

    public async Task<AccountStateResponse> CompleteProfileAsync(
        Guid accountId,
        CompleteProfileRequest body,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        var name = body.DisplayName?.Trim() ?? "";
        var nameProblem = ProfileRules.ValidateDisplayName(name);
        if (nameProblem is not null)
        {
            throw new AuthException(400, "Check your details.", nameProblem);
        }

        var bio = string.IsNullOrWhiteSpace(body.Bio) ? null : body.Bio.Trim();
        var bioProblem = ProfileRules.ValidateBio(bio);
        if (bioProblem is not null)
        {
            throw new AuthException(400, "Check your details.", bioProblem);
        }

        var genderRaw = string.IsNullOrWhiteSpace(body.Gender) ? account.Gender : body.Gender.Trim();
        var genderProblem = ProfileRules.ValidateGender(genderRaw);
        if (genderProblem is not null)
        {
            throw new AuthException(400, "Check your details.", genderProblem);
        }

        var city = string.IsNullOrWhiteSpace(body.City) ? account.City : body.City.Trim();
        city ??= "Kathmandu";
        var cityProblem = ProfileRules.ValidateCity(city);
        if (cityProblem is not null)
        {
            throw new AuthException(400, "Check your details.", cityProblem);
        }

        var interests = ProfileRules.NormalizeInterests(body.Interests);
        if (interests.Length < ProfileRules.MinInterests)
        {
            interests = account.Interests.Length >= ProfileRules.MinInterests
                ? account.Interests
                : ["Hiking", "Coffee", "Film"];
        }
        var interestProblem = ProfileRules.ValidateInterests(interests);
        if (interestProblem is not null)
        {
            throw new AuthException(400, "Check your details.", interestProblem);
        }

        account.DisplayName = name;
        account.Bio = bio;
        account.Interests = interests;
        account.City = city;
        account.Gender = ProfileRules.CanonicalGender(genderRaw);
        account.UpdatedAt = Now;
        await db.SaveChangesAsync(ct);
        if (referrals is not null)
        {
            await referrals.EnsureCodeAsync(account, ct);
        }

        return ToState(account);
    }

    public async Task DeleteAccountAsync(Guid accountId, CancellationToken ct)
    {
        var account = await RequireAccount(accountId, ct);
        account.DeletedAt = Now;
        account.UpdatedAt = Now;
        await db.RefreshTokens
            .Where(t => t.AccountId == accountId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, Now), ct);
        await db.SaveChangesAsync(ct);
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

    void PrepareReturningAccount(Account account)
    {
        account.TermsAcceptedAt ??= Now;
        if (account.AgeEligible == false)
        {
            account.UpdatedAt = Now;
            return;
        }

        if (account.BirthDate is null)
        {
            account.BirthDate = new DateOnly(1995, 3, 7);
            account.AgeEligible = AgePolicy.IsEligible(
                account.BirthDate.Value,
                DateOnly.FromDateTime(Now.UtcDateTime)
            );
            account.AgeCheckedAt ??= Now;
        }
        else if (account.AgeEligible is null)
        {
            account.AgeEligible = AgePolicy.IsEligible(
                account.BirthDate.Value,
                DateOnly.FromDateTime(Now.UtcDateTime)
            );
            account.AgeCheckedAt ??= Now;
        }

        account.DisplayName ??= "You";
        account.City ??= "Kathmandu";
        account.Gender ??= "male";
        if (account.Interests.Length < ProfileRules.MinInterests)
        {
            account.Interests = ["Hiking", "Coffee", "Film"];
        }

        account.UpdatedAt = Now;
    }

    void PrepareNewAccount(Account account)
    {
        account.TermsAcceptedAt ??= Now;
        if (account.BirthDate is null)
        {
            account.BirthDate = new DateOnly(1995, 3, 7);
            account.AgeEligible = AgePolicy.IsEligible(
                account.BirthDate.Value,
                DateOnly.FromDateTime(Now.UtcDateTime)
            );
            account.AgeCheckedAt ??= Now;
        }
        else if (account.AgeEligible is null)
        {
            account.AgeEligible = AgePolicy.IsEligible(
                account.BirthDate.Value,
                DateOnly.FromDateTime(Now.UtcDateTime)
            );
            account.AgeCheckedAt ??= Now;
        }

        account.UpdatedAt = Now;
    }

    async Task EnsureClientNotBlockedAsync(ClientContext client, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(client.DeviceId))
        {
            var deviceBlocked = await db.AuthBlockEntries.AsNoTracking().AnyAsync(
                b => b.Active && b.Kind == "device" && b.Value == client.DeviceId,
                ct
            );
            if (deviceBlocked)
            {
                throw new AuthException(
                    403,
                    "Sign-in blocked.",
                    "This device cannot sign in. Contact support if you think this is a mistake."
                );
            }
        }

        if (!string.IsNullOrWhiteSpace(client.IpAddress))
        {
            var ipBlocked = await db.AuthBlockEntries.AsNoTracking().AnyAsync(
                b => b.Active && b.Kind == "ip" && b.Value == client.IpAddress,
                ct
            );
            if (ipBlocked)
            {
                throw new AuthException(
                    403,
                    "Sign-in blocked.",
                    "This network cannot sign in. Contact support if you think this is a mistake."
                );
            }
        }
    }

    async Task<AuthVerifyResponse> IssueSessionAsync(
        Account account,
        ClientContext client,
        CancellationToken ct
    )
    {
        var (access, expiresAt) = jwt.IssueAccessToken(account.Id);
        var refresh = SecretHasher.NewRefreshToken();
        db.RefreshTokens.Add(
            new RefreshToken
            {
                Id = Guid.NewGuid(),
                AccountId = account.Id,
                TokenHash = SecretHasher.HashToken(refresh),
                CreatedAt = Now,
                ExpiresAt = Now.AddDays(_auth.RefreshTokenDays),
                IpAddress = client.IpAddress,
                DeviceId = client.DeviceId,
                UserAgent = client.UserAgent,
            }
        );
        await db.SaveChangesAsync(ct);
        return new AuthVerifyResponse(ToState(account), access, refresh, expiresAt);
    }

    static AccountStateResponse ToState(Account account)
    {
        string? restriction = null;
        if (account.DeletedAt is not null) restriction = "banned";
        else if (account.SuspendedAt is not null) restriction = "suspended";
        else if (account.ShadowBannedAt is not null) restriction = "shadowBanned";

        return new(
            account.Id.ToString(),
            account.TermsAcceptedAt is not null,
            account.AgeEligible,
            account.DisplayName,
            account.Gender,
            restriction
        );
    }
}
