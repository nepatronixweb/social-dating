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
        if (string.IsNullOrWhiteSpace(_options.SigningKey) || _options.SigningKey.Length < 32)
        {
            throw new InvalidOperationException("Jwt:SigningKey must be at least 32 characters.");
        }

        var expires = DateTimeOffset.UtcNow.AddMinutes(_auth.AccessTokenMinutes);
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_options.SigningKey));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(
            issuer: _options.Issuer,
            audience: _options.Audience,
            claims:
            [
                new Claim(JwtRegisteredClaimNames.Sub, accountId.ToString()),
                new Claim(ClaimTypes.NameIdentifier, accountId.ToString()),
            ],
            expires: expires.UtcDateTime,
            signingCredentials: creds
        );
        return (new JwtSecurityTokenHandler().WriteToken(token), expires);
    }
}
