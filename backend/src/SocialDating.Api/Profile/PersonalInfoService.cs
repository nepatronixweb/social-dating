using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Photos;

namespace SocialDating.Api.Profile;

public interface IPersonalInfoService
{
    Task<PersonalInfoResponse> GetAsync(Guid accountId, CancellationToken ct);
    Task<PersonalInfoResponse> UpsertAsync(
        Guid accountId,
        UpsertPersonalInfoRequest body,
        CancellationToken ct
    );
}

public sealed class PersonalInfoService(AppDbContext db, PhotoService photos) : IPersonalInfoService
{
    public async Task<PersonalInfoResponse> GetAsync(Guid accountId, CancellationToken ct)
    {
        var account = await RequireAccount(accountId, ct);
        return await BuildAsync(account, ct);
    }

    public async Task<PersonalInfoResponse> UpsertAsync(
        Guid accountId,
        UpsertPersonalInfoRequest body,
        CancellationToken ct
    )
    {
        var account = await RequireAccount(accountId, ct);
        var now = DateTimeOffset.UtcNow;

        if (!string.IsNullOrWhiteSpace(body.FullName))
        {
            var name = body.FullName.Trim();
            var nameProblem = ProfileRules.ValidateDisplayName(name);
            if (nameProblem is not null)
            {
                throw new AuthException(400, "Invalid name.", nameProblem);
            }

            account.DisplayName = name;
        }

        if (!string.IsNullOrWhiteSpace(body.City))
        {
            account.City = body.City.Trim();
        }

        if (body.Interests is { Count: > 0 })
        {
            account.Interests = body.Interests.Where(i => !string.IsNullOrWhiteSpace(i))
                .Select(i => i.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Take(16)
                .ToArray();
        }

        if (!string.IsNullOrWhiteSpace(body.BirthDate)
            && DateOnly.TryParse(body.BirthDate, out var birth)
            && account.BirthDate is null)
        {
            account.BirthDate = birth;
        }

        // Keep Account.Gender for matching rules; store detail separately when provided.
        if (!string.IsNullOrWhiteSpace(body.Gender))
        {
            var mapped = MapAccountGender(body.Gender);
            if (mapped is not null) account.Gender = mapped;
        }

        account.UpdatedAt = now;

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.AccountId == accountId, ct);
        if (profile is null)
        {
            profile = new UserProfile { AccountId = accountId };
            db.UserProfiles.Add(profile);
        }

        profile.GenderDetail = TrimOrNull(body.Gender) ?? profile.GenderDetail;
        profile.InterestedIn = TrimOrNull(body.InterestedIn) ?? profile.InterestedIn;
        profile.HeightCm = body.HeightCm ?? profile.HeightCm;
        profile.BodyType = TrimOrNull(body.BodyType) ?? profile.BodyType;
        profile.HairColor = TrimOrNull(body.HairColor) ?? profile.HairColor;
        profile.EyeColor = TrimOrNull(body.EyeColor) ?? profile.EyeColor;
        profile.FitnessLifestyle = TrimOrNull(body.FitnessLifestyle) ?? profile.FitnessLifestyle;
        profile.EducationLevel = TrimOrNull(body.EducationLevel) ?? profile.EducationLevel;
        profile.College = TrimOrNull(body.College) ?? profile.College;
        profile.Profession = TrimOrNull(body.Profession) ?? profile.Profession;
        profile.Company = TrimOrNull(body.Company) ?? profile.Company;
        profile.JobTitle = TrimOrNull(body.JobTitle) ?? profile.JobTitle;
        if (body.Languages is not null)
        {
            profile.Languages = body.Languages.Where(l => !string.IsNullOrWhiteSpace(l))
                .Select(l => l.Trim())
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToArray();
        }
        profile.IncomeRange = TrimOrNull(body.IncomeRange) ?? profile.IncomeRange;
        profile.UpdatedAt = now;

        var lifestyle = await db.UserLifestyles.FirstOrDefaultAsync(p => p.AccountId == accountId, ct);
        if (lifestyle is null)
        {
            lifestyle = new UserLifestyle { AccountId = accountId };
            db.UserLifestyles.Add(lifestyle);
        }

        lifestyle.Drink = TrimOrNull(body.Drink) ?? lifestyle.Drink;
        lifestyle.Smoke = TrimOrNull(body.Smoke) ?? lifestyle.Smoke;
        lifestyle.Exercise = TrimOrNull(body.Exercise) ?? lifestyle.Exercise;
        lifestyle.FoodPreference = TrimOrNull(body.FoodPreference) ?? lifestyle.FoodPreference;
        lifestyle.Pets = TrimOrNull(body.Pets) ?? lifestyle.Pets;
        lifestyle.SleepSchedule = TrimOrNull(body.SleepSchedule) ?? lifestyle.SleepSchedule;
        lifestyle.SocialLifestyle = TrimOrNull(body.SocialLifestyle) ?? lifestyle.SocialLifestyle;
        lifestyle.UpdatedAt = now;

        var prefs = await db.UserPreferences.FirstOrDefaultAsync(p => p.AccountId == accountId, ct);
        if (prefs is null)
        {
            prefs = new UserPreference { AccountId = accountId };
            db.UserPreferences.Add(prefs);
        }

        prefs.LookingFor = TrimOrNull(body.LookingFor) ?? prefs.LookingFor;
        if (body.PreferredAgeMin is int minAge) prefs.PreferredAgeMin = minAge;
        if (body.PreferredAgeMax is int maxAge) prefs.PreferredAgeMax = maxAge;
        prefs.PreferredDistanceKm = body.PreferredDistanceKm ?? prefs.PreferredDistanceKm;
        prefs.PreferredLocation = TrimOrNull(body.PreferredLocation) ?? prefs.PreferredLocation;
        prefs.ChildrenPreference = TrimOrNull(body.ChildrenPreference) ?? prefs.ChildrenPreference;
        prefs.RelationshipStatus = TrimOrNull(body.RelationshipStatus) ?? prefs.RelationshipStatus;
        prefs.MeetFrequency = TrimOrNull(body.MeetFrequency) ?? prefs.MeetFrequency;
        prefs.UpdatedAt = now;

        var personality = await db.UserPersonalities.FirstOrDefaultAsync(
            p => p.AccountId == accountId,
            ct
        );
        if (personality is null)
        {
            personality = new UserPersonality { AccountId = accountId };
            db.UserPersonalities.Add(personality);
        }

        personality.Personality = TrimOrNull(body.Personality) ?? personality.Personality;
        personality.PerfectWeekend = TrimOrNull(body.PerfectWeekend) ?? personality.PerfectWeekend;
        personality.LoveLanguage = TrimOrNull(body.LoveLanguage) ?? personality.LoveLanguage;
        personality.CommunicationStyle =
            TrimOrNull(body.CommunicationStyle) ?? personality.CommunicationStyle;
        personality.IdealFirstDate = TrimOrNull(body.IdealFirstDate) ?? personality.IdealFirstDate;
        personality.UpdatedAt = now;

        if (body.Prompts is not null)
        {
            var existing = await db.UserPrompts.Where(p => p.AccountId == accountId).ToListAsync(ct);
            db.UserPrompts.RemoveRange(existing);
            var order = 0;
            foreach (var prompt in body.Prompts.Take(3))
            {
                var key = TrimOrNull(prompt.PromptKey);
                var answer = TrimOrNull(prompt.Answer);
                if (key is null || answer is null) continue;
                db.UserPrompts.Add(
                    new UserPrompt
                    {
                        Id = Guid.NewGuid(),
                        AccountId = accountId,
                        PromptKey = key,
                        Answer = answer.Length > 200 ? answer[..200] : answer,
                        SortOrder = order++,
                        UpdatedAt = now,
                    }
                );
            }
        }

        var verification = await db.UserVerifications.FirstOrDefaultAsync(
            p => p.AccountId == accountId,
            ct
        );
        if (verification is null)
        {
            db.UserVerifications.Add(
                new UserVerification
                {
                    AccountId = accountId,
                    PhoneVerified = true,
                    Status = "phone_verified",
                    UpdatedAt = now,
                }
            );
        }

        await db.SaveChangesAsync(ct);
        return await BuildAsync(account, ct);
    }

    async Task<PersonalInfoResponse> BuildAsync(Account account, CancellationToken ct)
    {
        var accountId = account.Id;
        var profile = await db.UserProfiles.AsNoTracking()
            .FirstOrDefaultAsync(p => p.AccountId == accountId, ct);
        var lifestyle = await db.UserLifestyles.AsNoTracking()
            .FirstOrDefaultAsync(p => p.AccountId == accountId, ct);
        var prefs = await db.UserPreferences.AsNoTracking()
            .FirstOrDefaultAsync(p => p.AccountId == accountId, ct);
        var personality = await db.UserPersonalities.AsNoTracking()
            .FirstOrDefaultAsync(p => p.AccountId == accountId, ct);
        var prompts = await db.UserPrompts.AsNoTracking()
            .Where(p => p.AccountId == accountId)
            .OrderBy(p => p.SortOrder)
            .Select(p => new PersonalPromptDto(p.PromptKey, p.Answer))
            .ToListAsync(ct);
        var photoCount = await photos.CountProfileAsync(accountId, ct);

        return new PersonalInfoResponse(
            account.DisplayName,
            account.BirthDate?.ToString("yyyy-MM-dd"),
            profile?.GenderDetail ?? MapDetailGender(account.Gender),
            profile?.InterestedIn,
            photoCount,
            account.City,
            PhoneE164.Mask(account.PhoneE164),
            profile?.HeightCm,
            profile?.BodyType,
            profile?.HairColor,
            profile?.EyeColor,
            profile?.FitnessLifestyle,
            lifestyle?.Drink,
            lifestyle?.Smoke,
            lifestyle?.Exercise,
            lifestyle?.FoodPreference,
            lifestyle?.Pets,
            lifestyle?.SleepSchedule,
            lifestyle?.SocialLifestyle,
            profile?.EducationLevel,
            profile?.College,
            profile?.Profession,
            profile?.Company,
            profile?.JobTitle,
            profile?.Languages ?? [],
            profile?.IncomeRange,
            prefs?.LookingFor,
            prefs?.PreferredAgeMin,
            prefs?.PreferredAgeMax,
            prefs?.PreferredDistanceKm,
            prefs?.PreferredLocation,
            prefs?.ChildrenPreference,
            prefs?.RelationshipStatus,
            prefs?.MeetFrequency,
            account.Interests,
            personality?.Personality,
            personality?.PerfectWeekend,
            personality?.LoveLanguage,
            personality?.CommunicationStyle,
            personality?.IdealFirstDate,
            prompts
        );
    }

    async Task<Account> RequireAccount(Guid accountId, CancellationToken ct)
    {
        var account = await db.Accounts.FirstOrDefaultAsync(a => a.Id == accountId, ct);
        if (account is null)
        {
            throw new AuthException(401, "Please sign in again.", "The session is no longer valid.");
        }

        return account;
    }

    static string? TrimOrNull(string? value)
    {
        var trimmed = value?.Trim();
        return string.IsNullOrEmpty(trimmed) ? null : trimmed;
    }

    static string? MapAccountGender(string detail) =>
        detail.Trim().ToLowerInvariant() switch
        {
            "male" => "male",
            "female" => "female",
            "non_binary" => "lgbtq",
            "self_describe" => "other",
            _ => null,
        };

    static string? MapDetailGender(string? accountGender) =>
        accountGender switch
        {
            "male" => "male",
            "female" => "female",
            "lgbtq" => "non_binary",
            "other" => "self_describe",
            _ => null,
        };
}
