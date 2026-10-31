using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Subscription;
using Xunit;

namespace SocialDating.Api.Tests;

public class SubscriptionServiceTests : IDisposable
{
    readonly SqliteConnection _connection;
    readonly AppDbContext _db;
    readonly SubscriptionService _subscriptions;
    readonly DateTimeOffset _now = new(2026, 10, 29, 6, 0, 0, TimeSpan.Zero);
    int _phones;

    public SubscriptionServiceTests()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        _connection.Open();
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlite(_connection)
            .Options;
        _db = new AppDbContext(options);
        _db.Database.EnsureCreated();
        _subscriptions = new SubscriptionService(_db);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
    }

    [Theory]
    [InlineData("woman")]
    [InlineData("female")]
    [InlineData("lgbtq")]
    [InlineData("transgender")]
    [InlineData("other")]
    public async Task non_male_accounts_receive_complimentary_premium(string gender)
    {
        var person = SeedPerson("Asha", gender, "Kathmandu");
        await _db.SaveChangesAsync();

        var overview = await _subscriptions.FetchOverviewAsync(person.Id, CancellationToken.None);
        Assert.False(overview.NeedsPaidSubscription);
        Assert.True(overview.Complimentary);
        Assert.True(overview.HasPremiumAccess);
        Assert.False(overview.PaymentsEnabled);
        Assert.True(overview.IsLive);
        Assert.NotNull(overview.Active);
        Assert.True(overview.Active!.Complimentary);
        Assert.Equal(SubscriptionService.ComplimentaryPlanId, overview.Active.Plan.Id);
        Assert.Equal(person.CreatedAt, overview.Active.StartedAt);
        Assert.DoesNotContain(
            "phone",
            System.Text.Json.JsonSerializer.Serialize(overview),
            StringComparison.OrdinalIgnoreCase
        );
    }

    [Theory]
    [InlineData("man")]
    [InlineData("male")]
    public async Task male_accounts_must_buy_premium(string gender)
    {
        var person = SeedPerson("Nabin", gender, "Lalitpur");
        await _db.SaveChangesAsync();

        var overview = await _subscriptions.FetchOverviewAsync(person.Id, CancellationToken.None);
        Assert.True(overview.NeedsPaidSubscription);
        Assert.False(overview.Complimentary);
        Assert.False(overview.HasPremiumAccess);
        Assert.Null(overview.Active);
        Assert.False(overview.PaymentsEnabled);
    }

    [Fact]
    public async Task checkout_is_refused_for_complimentary_accounts()
    {
        var asha = SeedPerson("Asha", "woman", "Kathmandu");
        await _db.SaveChangesAsync();

        var error = await Assert.ThrowsAsync<AuthException>(() =>
            _subscriptions.SubmitCheckoutAsync(
                asha.Id,
                new SubmitCheckoutRequest("npr-100", false, "card", true, 10000),
                CancellationToken.None
            )
        );
        Assert.Equal(400, error.StatusCode);
        Assert.Contains("included", error.Detail, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task checkout_is_refused_for_male_accounts_until_payments_exist()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        var error = await Assert.ThrowsAsync<AuthException>(() =>
            _subscriptions.SubmitCheckoutAsync(
                nabin.Id,
                new SubmitCheckoutRequest("npr-100", false, "card", true, 10000),
                CancellationToken.None
            )
        );
        Assert.Equal(400, error.StatusCode);
        Assert.Contains("not enabled", error.Detail, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task checkout_requires_confirmation()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        var error = await Assert.ThrowsAsync<AuthException>(() =>
            _subscriptions.SubmitCheckoutAsync(
                nabin.Id,
                new SubmitCheckoutRequest("npr-100", false, "card", false, 10000),
                CancellationToken.None
            )
        );
        Assert.Equal(400, error.StatusCode);
    }

    [Fact]
    public async Task paid_plans_are_listed_and_history_is_empty()
    {
        var nabin = SeedPerson("Nabin", "man", "Lalitpur");
        await _db.SaveChangesAsync();

        var plans = await _subscriptions.FetchPlansAsync(nabin.Id, CancellationToken.None);
        Assert.Equal(2, plans.Items.Count);
        Assert.Contains(plans.Items, p => p.Id == SubscriptionService.StandardPlanId);
        var history = await _subscriptions.FetchHistoryAsync(nabin.Id, CancellationToken.None);
        Assert.Empty(history.Items);
    }

    Account SeedPerson(string name, string gender, string city)
    {
        var account = new Account
        {
            Id = Guid.NewGuid(),
            PhoneE164 = $"+9779800{Interlocked.Increment(ref _phones):D6}",
            CreatedAt = _now,
            UpdatedAt = _now,
            TermsAcceptedAt = _now,
            AgeEligible = true,
            AgeCheckedAt = _now,
            BirthDate = new DateOnly(1998, 3, 7),
            DisplayName = name,
            City = city,
            Gender = gender,
            Interests = ["Hiking", "Coffee", "Film"],
        };
        _db.Accounts.Add(account);
        return account;
    }
}
