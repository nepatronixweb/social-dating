namespace SocialDating.Api.Auth;

public sealed class AuthOptions
{
    public const string SectionName = "Auth";

    public int OtpTtlMinutes { get; set; } = 5;
    public int OtpMaxAttempts { get; set; } = 5;
    public int ResendCooldownSeconds { get; set; } = 30;
    public int AccessTokenMinutes { get; set; } = 15;
    public int RefreshTokenDays { get; set; } = 30;

    /// <summary>
    /// Development only. When true, a generated OTP is written to the
    /// server log. Never enable in production. The static development code
    /// is never logged.
    /// </summary>
    public bool LogOtps { get; set; }

    /// <summary>
    /// When true, a random OTP is issued and an SMS provider must send it.
    /// SMS is not wired yet, so this stays false.
    /// </summary>
    public bool SmsEnabled { get; set; }

    /// <summary>
    /// Accepted while [SmsEnabled] is false. Six digits. Not a secret.
    /// </summary>
    public string StaticOtp { get; set; } = "123456";
}
