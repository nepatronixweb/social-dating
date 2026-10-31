using Microsoft.Data.Sqlite;
using Xunit;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;

namespace SocialDating.Api.Tests;

public class AuthServiceTests : IDisposable
{
    const string Phone = "+9779841234567";
    const string Code = "482913";

    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly AuthService _auth;

    public AuthServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        _auth = new AuthService(
            _db,
            new FakeJwt(),
            new FixedOtp(),
            Options.Create(new AuthOptions { LogOtps = false }),
            NullLogger<AuthService>.Instance,
            TimeProvider.System
        );
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Fact]
    public async Task verify_creates_an_account_without_exposing_the_phone()
    {
        await _auth.RequestCodeAsync(Phone, CancellationToken.None);
        var session = await _auth.VerifyAsync(Phone, Code, CancellationToken.None);

        Assert.True(session.Account.TermsAccepted);
        Assert.True(session.Account.IsAgeEligible);
        Assert.False(string.IsNullOrEmpty(session.AccessToken));
        Assert.DoesNotContain("9841234567", session.Account.Id, StringComparison.Ordinal);
        Assert.Null(session.Account.DisplayName);
        Assert.Null(session.Account.Gender);
    }

    [Fact]
    public async Task a_number_that_already_has_an_account_skips_onboarding()
    {
        var auth = new AuthService(
            _db,
            new FakeJwt(),
            new FixedOtp(),
            Options.Create(new AuthOptions
            {
                LogOtps = false,
                ResendCooldownSeconds = 0,
            }),
            NullLogger<AuthService>.Instance,
            TimeProvider.System
        );

        var firstCode = await auth.RequestCodeAsync(Phone, CancellationToken.None);
        Assert.False(firstCode.Registered);
        var first = await auth.VerifyAsync(Phone, Code, CancellationToken.None);
        Assert.True(first.Account.TermsAccepted);
        Assert.Null(first.Account.DisplayName);
        Assert.Null(first.Account.Gender);

        var secondCode = await auth.RequestCodeAsync(Phone, CancellationToken.None);
        Assert.True(secondCode.Registered);
        var second = await auth.VerifyAsync(Phone, Code, CancellationToken.None);
        Assert.True(second.Account.TermsAccepted);
        Assert.True(second.Account.IsAgeEligible);
        Assert.Equal("You", second.Account.DisplayName);
        var stored = _db.Accounts.Single();
        Assert.Equal("Kathmandu", stored.City);
        Assert.Equal("male", stored.Gender);
    }

    [Fact]
    public async Task login_skips_onboarding_and_finishes_the_account()
    {
        await _auth.RequestCodeAsync(Phone, CancellationToken.None);
        var session = await _auth.VerifyAsync(
            Phone,
            Code,
            CancellationToken.None,
            login: true
        );

        Assert.True(session.Account.TermsAccepted);
        Assert.True(session.Account.IsAgeEligible);
        Assert.Equal("You", session.Account.DisplayName);
        var stored = _db.Accounts.Single();
        Assert.Equal("Kathmandu", stored.City);
        Assert.Equal("male", stored.Gender);
        Assert.Equal(3, stored.Interests.Length);
        Assert.NotNull(stored.BirthDate);
        Assert.DoesNotContain(
            "phone",
            System.Text.Json.JsonSerializer.Serialize(session.Account),
            StringComparison.OrdinalIgnoreCase
        );
    }

    [Fact]
    public async Task static_development_otp_is_accepted_until_sms_is_wired()
    {
        var auth = new AuthService(
            _db,
            new FakeJwt(),
            new StaticOtpGenerator("123456"),
            Options.Create(new AuthOptions
            {
                LogOtps = false,
                SmsEnabled = false,
                StaticOtp = "123456",
            }),
            NullLogger<AuthService>.Instance,
            TimeProvider.System
        );

        await auth.RequestCodeAsync(Phone, CancellationToken.None);
        var session = await auth.VerifyAsync(Phone, "123456", CancellationToken.None);
        Assert.False(string.IsNullOrEmpty(session.AccessToken));
    }

    [Fact]
    public async Task wrong_code_is_rejected()
    {
        await _auth.RequestCodeAsync(Phone, CancellationToken.None);
        var error = await Assert.ThrowsAsync<AuthException>(() =>
            _auth.VerifyAsync(Phone, "000000", CancellationToken.None)
        );
        Assert.Equal(401, error.StatusCode);
    }

    [Fact]
    public async Task age_check_stores_eligibility_not_the_date()
    {
        var account = await SignedIn();

        Assert.True(account.Account.IsAgeEligible);
        Assert.NotNull(_db.Accounts.Single().AgeCheckedAt);
        Assert.DoesNotContain(
            "birth",
            System.Text.Json.JsonSerializer.Serialize(account.Account),
            StringComparison.OrdinalIgnoreCase
        );
    }

    [Fact]
    public async Task second_age_submission_does_not_change_the_result()
    {
        var account = await SignedIn();
        var id = Guid.Parse(account.Account.Id);
        var young = DateOnly.FromDateTime(DateTime.UtcNow).AddYears(-10).ToString("yyyy-MM-dd");
        var adult = DateOnly.FromDateTime(DateTime.UtcNow).AddYears(-30).ToString("yyyy-MM-dd");

        await _auth.SubmitAgeAsync(id, young, CancellationToken.None);
        var again = await _auth.SubmitAgeAsync(id, adult, CancellationToken.None);

        Assert.True(again.IsAgeEligible);
    }

    [Fact]
    public async Task age_check_stores_the_date_privately()
    {
        var account = await SignedIn();
        var birth = DateOnly.FromDateTime(DateTime.UtcNow).AddYears(-25).ToString("yyyy-MM-dd");

        var state = await _auth.SubmitAgeAsync(
            Guid.Parse(account.Account.Id),
            birth,
            CancellationToken.None
        );

        Assert.True(state.IsAgeEligible);
        Assert.NotNull(_db.Accounts.Single().BirthDate);
        Assert.DoesNotContain("birth", System.Text.Json.JsonSerializer.Serialize(state), StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task complete_profile_stores_bio_and_interests()
    {
        var session = await SignedIn();
        var id = Guid.Parse(session.Account.Id);
        var state = await _auth.CompleteProfileAsync(
            id,
            new CompleteProfileRequest(
                "Ada",
                "Hikes on Saturday.",
                ["Hiking", "Coffee", "Film"],
                "Kathmandu",
                "female"
            ),
            CancellationToken.None
        );

        var stored = _db.Accounts.Single();
        Assert.Equal("Ada", state.DisplayName);
        Assert.Equal("Hikes on Saturday.", stored.Bio);
        Assert.Equal(["Hiking", "Coffee", "Film"], stored.Interests);
        Assert.Equal("Kathmandu", stored.City);
        Assert.Equal("female", stored.Gender);
    }

    [Fact]
    public async Task set_gender_stores_the_wire_name()
    {
        var session = await SignedIn();
        var state = await _auth.SetGenderAsync(
            Guid.Parse(session.Account.Id),
            "female",
            CancellationToken.None
        );

        Assert.Equal("female", state.Gender);
        Assert.Equal("female", _db.Accounts.Single().Gender);
    }

    [Fact]
    public async Task complete_profile_canonicalizes_legacy_gender_names()
    {
        var session = await SignedIn();
        await _auth.CompleteProfileAsync(
            Guid.Parse(session.Account.Id),
            new CompleteProfileRequest(
                "Ada",
                null,
                ["Hiking", "Coffee", "Film"],
                "Kathmandu",
                "woman"
            ),
            CancellationToken.None
        );
        Assert.Equal("female", _db.Accounts.Single().Gender);
    }

    [Fact]
    public async Task complete_profile_rejects_unknown_interests()
    {
        var session = await SignedIn();
        var error = await Assert.ThrowsAsync<AuthException>(() =>
            _auth.CompleteProfileAsync(
                Guid.Parse(session.Account.Id),
                new CompleteProfileRequest("Ada", null, ["Hiking", "Coffee", "NotATag"]),
                CancellationToken.None
            )
        );
        Assert.Equal(400, error.StatusCode);
    }

    async Task<AuthVerifyResponse> SignedIn()
    {
        await _auth.RequestCodeAsync(Phone, CancellationToken.None);
        return await _auth.VerifyAsync(Phone, Code, CancellationToken.None);
    }

    sealed class FakeJwt : IJwtTokenService
    {
        public (string token, DateTimeOffset expiresAt) IssueAccessToken(Guid accountId) =>
            ("test-access", DateTimeOffset.UtcNow.AddMinutes(15));
    }

    sealed class FixedOtp : IOtpGenerator
    {
        public string Next() => Code;
    }
}
