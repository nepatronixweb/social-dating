namespace SocialDating.Api.Photos;

public sealed record PhotoListResponse(IReadOnlyList<PhotoResponse> Items);

public sealed record PhotoResponse(string Id, string Url, int SortOrder);

public sealed record ReorderPhotosRequest(string[] Ids);
