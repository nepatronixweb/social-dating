using System.Security.Cryptography;
using System.Text;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Admin;

public static class StaffPassword
{
    public static (byte[] salt, byte[] hash) Hash(string password)
    {
        var salt = RandomNumberGenerator.GetBytes(16);
        return (salt, Compute(password, salt));
    }

    public static bool Verify(string password, byte[] salt, byte[] expected)
    {
        var actual = Compute(password, salt);
        return CryptographicOperations.FixedTimeEquals(actual, expected);
    }

    static byte[] Compute(string password, byte[] salt)
    {
        // PBKDF2 for staff passwords (OTP hasher stays separate).
        return Rfc2898DeriveBytes.Pbkdf2(
            Encoding.UTF8.GetBytes(password),
            salt,
            iterations: 100_000,
            hashAlgorithm: HashAlgorithmName.SHA256,
            outputLength: 32
        );
    }
}
