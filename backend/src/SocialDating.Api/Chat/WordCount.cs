using System.Text.RegularExpressions;

namespace SocialDating.Api.Chat;

/// Mirrors Flutter `countEligibleWords` / `MessageRules`. The server counts
/// for itself and never trusts a client quote.
public static class WordCount
{
    public const int MaxCharacters = 500;
    public const int PaisaPerEligibleWord = 10;

    static readonly Regex Whitespace = new(@"\s+", RegexOptions.CultureInvariant | RegexOptions.Compiled);
    static readonly Regex Letter = new(@"\p{L}", RegexOptions.CultureInvariant | RegexOptions.Compiled);

    public static int EligibleWords(string text)
    {
        var trimmed = text.Trim();
        if (trimmed.Length == 0) return 0;
        return Whitespace.Split(trimmed).Count(token => Letter.IsMatch(token));
    }
}
