namespace SocialDating.Api.Photos;

public sealed class PhotoOptions
{
    public const string SectionName = "Photos";

    public string RootPath { get; set; } = "";
    public int MaxCount { get; set; } = 6;
    public int MaxBytes { get; set; } = 5_000_000;
    public int UrlTtlMinutes { get; set; } = 120;
}
