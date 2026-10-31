namespace SocialDating.Api.Referrals;

public sealed class ReferralOptions
{
    public const string SectionName = "Referral";

    /// <summary>
    /// Public origin plus path prefix for invite links, with no trailing slash.
    /// Empty uses the app custom scheme so the API never invents a website.
    /// </summary>
    public string InviteBaseUrl { get; set; } = "";
}
