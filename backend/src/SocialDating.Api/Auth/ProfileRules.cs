using System.Text.RegularExpressions;

namespace SocialDating.Api.Auth;

/// Mirrors `AppConstants` / `Validators` in the Flutter app so the server is
/// the source of truth for profile completion.
public static class ProfileRules
{
    public const int MinNameLength = 2;
    public const int MaxNameLength = 30;
    public const int MaxBioLength = 300;
    public const int MinInterests = 3;
    public const int MaxInterests = 8;

    public static readonly HashSet<string> AllowedInterests = new(StringComparer.Ordinal)
    {
        "Coffee",
        "Hiking",
        "Film",
        "Cooking",
        "Travel",
        "Music",
        "Books",
        "Climbing",
        "Art",
        "Dogs",
        "Yoga",
        "Running",
        "Photography",
        "Gaming",
    };

    public static readonly HashSet<string> AllowedCities = new(StringComparer.Ordinal)
    {
        "Kathmandu",
        "Lalitpur",
        "Bhaktapur",
        "Pokhara",
        "Biratnagar",
        "Bharatpur",
        "Dharan",
        "Nepalgunj",
    };

    public static readonly HashSet<string> AllowedGenders = new(StringComparer.Ordinal)
    {
        "male",
        "female",
        "lgbtq",
        "other",
        "man",
        "woman",
        "nonBinary",
        "transgender",
    };

    public static string? CanonicalGender(string? gender)
    {
        if (string.IsNullOrWhiteSpace(gender)) return null;
        return gender.Trim() switch
        {
            "male" or "man" => "male",
            "female" or "woman" => "female",
            "lgbtq" or "nonBinary" or "transgender" => "lgbtq",
            "other" => "other",
            _ => null,
        };
    }

    public static bool IsMale(string? gender) => CanonicalGender(gender) == "male";

    public static bool IsFemale(string? gender) => CanonicalGender(gender) == "female";

    /// Female, LGBTQ+ and other accounts may record a withdrawal. Male cannot.
    public static bool CanWithdraw(string? gender)
    {
        var canonical = CanonicalGender(gender);
        return canonical is not null && canonical != "male";
    }

    /// Female, LGBTQ+ and other accounts have every Premium feature at no charge.
    public static bool HasComplimentaryPremium(string? gender) => CanWithdraw(gender);

    public static bool HasComplimentaryPremium(Data.Account account) =>
        account.StaffComplimentaryPremium || CanWithdraw(account.Gender);

    /// Only male accounts buy a subscription for Premium.
    public static bool NeedsPaidSubscription(string? gender) => IsMale(gender);

    public static bool NeedsPaidSubscription(Data.Account account) =>
        IsMale(account.Gender) && !account.StaffComplimentaryPremium;

    /// Male accounts see female and LGBTQ+ (including stored transgender).
    /// Female, LGBTQ+ and other accounts see male.
    public static bool ViewerSees(string? viewerGender, string? candidateGender)
    {
        var viewer = CanonicalGender(viewerGender);
        var candidate = CanonicalGender(candidateGender);
        if (viewer is null || candidate is null) return false;
        return viewer switch
        {
            "male" => candidate is "female" or "lgbtq",
            _ => candidate == "male",
        };
    }

    static readonly Regex DisplayNamePattern = new(
        @"^[\p{L}][\p{L}\s'.-]*$",
        RegexOptions.CultureInvariant | RegexOptions.Compiled | RegexOptions.Singleline
    );

    public static string? ValidateDisplayName(string name)
    {
        if (name.Length < MinNameLength || name.Length > MaxNameLength)
        {
            return "Enter your first name.";
        }

        if (!DisplayNamePattern.IsMatch(name))
        {
            return "Use letters only.";
        }

        return null;
    }

    public static string? ValidateBio(string? bio)
    {
        if (bio is { Length: > MaxBioLength })
        {
            return $"Keep your bio under {MaxBioLength} characters.";
        }

        return null;
    }

    public static string[] NormalizeInterests(IEnumerable<string>? raw)
    {
        if (raw is null) return [];
        var seen = new HashSet<string>(StringComparer.Ordinal);
        var list = new List<string>();
        foreach (var item in raw)
        {
            var value = item.Trim();
            if (value.Length == 0 || !seen.Add(value)) continue;
            list.Add(value);
        }

        return [.. list];
    }

    public static string? ValidateInterests(IReadOnlyList<string> interests)
    {
        if (interests.Count < MinInterests)
        {
            return "Pick at least 3 interests.";
        }

        if (interests.Count > MaxInterests)
        {
            return "Pick fewer interests.";
        }

        if (interests.Any(interest => !AllowedInterests.Contains(interest)))
        {
            return "Choose from the listed interests.";
        }

        return null;
    }

    public static string? ValidateCity(string? city)
    {
        if (string.IsNullOrWhiteSpace(city) || !AllowedCities.Contains(city.Trim()))
        {
            return "Choose a city.";
        }

        return null;
    }

    public static string? ValidateGender(string? gender)
    {
        if (CanonicalGender(gender) is null)
        {
            return "Select who you are.";
        }

        return null;
    }
}
