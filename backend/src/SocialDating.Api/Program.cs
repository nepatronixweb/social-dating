using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Chat;
using SocialDating.Api.Discovery;
using SocialDating.Api.Hosting;
using SocialDating.Api.Inbox;
using SocialDating.Api.Photos;
using SocialDating.Api.Referrals;
using SocialDating.Api.Subscription;
using SocialDating.Api.Wallet;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddProblemDetails();
builder.Services.AddExceptionHandler<AuthExceptionHandler>();
builder.Services.AddOpenApi();
builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.Configure<AuthOptions>(builder.Configuration.GetSection(AuthOptions.SectionName));
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection(JwtOptions.SectionName));
builder.Services.Configure<ReferralOptions>(builder.Configuration.GetSection(ReferralOptions.SectionName));
builder.Services.Configure<CorsSettings>(builder.Configuration.GetSection(CorsSettings.SectionName));
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownNetworks.Clear();
    options.KnownProxies.Clear();
});

var connectionString = builder.Configuration.GetConnectionString("Database");
if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("ConnectionStrings:Database is not set.");
}

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(connectionString)
);

builder.Services.AddScoped<IJwtTokenService, JwtTokenService>();
builder.Services.AddSingleton<IOtpGenerator>(sp =>
{
    var auth = sp.GetRequiredService<IOptions<AuthOptions>>().Value;
    if (auth.SmsEnabled) return new RandomOtpGenerator();
    var staticCode = auth.StaticOtp?.Trim();
    if (string.IsNullOrEmpty(staticCode)) return new RandomOtpGenerator();
    if (staticCode.Length != 6 || !staticCode.All(char.IsDigit))
    {
        throw new InvalidOperationException("Auth:StaticOtp must be 6 digits while SMS is disabled.");
    }

    return new StaticOtpGenerator(staticCode);
});
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.Configure<FormOptions>(options =>
{
    options.MultipartBodyLengthLimit = 6_000_000;
});
builder.WebHost.ConfigureKestrel(options =>
{
    options.Limits.MaxRequestBodySize = 6_000_000;
});
builder.Services.Configure<PhotoOptions>(builder.Configuration.GetSection(PhotoOptions.SectionName));
builder.Services.PostConfigure<PhotoOptions>(options =>
{
    if (string.IsNullOrWhiteSpace(options.RootPath))
    {
        options.RootPath = Path.Combine(builder.Environment.ContentRootPath, "App_Data", "photos");
    }
});
builder.Services.AddScoped<IWalletService, WalletService>();
builder.Services.AddScoped<PhotoService>();
builder.Services.AddSingleton<IUserIdProvider, AccountUserIdProvider>();
builder.Services.AddSignalR();
builder.Services.AddSingleton<IChatRealtime, SignalRChatRealtime>();
builder.Services.AddScoped<IInboxService, InboxService>();
builder.Services.AddScoped<IDiscoveryService, DiscoveryService>();
builder.Services.AddScoped<IChatService, ChatService>();
builder.Services.AddScoped<IReferralService, ReferralService>();
builder.Services.AddScoped<ISubscriptionService, SubscriptionService>();

var jwt = builder.Configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();
if (string.IsNullOrWhiteSpace(jwt.SigningKey) || jwt.SigningKey.Length < 32)
{
    throw new InvalidOperationException("Jwt:SigningKey must be at least 32 characters.");
}

builder
    .Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateIssuerSigningKey = true,
            ValidateLifetime = true,
            ValidIssuer = jwt.Issuer,
            ValidAudience = jwt.Audience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.SigningKey)),
            ClockSkew = TimeSpan.FromMinutes(1),
            NameClaimType = "sub",
        };
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                var access = context.Request.Query["access_token"];
                if (!string.IsNullOrEmpty(access)
                    && context.HttpContext.Request.Path.StartsWithSegments("/v1/hubs/chat"))
                {
                    context.Token = access;
                }

                return Task.CompletedTask;
            }
        };
    });
builder.Services.AddAuthorization();

var corsSettings =
    builder.Configuration.GetSection(CorsSettings.SectionName).Get<CorsSettings>() ?? new CorsSettings();
var authSettings =
    builder.Configuration.GetSection(AuthOptions.SectionName).Get<AuthOptions>() ?? new AuthOptions();
ProductionGuards.Ensure(builder.Environment, authSettings);

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
    {
        policy
            .SetIsOriginAllowed(origin => OriginPolicy.IsAllowed(origin, corsSettings))
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

var app = builder.Build();

app.UseForwardedHeaders();
app.UseExceptionHandler();
app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
}

app.MapGet("/health", async (AppDbContext db, CancellationToken ct) =>
{
    var ok = await db.Database.CanConnectAsync(ct);
    return ok
        ? Results.Ok(new { status = "ok" })
        : Results.Json(new { status = "unhealthy" }, statusCode: StatusCodes.Status503ServiceUnavailable);
});
app.MapAuthEndpoints();
app.MapDiscoveryEndpoints();
app.MapMatchingEndpoints();
app.MapChatEndpoints();
app.MapWalletEndpoints();
app.MapPhotoEndpoints();
app.MapInboxEndpoints();
app.MapReferralEndpoints();
app.MapSubscriptionEndpoints();
app.MapHub<ChatHub>("/v1/hubs/chat").RequireAuthorization();

if (app.Environment.IsDevelopment())
{
    await DiscoverySeeder.SeedAsync(app.Services);
}

app.Run();

public partial class Program;
