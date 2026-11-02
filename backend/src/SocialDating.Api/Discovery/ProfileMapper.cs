using SocialDating.Api.Auth;
using SocialDating.Api.Data;

namespace SocialDating.Api.Discovery;

public static class ProfileMapper
{
    public static PublicProfileResponse? ToPublic(
        Account account,
        DateTimeOffset now,
        IReadOnlyList<string>? photoUrls = null,
        int? spendablePoints = null)
    {
        if (account.DisplayName is null
            || account.BirthDate is null
            || account.City is null
            || account.Gender is null)
        {
            return null;
        }

        var urls = photoUrls?.ToArray() ?? [];
        var today = DateOnly.FromDateTime(now.UtcDateTime);
        return new PublicProfileResponse(
            account.Id.ToString(),
            account.DisplayName,
            AgePolicy.AgeOn(account.BirthDate.Value, today),
            account.City,
            account.Bio ?? "",
            account.Interests,
            false,
            false,
            urls.Length,
            null,
            null,
            account.Gender,
            null,
            urls,
            spendablePoints
        );
    }
}
