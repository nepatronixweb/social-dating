namespace SocialDating.Api.Discovery;

/// Nepal Standard Time is UTC+05:45 with no daylight saving.
public static class NepalTime
{
    public static readonly TimeSpan Offset = new(5, 45, 0);

    public static string DayKey(DateTimeOffset instant)
    {
        var nepal = instant.ToOffset(Offset);
        return $"{nepal.Year:D4}-{nepal.Month:D2}-{nepal.Day:D2}";
    }

    public static DateTimeOffset NextMidnightUtc(DateTimeOffset instant)
    {
        var nepal = instant.ToOffset(Offset);
        var next = new DateTimeOffset(nepal.Year, nepal.Month, nepal.Day, 0, 0, 0, Offset).AddDays(1);
        return next.ToUniversalTime();
    }
}
