namespace SocialDating.Api.Auth;

public sealed class AuthException(int statusCode, string title, string detail, int? retryAfterSeconds = null)
    : Exception(detail)
{
    public int StatusCode { get; } = statusCode;
    public string Title { get; } = title;
    public string Detail { get; } = detail;
    public int? RetryAfterSeconds { get; } = retryAfterSeconds;
}
