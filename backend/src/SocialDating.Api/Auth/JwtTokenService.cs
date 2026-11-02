using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;

namespace SocialDating.Api.Auth;

public sealed class JwtOptions
{
    public const string SectionName = "Jwt";

    public string Issuer { get; set; } = "social-dating";
    public string Audience { get; set; } = "social-dating-app";
    public string SigningKey { get; set; } = "";
}

public interface IJwtTokenService
{
    (string token, DateTimeOffset expiresAt) IssueAccessToken(Guid accountId);

    (string token, DateTimeOffset expiresAt) IssueStaffAccessToken(
        Guid staffId,
        string email,
        string role,
        int lifetimeMinutes
    );
}

public sealed class JwtTokenService(
    IOptions<JwtOptions> options,
    IOptions<AuthOptions> auth
) : IJwtTokenService
{
    readonly JwtOptions _options = options.Value;
    readonly AuthOptions _auth = auth.Value;

    public (string token, DateTimeOffset expiresAt) IssueAccessToken(Guid accountId)
    {
        EnsureKey();
        var expires = DateTimeOffset.UtcNow.AddMinutes(_auth.AccessTokenMinutes);
        return Issue(
            expires,
            [
                new Claim(JwtRegisteredClaimNames.Sub, accountId.ToString()),
                new Claim(ClaimTypes.NameIdentifier, accountId.ToString()),
            ]
        );
    }

    public (string token, DateTimeOffset expiresAt) IssueStaffAccessToken(
        Guid staffId,
        string email,
        string role,
        int lifetimeMinutes
    )
    {
        EnsureKey();
        var minutes = Math.Clamp(lifetimeMinutes, 15, 24 * 60);
        var expires = DateTimeOffset.UtcNow.AddMinutes(minutes);
        return Issue(
            expires,
            [
                new Claim(JwtRegisteredClaimNames.Sub, staffId.ToString()),
                new Claim(ClaimTypes.NameIdentifier, staffId.ToString()),
                new Claim(Admin.StaffClaims.TypeClaim, Admin.StaffClaims.TokenType),
                new Claim(Admin.StaffClaims.EmailClaim, email),
                new Claim(Admin.StaffClaims.RoleClaim, role),
            ]
        );
    }

    void EnsureKey()
    {
        if (string.IsNullOrWhiteSpace(_options.SigningKey) || _options.SigningKey.Length < 32)
        {
            throw new InvalidOperationException("Jwt:SigningKey must be at least 32 characters.");
        }
    }

    (string token, DateTimeOffset expiresAt) Issue(DateTimeOffset expires, Claim[] claims)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var now = DateTime.UtcNow;
        var withIat = claims
            .Append(
                new Claim(
                    JwtRegisteredClaimNames.Iat,
                    EpochTime.GetIntDate(now).ToString(),
                    ClaimValueTypes.Integer64
                )
            )
            .ToArray();
        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims: withIat,
            notBefore: now,
            expires: expires.UtcDateTime,
            signingCredentials: creds
        );
        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }
}
