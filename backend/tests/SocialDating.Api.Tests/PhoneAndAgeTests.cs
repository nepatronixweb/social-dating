using SocialDating.Api.Auth;
using Xunit;

namespace SocialDating.Api.Tests;

public class PhoneAndAgeTests
{
    [Theory]
    [InlineData("+9779841234567")]
    [InlineData("+447911123456")]
    public void accepts_e164(string phone)
    {
        Assert.True(PhoneE164.TryNormalize(phone, out var e164));
        Assert.Equal(phone, e164);
    }

    [Theory]
    [InlineData("9841234567")]
    [InlineData("+977")]
    [InlineData("")]
    [InlineData("+0123")]
    public void rejects_non_e164(string? phone)
    {
        Assert.False(PhoneE164.TryNormalize(phone, out _));
    }

    [Fact]
    public void eighteen_today_is_eligible()
    {
        var today = new DateOnly(2026, 10, 29);
        var birth = new DateOnly(2008, 10, 29);
        Assert.True(AgePolicy.IsEligible(birth, today));
        Assert.Equal(18, AgePolicy.AgeOn(birth, today));
    }

    [Fact]
    public void one_day_short_is_not_eligible()
    {
        var today = new DateOnly(2026, 10, 29);
        var birth = new DateOnly(2008, 10, 30);
        Assert.False(AgePolicy.IsEligible(birth, today));
    }

    [Fact]
    public void profile_rules_accept_the_app_interest_list()
    {
        var interests = ProfileRules.NormalizeInterests([" Hiking ", "Coffee", "Hiking", "Film"]);
        Assert.Equal(["Hiking", "Coffee", "Film"], interests);
        Assert.Null(ProfileRules.ValidateInterests(interests));
        Assert.Null(ProfileRules.ValidateDisplayName("Ada"));
        Assert.Equal("Use letters only.", ProfileRules.ValidateDisplayName("Ada2"));
    }

    [Fact]
    public void otp_hash_round_trips()
    {
        var (salt, hash) = SecretHasher.HashOtp("482913");
        Assert.True(SecretHasher.VerifyOtp("482913", salt, hash));
        Assert.False(SecretHasher.VerifyOtp("000000", salt, hash));
    }
}
