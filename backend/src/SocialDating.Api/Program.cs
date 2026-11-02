using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.Tokens;
using SocialDating.Api.Admin;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;
using SocialDating.Api.Chat;
using SocialDating.Api.Discovery;
using SocialDating.Api.Hosting;
using SocialDating.Api.Inbox;
using SocialDating.Api.Ops;
using SocialDating.Api.Photos;
using SocialDating.Api.Profile;
using SocialDating.Api.Referrals;
using SocialDating.Api.Safety;
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
builder.Services.Configure<AdminOptions>(builder.Configuration.GetSection(AdminOptions.SectionName));
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
builder.Services.AddScoped<IAppConfigService, AppConfigService>();
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
builder.Services.AddScoped<IPersonalInfoService, PersonalInfoService>();
builder.Services.AddScoped<IAdminAuthService, AdminAuthService>();
builder.Services.AddScoped<IAdminService, AdminService>();
builder.Services.AddScoped<IAdminOpsService, AdminOpsService>();
builder.Services.AddScoped<IAdminTrustService, AdminTrustService>();
builder.Services.AddScoped<IAdminDeskService, AdminDeskService>();
builder.Services.AddScoped<IAdminGrowthService, AdminGrowthService>();
builder.Services.AddScoped<IAdminComplianceService, AdminComplianceService>();
builder.Services.AddScoped<IAdminAppealService, AdminAppealService>();
builder.Services.AddScoped<ISafetyService, SafetyService>();
builder.Services.AddHostedService<AdminBootstrapHostedService>();

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
            },
            OnTokenValidated = async context =>
            {
                var typ = context.Principal?.FindFirst(StaffClaims.TypeClaim)?.Value;
                if (typ != StaffClaims.TokenType) return;

                var sub = context.Principal?.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
                    ?? context.Principal?.FindFirst("sub")?.Value;
                if (!Guid.TryParse(sub, out var staffId))
                {
                    context.Fail("Invalid staff token subject.");
                    return;
                }

                var db = context.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
                var staff = await db.StaffUsers.AsNoTracking()
                    .FirstOrDefaultAsync(s => s.Id == staffId, context.HttpContext.RequestAborted);
                if (staff is null || staff.DisabledAt is not null)
                {
                    context.Fail("Staff session is no longer valid.");
                    return;
                }

                if (staff.TokensValidAfter is DateTimeOffset cut)
                {
                    DateTimeOffset? issued = null;
                    if (context.SecurityToken is System.IdentityModel.Tokens.Jwt.JwtSecurityToken classic)
                    {
                        var at = classic.IssuedAt;
                        if (at > DateTime.UnixEpoch)
                        {
                            issued = at.Kind == DateTimeKind.Unspecified
                                ? new DateTimeOffset(DateTime.SpecifyKind(at, DateTimeKind.Utc))
                                : new DateTimeOffset(at.ToUniversalTime());
                        }
                    }
                    else if (context.SecurityToken is Microsoft.IdentityModel.JsonWebTokens.JsonWebToken modern
                             && modern.IssuedAt > DateTime.UnixEpoch)
                    {
                        issued = new DateTimeOffset(DateTime.SpecifyKind(modern.IssuedAt, DateTimeKind.Utc));
                    }

                    if (issued is null)
                    {
                        var iat =
                            context.Principal?.FindFirst("iat")?.Value
                            ?? context.Principal?.FindFirst(
                                System.IdentityModel.Tokens.Jwt.JwtRegisteredClaimNames.Iat
                            )?.Value;
                        if (long.TryParse(iat, out var seconds))
                            issued = DateTimeOffset.FromUnixTimeSeconds(seconds);
                    }

                    // No issued-at → treat as pre-revoke (cannot prove freshness).
                    if (issued is null || issued.Value <= cut)
                    {
                        context.Fail("Staff session was revoked. Sign in again.");
                    }
                }
            },
        };
    });
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(StaffClaims.PolicyName, policy =>
        policy.RequireAuthenticatedUser()
            .RequireClaim(StaffClaims.TypeClaim, StaffClaims.TokenType));

    options.AddPolicy(StaffClaims.SupportWritePolicy, policy =>
        policy.RequireAuthenticatedUser()
            .RequireClaim(StaffClaims.TypeClaim, StaffClaims.TokenType)
            .RequireAssertion(ctx =>
                StaffRoles.CanSupportWrite(ctx.User.FindFirstValue(StaffClaims.RoleClaim))));

    options.AddPolicy(StaffClaims.FinanceWritePolicy, policy =>
        policy.RequireAuthenticatedUser()
            .RequireClaim(StaffClaims.TypeClaim, StaffClaims.TokenType)
            .RequireAssertion(ctx =>
                StaffRoles.CanFinanceWrite(ctx.User.FindFirstValue(StaffClaims.RoleClaim))));

    options.AddPolicy(StaffClaims.SuperadminPolicy, policy =>
        policy.RequireAuthenticatedUser()
            .RequireClaim(StaffClaims.TypeClaim, StaffClaims.TokenType)
            .RequireAssertion(ctx =>
                StaffRoles.CanSuperadminWrite(ctx.User.FindFirstValue(StaffClaims.RoleClaim))));
});

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
app.MapPersonalInfoEndpoints();
app.MapSafetyEndpoints();
app.MapAdminEndpoints();
AdminAppealEndpoints.MapUserAppealEndpoints(app);
app.MapHub<ChatHub>("/v1/hubs/chat").RequireAuthorization();

if (app.Environment.IsDevelopment())
{
    await DiscoverySeeder.SeedAsync(app.Services);
}

app.Run();

public partial class Program;
