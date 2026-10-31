using Microsoft.AspNetCore.Mvc;
using SocialDating.Api.Auth;

namespace SocialDating.Api.Photos;

public static class PhotoEndpoints
{
    public static void MapPhotoEndpoints(this WebApplication app)
    {
        var me = app.MapGroup("/v1/me/photos").RequireAuthorization();
        me.MapGet("", ListMine);
        me.MapPost("", Upload).DisableAntiforgery();
        me.MapPatch("/order", Reorder);
        me.MapDelete("/{id:guid}", Delete);

        app.MapGet("/v1/media/{id:guid}", Open).AllowAnonymous();
    }

    static async Task<IResult> ListMine(
        HttpContext http,
        PhotoService photos,
        CancellationToken ct
    ) => Results.Json(new PhotoListResponse(await photos.ListMine(http.User.RequireAccountId(), ct)));

    static async Task<IResult> Upload(
        HttpContext http,
        PhotoService photos,
        IFormFile? file,
        CancellationToken ct
    )
    {
        if (file is null || file.Length == 0)
            throw new AuthException(400, "Choose a photo to upload.", "Choose a photo to upload.");

        await using var stream = file.OpenReadStream();
        var item = await photos.Upload(
            http.User.RequireAccountId(),
            stream,
            file.ContentType,
            file.Length,
            ct);
        return Results.Json(item);
    }

    static async Task<IResult> Reorder(
        HttpContext http,
        PhotoService photos,
        [FromBody] ReorderPhotosRequest body,
        CancellationToken ct
    )
    {
        await photos.Reorder(http.User.RequireAccountId(), body.Ids ?? [], ct);
        return Results.NoContent();
    }

    static async Task<IResult> Delete(
        HttpContext http,
        PhotoService photos,
        Guid id,
        CancellationToken ct
    )
    {
        await photos.Delete(http.User.RequireAccountId(), id, ct);
        return Results.NoContent();
    }

    static async Task<IResult> Open(
        PhotoService photos,
        Guid id,
        [FromQuery] long e,
        [FromQuery] string? s,
        CancellationToken ct
    )
    {
        var opened = await photos.OpenSigned(id, e, s ?? "", ct);
        if (opened is null) return Results.NotFound();
        return Results.File(opened.Value.Bytes, opened.Value.ContentType);
    }
}
