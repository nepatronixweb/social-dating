using System.Text.Json.Serialization;

namespace SocialDating.Api.Auth;

public sealed record RequestCodeRequest(string Phone);

public sealed record RequestCodeResponse(int RetryAfterSeconds, bool Registered = false);

public sealed record VerifyCodeRequest(
    string Phone,
    string Code,
    string? ReferralCode = null,
    [property: JsonPropertyName("login")] bool Login = false
);

public sealed record AccountStateResponse(
    string Id,
    bool TermsAccepted,
    bool? IsAgeEligible,
    string? DisplayName,
    string? Gender = null
);

public sealed record AuthVerifyResponse(
    AccountStateResponse Account,
    string AccessToken,
    string RefreshToken,
    DateTimeOffset ExpiresAt
);

public sealed record RefreshRequest(string RefreshToken);

public sealed record SubmitAgeRequest(string BirthDate);

public sealed record SetGenderRequest(string Gender);

public sealed record CompleteProfileRequest(
    string DisplayName,
    string? Bio = null,
    List<string>? Interests = null,
    string? City = null,
    string? Gender = null
);
