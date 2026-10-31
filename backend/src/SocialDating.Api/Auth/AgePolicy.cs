namespace SocialDating.Api.Auth;

/// Server-side 18+ rule. The birth date is stored privately and never returned.
public static class AgePolicy
{
    public const int MinimumAge = 18;
    public const int MaximumPlausibleAge = 120;
    public const int EarliestYear = 1900;

    public static int AgeOn(DateOnly birthDate, DateOnly today)
    {
        var age = today.Year - birthDate.Year;
        var hadBirthday =
            today.Month > birthDate.Month
            || (today.Month == birthDate.Month && today.Day >= birthDate.Day);
        if (!hadBirthday) age--;
        return age;
    }

    public static bool IsEligible(DateOnly birthDate, DateOnly today) =>
        AgeOn(birthDate, today) >= MinimumAge;

    public static string? Validate(DateOnly birthDate, DateOnly today)
    {
        if (birthDate.Year < EarliestYear) return "Enter a valid birth year.";
        if (birthDate > today) return "Your birth date can't be in the future.";
        if (AgeOn(birthDate, today) > MaximumPlausibleAge)
        {
            return "Enter a valid birth year.";
        }

        return null;
    }
}
