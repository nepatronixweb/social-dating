namespace SocialDating.Api.Hosting;

public sealed class CorsSettings
{
    public const string SectionName = "Cors";

    /// <summary>Exact origins for Flutter web or a hosted admin. Empty is fine for native apps.</summary>
    public string[] AllowedOrigins { get; set; } = [];

    /// <summary>Allows localhost / 127.0.0.1 for a local production-shaped web client.</summary>
    public bool AllowLocalhost { get; set; } = true;
}

public static class OriginPolicy
{
    public static bool IsAllowed(string? origin, CorsSettings settings)
    {
        if (string.IsNullOrWhiteSpace(origin)) return false;
        if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri)) return false;
        if (uri.Scheme is not "http" and not "https") return false;

        foreach (var allowed in settings.AllowedOrigins)
        {
            if (string.Equals(allowed, origin, StringComparison.OrdinalIgnoreCase)) return true;
        }

        if (!settings.AllowLocalhost) return false;
        return uri.Host is "localhost" or "127.0.0.1";
    }
}
