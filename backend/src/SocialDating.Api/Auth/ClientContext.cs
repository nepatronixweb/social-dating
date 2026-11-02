namespace SocialDating.Api.Auth;

public readonly record struct ClientContext(string? IpAddress, string? DeviceId, string? UserAgent)
{
    public static ClientContext FromHttp(HttpContext http)
    {
        var ip = http.Connection.RemoteIpAddress?.ToString();
        var forwarded = http.Request.Headers["X-Forwarded-For"].FirstOrDefault();
        if (!string.IsNullOrWhiteSpace(forwarded))
        {
            ip = forwarded.Split(',')[0].Trim();
        }

        if (ip is { Length: > 64 }) ip = ip[..64];

        var device = http.Request.Headers["X-Device-Id"].FirstOrDefault()?.Trim();
        if (device is { Length: > 128 }) device = device[..128];
        if (string.IsNullOrWhiteSpace(device)) device = null;

        var ua = http.Request.Headers.UserAgent.ToString();
        if (string.IsNullOrWhiteSpace(ua)) ua = null;
        else if (ua.Length > 256) ua = ua[..256];

        return new ClientContext(ip, device, ua);
    }
}
