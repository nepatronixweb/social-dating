using System.Security.Claims;
using System.Text.Json;

namespace SocialDating.Api.Admin;

public static class AdminComplianceEndpoints
{
    public static void MapAdminComplianceEndpoints(
        this RouteGroupBuilder read,
        RouteGroupBuilder super
    )
    {
        read.MapGet("/users/{id:guid}/export.json", ExportUser);
        super.MapPost("/users/{id:guid}/erase", EraseUser);
    }

    static async Task<IResult> ExportUser(
        Guid id,
        IAdminComplianceService compliance,
        CancellationToken ct
    )
    {
        var payload = await compliance.ExportUserAsync(id, ct);
        var json = JsonSerializer.Serialize(
            payload,
            new JsonSerializerOptions
            {
                PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
                WriteIndented = true,
            }
        );
        var fileName = $"user-{id:N}-export.json";
        return Results.File(
            System.Text.Encoding.UTF8.GetBytes(json),
            "application/json",
            fileName
        );
    }

    static async Task<IResult> EraseUser(
        Guid id,
        EraseUserRequest body,
        HttpContext http,
        IAdminComplianceService compliance,
        CancellationToken ct
    ) => Results.Ok(await compliance.EraseUserAsync(id, body, http.User, ct));
}
