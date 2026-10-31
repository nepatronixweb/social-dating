using System.Security.Cryptography;

namespace SocialDating.Api.Auth;

public static class SecretHasher
{
    public static (byte[] salt, byte[] hash) HashOtp(string code)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        return (salt, Compute(code, salt));
    }

    public static bool VerifyOtp(string code, byte[] salt, byte[] expected)
    {
        var actual = Compute(code, salt);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }

    public static byte[] HashToken(string token)
    {
        return SHA256.HashData(System.Text.Encoding.UTF8.GetBytes(token));
    }

    public static string NewRefreshToken()
    {
        return Convert.ToBase64String(RandomNumberGenerator.GetBytes(32))
            .TrimEnd('=')
            .Replace('+', '-')
            .Replace('/', '_');
    }

    public static string NewOtp() => RandomNumberGenerator.GetInt32(0, 1_000_000).ToString("D6");

    static byte[] Compute(string code, byte[] salt)
    {
        using var hmac = new HMACSHA256(salt);
        return hmac.ComputeHash(System.Text.Encoding.UTF8.GetBytes(code));
    }
}

public interface IOtpGenerator
{
    string Next();
}

public sealed class RandomOtpGenerator : IOtpGenerator
{
    public string Next() => SecretHasher.NewOtp();
}

public sealed class StaticOtpGenerator(string code) : IOtpGenerator
{
    public string Next() => code;
}
