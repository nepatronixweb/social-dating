using System.Text.RegularExpressions;

namespace SocialDating.Api.Auth;

/// E.164 phone numbers. Stored privately; never placed on account JSON.
public static partial class PhoneE164
{
    [GeneratedRegex(@"^\+[1-9]\d{7,14}$", RegexOptions.CultureInvariant)]
    private static partial Regex Pattern();

    public static bool TryNormalize(string? raw, out string e164)
    {
        e164 = "";
        if (string.IsNullOrWhiteSpace(raw)) return false;
        var compact = raw.Trim().Replace(" ", "", StringComparison.Ordinal);
        if (!Pattern().IsMatch(compact)) return false;
        e164 = compact;
        return true;
    }

    /// Masked label safe for UI. Never returns the full number.
    public static string Mask(string e164)
    {
        if (string.IsNullOrWhiteSpace(e164) || e164.Length < 6) return "+•";
        var last4 = e164[^4..];
        return $"{e164[..Math.Min(4, e164.Length - 4)]}••••••{last4}";
    }
}
