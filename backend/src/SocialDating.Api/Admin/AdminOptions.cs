namespace SocialDating.Api.Admin;

public sealed class AdminOptions
{
    public const string SectionName = "Admin";

    /// <summary>Bootstrapped on startup when no staff users exist (development).</summary>
    public string? BootstrapEmail { get; set; }

    public string? BootstrapPassword { get; set; }

    public string BootstrapDisplayName { get; set; } = "Superadmin";

    public string BootstrapRole { get; set; } = "superadmin";

    public int AccessTokenMinutes { get; set; } = 480;

    /// <summary>
    /// Absolute charge points at/above this require a second staff approval before refund.
    /// Default 500 (= 5.00 points).
    /// </summary>
    public int RefundDualControlThresholdPoints { get; set; } = 500;

    /// <summary>Open/investigating reports older than this are overdue (hours).</summary>
    public int ReportSlaHours { get; set; } = 24;

    /// <summary>Open reports past this age are due soon (hours), before hard overdue.</summary>
    public int ReportSlaWarnHours { get; set; } = 18;

    /// <summary>Open appeals older than this are overdue (hours).</summary>
    public int AppealSlaHours { get; set; } = 48;
}
