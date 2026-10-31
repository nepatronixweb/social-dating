using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Hosting;
using SocialDating.Api.Auth;
using SocialDating.Api.Hosting;
using Xunit;

namespace SocialDating.Api.Tests;

public class ProductionGuardsTests
{
    [Fact]
    public void production_refuses_otp_logging()
    {
        var error = Assert.Throws<InvalidOperationException>(() =>
            ProductionGuards.Ensure(new FakeHost("Production"), new AuthOptions { LogOtps = true })
        );
        Assert.Contains("LogOtps", error.Message, StringComparison.Ordinal);
    }

    [Fact]
    public void production_allows_silent_otps()
    {
        ProductionGuards.Ensure(new FakeHost("Production"), new AuthOptions { LogOtps = false });
    }

    [Fact]
    public void development_may_log_otps()
    {
        ProductionGuards.Ensure(new FakeHost("Development"), new AuthOptions { LogOtps = true });
    }

    [Theory]
    [InlineData("http://localhost:8080", true, true)]
    [InlineData("http://127.0.0.1:5088", true, true)]
    [InlineData("http://localhost:8080", false, false)]
    [InlineData("https://app.example.test", true, false)]
    public void localhost_origins_follow_the_flag(string origin, bool allowLocalhost, bool expected)
    {
        var settings = new CorsSettings { AllowLocalhost = allowLocalhost };
        Assert.Equal(expected, OriginPolicy.IsAllowed(origin, settings));
    }

    [Fact]
    public void an_exact_allowed_origin_is_accepted()
    {
        var settings = new CorsSettings
        {
            AllowLocalhost = false,
            AllowedOrigins = ["https://app.example.test"],
        };
        Assert.True(OriginPolicy.IsAllowed("https://app.example.test", settings));
        Assert.False(OriginPolicy.IsAllowed("https://other.example.test", settings));
    }

    sealed class FakeHost(string name) : IHostEnvironment
    {
        public string EnvironmentName { get; set; } = name;
        public string ApplicationName { get; set; } = "SocialDating.Api";
        public string ContentRootPath { get; set; } = ".";
        public IFileProvider ContentRootFileProvider { get; set; } = new NullFileProvider();
    }
}
