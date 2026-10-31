using Microsoft.AspNetCore.Diagnostics;

namespace SocialDating.Api.Auth;

public sealed class AuthExceptionHandler : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(
        HttpContext context,
        Exception exception,
        CancellationToken cancellationToken
    )
    {
        if (exception is not AuthException error) return false;

        if (error.RetryAfterSeconds is int retry)
        {
            context.Response.Headers.RetryAfter = retry.ToString();
        }

        await Results
            .Problem(
                title: error.Title,
                detail: error.Detail,
                statusCode: error.StatusCode,
                type: $"urn:socialdating:problem:{error.StatusCode}"
            )
            .ExecuteAsync(context);
        return true;
    }
}
