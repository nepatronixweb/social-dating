using System.ComponentModel.DataAnnotations;

namespace SocialDating.Api.Data;

public sealed class Account
{
    public Guid Id { get; set; }

    /// <summary>E.164, never returned on public JSON.</summary>
    [MaxLength(16)]
    public required string PhoneE164 { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
    public DateTimeOffset? DeletedAt { get; set; }

    public DateTimeOffset? TermsAcceptedAt { get; set; }

    /// <summary>Null until a birth date has been submitted once.</summary>
    public bool? AgeEligible { get; set; }
    public DateTimeOffset? AgeCheckedAt { get; set; }

    /// <summary>Private. Used to compute public age. Never returned on JSON.</summary>
    public DateOnly? BirthDate { get; set; }

    [MaxLength(30)]
    public string? DisplayName { get; set; }

    [MaxLength(300)]
    public string? Bio { get; set; }

    public string[] Interests { get; set; } = [];

    [MaxLength(40)]
    public string? City { get; set; }

    /// <summary>male, female, lgbtq, other (legacy woman/man/nonBinary/transgender still read). Never a phone or birth date.</summary>
    [MaxLength(16)]
    public string? Gender { get; set; }

    /// <summary>Public invite code. Unique when set. Never a phone number.</summary>
    [MaxLength(12)]
    public string? ReferralCode { get; set; }

    public Guid? ReferredByAccountId { get; set; }

    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
}

public sealed class ReferralInvite
{
    public Guid Id { get; set; }
    public Guid ReferrerAccountId { get; set; }
    public Guid InviteeAccountId { get; set; }

    [MaxLength(12)]
    public required string CodeUsed { get; set; }

    /// <summary>joined, purchased, or refunded.</summary>
    [MaxLength(16)]
    public required string Status { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? PurchasedAt { get; set; }
    public DateTimeOffset? RefundedAt { get; set; }
}

public sealed class ReferralCommission
{
    public Guid Id { get; set; }
    public Guid InviteId { get; set; }
    public Guid ReferrerAccountId { get; set; }
    public int AmountPaisa { get; set; }

    /// <summary>pending, approved, reversed, or paid.</summary>
    [MaxLength(16)]
    public required string Status { get; set; }

    [MaxLength(300)]
    public string Detail { get; set; } = "";

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ResolvedAt { get; set; }
}

public sealed class Swipe
{
    public Guid Id { get; set; }
    public Guid FromAccountId { get; set; }
    public Guid ToAccountId { get; set; }

    /// <summary>left or right, matching the Flutter enum names.</summary>
    [MaxLength(8)]
    public required string Direction { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? UndoneAt { get; set; }
    public Guid? MatchId { get; set; }
}

public sealed class MatchPair
{
    public Guid Id { get; set; }
    public Guid AccountLowId { get; set; }
    public Guid AccountHighId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? UnmatchedAt { get; set; }
    public bool SeenByLow { get; set; }
    public bool SeenByHigh { get; set; }
}

public sealed class SwipeDay
{
    public Guid AccountId { get; set; }
    public required string DayKey { get; set; }
    public int PreviewUsed { get; set; }
    public int DailyUsed { get; set; }
}

public sealed class Block
{
    public Guid BlockerAccountId { get; set; }
    public Guid BlockedAccountId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class Message
{
    public Guid Id { get; set; }
    public Guid MatchId { get; set; }
    public Guid SenderAccountId { get; set; }

    [MaxLength(500)]
    public required string Body { get; set; }

    public Guid? PhotoId { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class InboxNotification
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }

    /// <summary>match, like, message, or system.</summary>
    [MaxLength(16)]
    public required string Type { get; set; }

    [MaxLength(80)]
    public required string Title { get; set; }

    [MaxLength(300)]
    public required string Body { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ReadAt { get; set; }
    public Guid? ActorAccountId { get; set; }
    public Guid? MatchId { get; set; }
}

public sealed class ChatMember
{
    public Guid MatchId { get; set; }
    public Guid AccountId { get; set; }
    public DateTimeOffset? LastReadAt { get; set; }
    public bool Muted { get; set; }
    public bool Hidden { get; set; }
}

public sealed class Photo
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public int SortOrder { get; set; }

    [MaxLength(64)]
    public required string ContentType { get; set; }

    /// <summary>profile (album) or chat (message attachment).</summary>
    [MaxLength(16)]
    public string Kind { get; set; } = "profile";

    public int ByteSize { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
}

public sealed class WalletEntry
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public int Points { get; set; }

    /// <summary>promotional or earned.</summary>
    [MaxLength(16)]
    public required string Bucket { get; set; }

    /// <summary>welcomeBonus, swipeSpend, messageSpend, messageReceived, withdrawalHold, withdrawalRelease, other.</summary>
    [MaxLength(32)]
    public required string Kind { get; set; }

    [MaxLength(80)]
    public required string Title { get; set; }

    [MaxLength(300)]
    public string Detail { get; set; } = "";

    public DateTimeOffset OccurredAt { get; set; }

    [MaxLength(64)]
    public string? SourceId { get; set; }
}

public sealed class WithdrawalRequest
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public int Points { get; set; }
    public int FeePoints { get; set; }
    public int NetPoints { get; set; }

    /// <summary>recorded, cancelled, or declined. Never paid.</summary>
    [MaxLength(16)]
    public required string Status { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset? ResolvedAt { get; set; }
}

public sealed class OtpChallenge
{
    public Guid Id { get; set; }

    [MaxLength(16)]
    public required string PhoneE164 { get; set; }

    public required byte[] CodeSalt { get; set; }
    public required byte[] CodeHash { get; set; }

    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? ConsumedAt { get; set; }
    public int AttemptCount { get; set; }
}

public sealed class RefreshToken
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }
    public Account Account { get; set; } = null!;

    public required byte[] TokenHash { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset ExpiresAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
}

/// Extended personal details beyond the core [Account] fields.
public sealed class UserProfile
{
    public Guid AccountId { get; set; }

    /// <summary>male, female, non_binary, self_describe.</summary>
    [MaxLength(24)]
    public string? GenderDetail { get; set; }

    /// <summary>men, women, everyone.</summary>
    [MaxLength(16)]
    public string? InterestedIn { get; set; }

    public int? HeightCm { get; set; }

    [MaxLength(24)]
    public string? BodyType { get; set; }

    [MaxLength(24)]
    public string? HairColor { get; set; }

    [MaxLength(24)]
    public string? EyeColor { get; set; }

    [MaxLength(24)]
    public string? FitnessLifestyle { get; set; }

    [MaxLength(24)]
    public string? EducationLevel { get; set; }

    [MaxLength(120)]
    public string? College { get; set; }

    [MaxLength(40)]
    public string? Profession { get; set; }

    [MaxLength(120)]
    public string? Company { get; set; }

    [MaxLength(80)]
    public string? JobTitle { get; set; }

    public string[] Languages { get; set; } = [];

    [MaxLength(24)]
    public string? IncomeRange { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class UserLifestyle
{
    public Guid AccountId { get; set; }

    [MaxLength(24)]
    public string? Drink { get; set; }

    [MaxLength(24)]
    public string? Smoke { get; set; }

    [MaxLength(24)]
    public string? Exercise { get; set; }

    [MaxLength(24)]
    public string? FoodPreference { get; set; }

    [MaxLength(24)]
    public string? Pets { get; set; }

    [MaxLength(24)]
    public string? SleepSchedule { get; set; }

    [MaxLength(24)]
    public string? SocialLifestyle { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class UserPreference
{
    public Guid AccountId { get; set; }

    [MaxLength(24)]
    public string? LookingFor { get; set; }

    public int PreferredAgeMin { get; set; } = 18;
    public int PreferredAgeMax { get; set; } = 100;
    public int? PreferredDistanceKm { get; set; }

    [MaxLength(24)]
    public string? PreferredLocation { get; set; }

    [MaxLength(24)]
    public string? ChildrenPreference { get; set; }

    [MaxLength(24)]
    public string? RelationshipStatus { get; set; }

    [MaxLength(24)]
    public string? MeetFrequency { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class UserPersonality
{
    public Guid AccountId { get; set; }

    [MaxLength(24)]
    public string? Personality { get; set; }

    [MaxLength(24)]
    public string? PerfectWeekend { get; set; }

    [MaxLength(24)]
    public string? LoveLanguage { get; set; }

    [MaxLength(24)]
    public string? CommunicationStyle { get; set; }

    [MaxLength(24)]
    public string? IdealFirstDate { get; set; }

    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class UserPrompt
{
    public Guid Id { get; set; }
    public Guid AccountId { get; set; }

    [MaxLength(40)]
    public required string PromptKey { get; set; }

    [MaxLength(200)]
    public required string Answer { get; set; }

    public int SortOrder { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class UserVerification
{
    public Guid AccountId { get; set; }
    public bool PhoneVerified { get; set; }
    public bool SelfieVerified { get; set; }

    [MaxLength(24)]
    public string Status { get; set; } = "unverified";

    public DateTimeOffset UpdatedAt { get; set; }
}

public sealed class UserPrivacy
{
    public Guid AccountId { get; set; }
    public bool ShowDistance { get; set; } = true;
    public bool ShowOnlineStatus { get; set; } = true;
    public bool Discoverable { get; set; } = true;

    [MaxLength(24)]
    public string Visibility { get; set; } = "everyone";

    public DateTimeOffset UpdatedAt { get; set; }
}
