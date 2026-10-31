using System.Text.Json;
using Microsoft.EntityFrameworkCore;

namespace SocialDating.Api.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    static readonly JsonSerializerOptions InterestsJson = new();

    public DbSet<Account> Accounts => Set<Account>();
    public DbSet<OtpChallenge> OtpChallenges => Set<OtpChallenge>();
    public DbSet<RefreshToken> RefreshTokens => Set<RefreshToken>();
    public DbSet<Swipe> Swipes => Set<Swipe>();
    public DbSet<MatchPair> Matches => Set<MatchPair>();
    public DbSet<SwipeDay> SwipeDays => Set<SwipeDay>();
    public DbSet<Block> Blocks => Set<Block>();
    public DbSet<Message> Messages => Set<Message>();
    public DbSet<ChatMember> ChatMembers => Set<ChatMember>();
    public DbSet<WalletEntry> WalletEntries => Set<WalletEntry>();
    public DbSet<Photo> Photos => Set<Photo>();
    public DbSet<InboxNotification> InboxNotifications => Set<InboxNotification>();
    public DbSet<ReferralInvite> ReferralInvites => Set<ReferralInvite>();
    public DbSet<ReferralCommission> ReferralCommissions => Set<ReferralCommission>();
    public DbSet<WithdrawalRequest> WithdrawalRequests => Set<WithdrawalRequest>();
    public DbSet<UserProfile> UserProfiles => Set<UserProfile>();
    public DbSet<UserLifestyle> UserLifestyles => Set<UserLifestyle>();
    public DbSet<UserPreference> UserPreferences => Set<UserPreference>();
    public DbSet<UserPersonality> UserPersonalities => Set<UserPersonality>();
    public DbSet<UserPrompt> UserPrompts => Set<UserPrompt>();
    public DbSet<UserVerification> UserVerifications => Set<UserVerification>();
    public DbSet<UserPrivacy> UserPrivacies => Set<UserPrivacy>();

    protected override void OnModelCreating(ModelBuilder model)
    {
        model.Entity<Account>(entity =>
        {
            entity.ToTable("accounts");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.PhoneE164).IsUnique();
            entity.Property(x => x.PhoneE164).HasColumnName("phone_e164");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            entity.Property(x => x.DeletedAt).HasColumnName("deleted_at");
            entity.Property(x => x.TermsAcceptedAt).HasColumnName("terms_accepted_at");
            entity.Property(x => x.AgeEligible).HasColumnName("age_eligible");
            entity.Property(x => x.AgeCheckedAt).HasColumnName("age_checked_at");
            entity.Property(x => x.BirthDate).HasColumnName("birth_date");
            entity.Property(x => x.DisplayName).HasColumnName("display_name");
            entity.Property(x => x.Bio).HasColumnName("bio");
            entity.Property(x => x.City).HasColumnName("city");
            entity.Property(x => x.Gender).HasColumnName("gender");
            entity.Property(x => x.ReferralCode).HasColumnName("referral_code");
            entity.Property(x => x.ReferredByAccountId).HasColumnName("referred_by_account_id");
            entity.HasIndex(x => x.ReferralCode).IsUnique();
            entity.Property(x => x.Interests)
                .HasColumnName("interests")
                .HasMaxLength(800)
                .HasConversion(
                    v => SerializeInterests(v),
                    v => DeserializeInterests(v)
                );
            entity.HasQueryFilter(x => x.DeletedAt == null);
        });

        model.Entity<OtpChallenge>(entity =>
        {
            entity.ToTable("otp_challenges");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.PhoneE164, x.CreatedAt });
            entity.Property(x => x.PhoneE164).HasColumnName("phone_e164");
            entity.Property(x => x.CodeSalt).HasColumnName("code_salt");
            entity.Property(x => x.CodeHash).HasColumnName("code_hash");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            entity.Property(x => x.ConsumedAt).HasColumnName("consumed_at");
            entity.Property(x => x.AttemptCount).HasColumnName("attempt_count");
        });

        model.Entity<RefreshToken>(entity =>
        {
            entity.ToTable("refresh_tokens");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => x.TokenHash).IsUnique();
            entity.HasIndex(x => x.AccountId);
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.TokenHash).HasColumnName("token_hash");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.ExpiresAt).HasColumnName("expires_at");
            entity.Property(x => x.RevokedAt).HasColumnName("revoked_at");
            entity.HasOne(x => x.Account)
                .WithMany(x => x.RefreshTokens)
                .HasForeignKey(x => x.AccountId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        model.Entity<Swipe>(entity =>
        {
            entity.ToTable("swipes");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.FromAccountId, x.ToAccountId });
            entity.HasIndex(x => x.FromAccountId);
            entity.Property(x => x.FromAccountId).HasColumnName("from_account_id");
            entity.Property(x => x.ToAccountId).HasColumnName("to_account_id");
            entity.Property(x => x.Direction).HasColumnName("direction");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.UndoneAt).HasColumnName("undone_at");
            entity.Property(x => x.MatchId).HasColumnName("match_id");
        });

        model.Entity<MatchPair>(entity =>
        {
            entity.ToTable("matches");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.AccountLowId, x.AccountHighId });
            entity.Property(x => x.AccountLowId).HasColumnName("account_low_id");
            entity.Property(x => x.AccountHighId).HasColumnName("account_high_id");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.UnmatchedAt).HasColumnName("unmatched_at");
            entity.Property(x => x.SeenByLow).HasColumnName("seen_by_low");
            entity.Property(x => x.SeenByHigh).HasColumnName("seen_by_high");
        });

        model.Entity<SwipeDay>(entity =>
        {
            entity.ToTable("swipe_days");
            entity.HasKey(x => new { x.AccountId, x.DayKey });
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.DayKey).HasColumnName("day_key").HasMaxLength(10);
            entity.Property(x => x.PreviewUsed).HasColumnName("preview_used");
            entity.Property(x => x.DailyUsed).HasColumnName("daily_used");
        });

        model.Entity<Block>(entity =>
        {
            entity.ToTable("blocks");
            entity.HasKey(x => new { x.BlockerAccountId, x.BlockedAccountId });
            entity.HasIndex(x => x.BlockedAccountId);
            entity.Property(x => x.BlockerAccountId).HasColumnName("blocker_account_id");
            entity.Property(x => x.BlockedAccountId).HasColumnName("blocked_account_id");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
        });

        model.Entity<Message>(entity =>
        {
            entity.ToTable("messages");
            entity.HasKey(x => x.Id);
            entity.HasIndex(x => new { x.MatchId, x.CreatedAt });
            entity.Property(x => x.MatchId).HasColumnName("match_id");
            entity.Property(x => x.SenderAccountId).HasColumnName("sender_account_id");
            entity.Property(x => x.Body).HasColumnName("body");
            entity.Property(x => x.PhotoId).HasColumnName("photo_id");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
        });

        model.Entity<ChatMember>(entity =>
        {
            entity.ToTable("chat_members");
            entity.HasKey(x => new { x.MatchId, x.AccountId });
            entity.Property(x => x.MatchId).HasColumnName("match_id");
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.LastReadAt).HasColumnName("last_read_at");
            entity.Property(x => x.Muted).HasColumnName("muted");
            entity.Property(x => x.Hidden).HasColumnName("hidden");
        });

        model.Entity<Photo>(entity =>
        {
            entity.ToTable("photos");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasColumnName("id");
            entity.HasIndex(x => new { x.AccountId, x.SortOrder });
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.SortOrder).HasColumnName("sort_order");
            entity.Property(x => x.ContentType).HasColumnName("content_type");
            entity.Property(x => x.Kind).HasColumnName("kind").HasMaxLength(16).HasDefaultValue("profile");
            entity.Property(x => x.ByteSize).HasColumnName("byte_size");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
        });

        model.Entity<WalletEntry>(entity =>
        {
            entity.ToTable("wallet_entries");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasColumnName("id");
            entity.HasIndex(x => new { x.AccountId, x.OccurredAt });
            entity.HasIndex(x => new { x.AccountId, x.Kind });
            entity.HasIndex(x => new { x.AccountId, x.SourceId });
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.Points).HasColumnName("points");
            entity.Property(x => x.Bucket).HasColumnName("bucket");
            entity.Property(x => x.Kind).HasColumnName("kind");
            entity.Property(x => x.Title).HasColumnName("title");
            entity.Property(x => x.Detail).HasColumnName("detail");
            entity.Property(x => x.OccurredAt).HasColumnName("occurred_at");
            entity.Property(x => x.SourceId).HasColumnName("source_id");
        });

        model.Entity<InboxNotification>(entity =>
        {
            entity.ToTable("inbox_notifications");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasColumnName("id");
            entity.HasIndex(x => new { x.AccountId, x.CreatedAt });
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.Type).HasColumnName("type").HasMaxLength(16);
            entity.Property(x => x.Title).HasColumnName("title").HasMaxLength(80);
            entity.Property(x => x.Body).HasColumnName("body").HasMaxLength(300);
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.ReadAt).HasColumnName("read_at");
            entity.Property(x => x.ActorAccountId).HasColumnName("actor_account_id");
            entity.Property(x => x.MatchId).HasColumnName("match_id");
        });

        model.Entity<ReferralInvite>(entity =>
        {
            entity.ToTable("referral_invites");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasColumnName("id");
            entity.HasIndex(x => x.InviteeAccountId).IsUnique();
            entity.HasIndex(x => x.ReferrerAccountId);
            entity.Property(x => x.ReferrerAccountId).HasColumnName("referrer_account_id");
            entity.Property(x => x.InviteeAccountId).HasColumnName("invitee_account_id");
            entity.Property(x => x.CodeUsed).HasColumnName("code_used");
            entity.Property(x => x.Status).HasColumnName("status");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.PurchasedAt).HasColumnName("purchased_at");
            entity.Property(x => x.RefundedAt).HasColumnName("refunded_at");
        });

        model.Entity<ReferralCommission>(entity =>
        {
            entity.ToTable("referral_commissions");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasColumnName("id");
            entity.HasIndex(x => x.InviteId).IsUnique();
            entity.HasIndex(x => x.ReferrerAccountId);
            entity.Property(x => x.InviteId).HasColumnName("invite_id");
            entity.Property(x => x.ReferrerAccountId).HasColumnName("referrer_account_id");
            entity.Property(x => x.AmountPaisa).HasColumnName("amount_paisa");
            entity.Property(x => x.Status).HasColumnName("status");
            entity.Property(x => x.Detail).HasColumnName("detail");
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.ResolvedAt).HasColumnName("resolved_at");
        });

        model.Entity<WithdrawalRequest>(entity =>
        {
            entity.ToTable("withdrawal_requests");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasColumnName("id");
            entity.HasIndex(x => x.AccountId);
            entity.HasIndex(x => new { x.AccountId, x.Status });
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.Points).HasColumnName("points");
            entity.Property(x => x.FeePoints).HasColumnName("fee_points");
            entity.Property(x => x.NetPoints).HasColumnName("net_points");
            entity.Property(x => x.Status).HasColumnName("status").HasMaxLength(16);
            entity.Property(x => x.CreatedAt).HasColumnName("created_at");
            entity.Property(x => x.ResolvedAt).HasColumnName("resolved_at");
        });

        model.Entity<UserProfile>(entity =>
        {
            entity.ToTable("user_profiles");
            entity.HasKey(x => x.AccountId);
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.GenderDetail).HasColumnName("gender_detail");
            entity.Property(x => x.InterestedIn).HasColumnName("interested_in");
            entity.Property(x => x.HeightCm).HasColumnName("height_cm");
            entity.Property(x => x.BodyType).HasColumnName("body_type");
            entity.Property(x => x.HairColor).HasColumnName("hair_color");
            entity.Property(x => x.EyeColor).HasColumnName("eye_color");
            entity.Property(x => x.FitnessLifestyle).HasColumnName("fitness_lifestyle");
            entity.Property(x => x.EducationLevel).HasColumnName("education_level");
            entity.Property(x => x.College).HasColumnName("college");
            entity.Property(x => x.Profession).HasColumnName("profession");
            entity.Property(x => x.Company).HasColumnName("company");
            entity.Property(x => x.JobTitle).HasColumnName("job_title");
            entity.Property(x => x.IncomeRange).HasColumnName("income_range");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
            entity.Property(x => x.Languages)
                .HasColumnName("languages")
                .HasMaxLength(400)
                .HasConversion(
                    v => SerializeInterests(v),
                    v => DeserializeInterests(v)
                );
        });

        model.Entity<UserLifestyle>(entity =>
        {
            entity.ToTable("user_lifestyles");
            entity.HasKey(x => x.AccountId);
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.Drink).HasColumnName("drink");
            entity.Property(x => x.Smoke).HasColumnName("smoke");
            entity.Property(x => x.Exercise).HasColumnName("exercise");
            entity.Property(x => x.FoodPreference).HasColumnName("food_preference");
            entity.Property(x => x.Pets).HasColumnName("pets");
            entity.Property(x => x.SleepSchedule).HasColumnName("sleep_schedule");
            entity.Property(x => x.SocialLifestyle).HasColumnName("social_lifestyle");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        });

        model.Entity<UserPreference>(entity =>
        {
            entity.ToTable("user_preferences");
            entity.HasKey(x => x.AccountId);
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.LookingFor).HasColumnName("looking_for");
            entity.Property(x => x.PreferredAgeMin).HasColumnName("preferred_age_min");
            entity.Property(x => x.PreferredAgeMax).HasColumnName("preferred_age_max");
            entity.Property(x => x.PreferredDistanceKm).HasColumnName("preferred_distance_km");
            entity.Property(x => x.PreferredLocation).HasColumnName("preferred_location");
            entity.Property(x => x.ChildrenPreference).HasColumnName("children_preference");
            entity.Property(x => x.RelationshipStatus).HasColumnName("relationship_status");
            entity.Property(x => x.MeetFrequency).HasColumnName("meet_frequency");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        });

        model.Entity<UserPersonality>(entity =>
        {
            entity.ToTable("user_personalities");
            entity.HasKey(x => x.AccountId);
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.Personality).HasColumnName("personality");
            entity.Property(x => x.PerfectWeekend).HasColumnName("perfect_weekend");
            entity.Property(x => x.LoveLanguage).HasColumnName("love_language");
            entity.Property(x => x.CommunicationStyle).HasColumnName("communication_style");
            entity.Property(x => x.IdealFirstDate).HasColumnName("ideal_first_date");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        });

        model.Entity<UserPrompt>(entity =>
        {
            entity.ToTable("user_prompts");
            entity.HasKey(x => x.Id);
            entity.Property(x => x.Id).HasColumnName("id");
            entity.HasIndex(x => new { x.AccountId, x.SortOrder });
            entity.HasIndex(x => new { x.AccountId, x.PromptKey }).IsUnique();
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.PromptKey).HasColumnName("prompt_key");
            entity.Property(x => x.Answer).HasColumnName("answer");
            entity.Property(x => x.SortOrder).HasColumnName("sort_order");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        });

        model.Entity<UserVerification>(entity =>
        {
            entity.ToTable("user_verifications");
            entity.HasKey(x => x.AccountId);
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.PhoneVerified).HasColumnName("phone_verified");
            entity.Property(x => x.SelfieVerified).HasColumnName("selfie_verified");
            entity.Property(x => x.Status).HasColumnName("status");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        });

        model.Entity<UserPrivacy>(entity =>
        {
            entity.ToTable("user_privacies");
            entity.HasKey(x => x.AccountId);
            entity.Property(x => x.AccountId).HasColumnName("account_id");
            entity.Property(x => x.ShowDistance).HasColumnName("show_distance");
            entity.Property(x => x.ShowOnlineStatus).HasColumnName("show_online_status");
            entity.Property(x => x.Discoverable).HasColumnName("discoverable");
            entity.Property(x => x.Visibility).HasColumnName("visibility");
            entity.Property(x => x.UpdatedAt).HasColumnName("updated_at");
        });
    }

    static string SerializeInterests(string[] value)
    {
        return JsonSerializer.Serialize(value, InterestsJson);
    }

    static string[] DeserializeInterests(string value)
    {
        var parsed = JsonSerializer.Deserialize<string[]>(value, InterestsJson);
        return parsed ?? Array.Empty<string>();
    }
}
