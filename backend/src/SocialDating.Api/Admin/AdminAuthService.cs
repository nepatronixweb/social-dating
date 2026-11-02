using System.Security.Claims;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using SocialDating.Api.Auth;
using SocialDating.Api.Data;

namespace SocialDating.Api.Admin;

public interface IAdminAuthService
{
    Task EnsureBootstrapAsync(CancellationToken ct);
    Task<StaffLoginResponse> LoginAsync(StaffLoginRequest body, CancellationToken ct);
    Task<StaffListResponse> ListStaffAsync(CancellationToken ct);
    Task<StaffMemberResponse> CreateStaffAsync(
        CreateStaffRequest body,
        ClaimsPrincipal actor,
        CancellationToken ct
    );
    Task<StaffMemberResponse> ResetPasswordAsync(
        Guid id,
        ResetStaffPasswordRequest body,
        ClaimsPrincipal actor,
        CancellationToken ct
    );
    Task SetDisabledAsync(Guid id, bool disabled, ClaimsPrincipal actor, CancellationToken ct);
    Task<StaffMemberResponse> SetRoleAsync(
        Guid id,
        SetStaffRoleRequest body,
        ClaimsPrincipal actor,
        CancellationToken ct
    );
    Task RevokeSessionsAsync(Guid id, ClaimsPrincipal actor, CancellationToken ct);
}

public sealed class AdminAuthService(
    AppDbContext db,
    IJwtTokenService jwt,
    IOptions<AdminOptions> options,
    TimeProvider time
) : IAdminAuthService
{
    DateTimeOffset Now => time.GetUtcNow();

    public async Task EnsureBootstrapAsync(CancellationToken ct)
    {
        if (await db.StaffUsers.AnyAsync(ct)) return;

        var cfg = options.Value;
        var email = cfg.BootstrapEmail?.Trim().ToLowerInvariant();
        var password = cfg.BootstrapPassword?.Trim();
        if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(password))
        {
            return;
        }

        if (password.Length < 8)
        {
            throw new InvalidOperationException("Admin:BootstrapPassword must be at least 8 characters.");
        }

        var (salt, hash) = StaffPassword.Hash(password);
        db.StaffUsers.Add(
            new StaffUser
            {
                Id = Guid.NewGuid(),
                Email = email,
                DisplayName = string.IsNullOrWhiteSpace(cfg.BootstrapDisplayName)
                    ? "Superadmin"
                    : cfg.BootstrapDisplayName.Trim(),
                Role = string.IsNullOrWhiteSpace(cfg.BootstrapRole)
                    ? StaffRoles.Superadmin
                    : cfg.BootstrapRole.Trim().ToLowerInvariant(),
                PasswordSalt = salt,
                PasswordHash = hash,
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<StaffLoginResponse> LoginAsync(StaffLoginRequest body, CancellationToken ct)
    {
        var email = body.Email?.Trim().ToLowerInvariant() ?? "";
        var password = body.Password ?? "";
        if (email.Length == 0 || password.Length == 0)
        {
            throw new AuthException(400, "Email and password are required.", "Enter staff email and password.");
        }

        var staff = await db.StaffUsers.FirstOrDefaultAsync(s => s.Email == email, ct);
        if (staff is null || staff.DisabledAt is not null
            || !StaffPassword.Verify(password, staff.PasswordSalt, staff.PasswordHash))
        {
            throw new AuthException(401, "Invalid email or password.", "Staff credentials were rejected.");
        }

        staff.LastLoginAt = Now;
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = staff.Id,
                StaffEmail = staff.Email,
                Action = "staff.login",
                TargetType = "staff",
                TargetId = staff.Id.ToString(),
                Detail = "Staff signed in.",
                CreatedAt = Now,
            }
        );
        await db.SaveChangesAsync(ct);

        var (token, expires) = jwt.IssueStaffAccessToken(
            staff.Id,
            staff.Email,
            staff.Role,
            options.Value.AccessTokenMinutes
        );

        return new StaffLoginResponse(
            token,
            expires,
            new StaffProfileResponse(
                staff.Id.ToString(),
                staff.Email,
                staff.DisplayName,
                staff.Role
            )
        );
    }

    public async Task<StaffListResponse> ListStaffAsync(CancellationToken ct)
    {
        var rows = await db.StaffUsers.OrderBy(s => s.Email).ToListAsync(ct);
        return new StaffListResponse(rows.Select(ToMember).ToList());
    }

    public async Task<StaffMemberResponse> CreateStaffAsync(
        CreateStaffRequest body,
        ClaimsPrincipal actor,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSuperadmin(actor);

        var email = body.Email?.Trim().ToLowerInvariant() ?? "";
        var display = body.DisplayName?.Trim() ?? "";
        var role = StaffRoles.Normalize(body.Role);
        var password = body.TemporaryPassword?.Trim() ?? "";

        if (email.Length < 5 || !email.Contains('@'))
        {
            throw new AuthException(400, "Invalid email.", "Enter a valid staff email.");
        }

        if (display.Length < 2)
        {
            throw new AuthException(400, "Display name required.", "Enter a display name.");
        }

        if (role == StaffRoles.Trust) role = StaffRoles.Support;
        if (role is not (StaffRoles.Support or StaffRoles.Finance or StaffRoles.Superadmin))
        {
            throw new AuthException(
                400,
                "Invalid role.",
                "Use support, finance, or superadmin."
            );
        }

        if (password.Length < 8)
        {
            throw new AuthException(
                400,
                "Password too short.",
                "Temporary password must be at least 8 characters."
            );
        }

        if (await db.StaffUsers.AnyAsync(s => s.Email == email, ct))
        {
            throw new AuthException(400, "Email in use.", "That staff email already exists.");
        }

        var storedRole = role;
        var (salt, hash) = StaffPassword.Hash(password);
        var staff = new StaffUser
        {
            Id = Guid.NewGuid(),
            Email = email,
            DisplayName = display,
            Role = storedRole,
            PasswordSalt = salt,
            PasswordHash = hash,
            CreatedAt = Now,
        };
        db.StaffUsers.Add(staff);
        await Audit(
            actor,
            "staff.create",
            staff.Id.ToString(),
            $"{email} as {storedRole}",
            ct
        );
        await db.SaveChangesAsync(ct);
        return ToMember(staff);
    }

    public async Task<StaffMemberResponse> ResetPasswordAsync(
        Guid id,
        ResetStaffPasswordRequest body,
        ClaimsPrincipal actor,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSuperadmin(actor);
        var password = body.TemporaryPassword?.Trim() ?? "";
        if (password.Length < 8)
        {
            throw new AuthException(
                400,
                "Password too short.",
                "Temporary password must be at least 8 characters."
            );
        }

        var staff = await db.StaffUsers.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new AuthException(404, "Staff not found.", "No staff user matches that id.");

        var (salt, hash) = StaffPassword.Hash(password);
        staff.PasswordSalt = salt;
        staff.PasswordHash = hash;
        staff.TokensValidAfter = Now;
        await Audit(actor, "staff.resetPassword", staff.Id.ToString(), staff.Email, ct);
        await db.SaveChangesAsync(ct);
        return ToMember(staff);
    }

    public async Task SetDisabledAsync(
        Guid id,
        bool disabled,
        ClaimsPrincipal actor,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSuperadmin(actor);
        var actorId = actor.RequireStaffId();
        if (actorId == id)
        {
            throw new AuthException(400, "Cannot disable yourself.", "Ask another superadmin.");
        }

        var staff = await db.StaffUsers.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new AuthException(404, "Staff not found.", "No staff user matches that id.");

        if (disabled && staff.Role == StaffRoles.Superadmin)
        {
            var otherSupers = await db.StaffUsers.CountAsync(
                s =>
                    s.Id != id
                    && s.Role == StaffRoles.Superadmin
                    && s.DisabledAt == null,
                ct
            );
            if (otherSupers == 0)
            {
                throw new AuthException(
                    400,
                    "Last superadmin.",
                    "Keep at least one active superadmin."
                );
            }
        }

        staff.DisabledAt = disabled ? Now : null;
        if (disabled) staff.TokensValidAfter = Now;
        await Audit(
            actor,
            disabled ? "staff.disable" : "staff.enable",
            staff.Id.ToString(),
            staff.Email,
            ct
        );
        await db.SaveChangesAsync(ct);
    }

    public async Task<StaffMemberResponse> SetRoleAsync(
        Guid id,
        SetStaffRoleRequest body,
        ClaimsPrincipal actor,
        CancellationToken ct
    )
    {
        StaffRoles.RequireSuperadmin(actor);
        var role = StaffRoles.Normalize(body.Role);
        if (role == StaffRoles.Trust) role = StaffRoles.Support;
        if (role is not (StaffRoles.Support or StaffRoles.Finance or StaffRoles.Superadmin))
        {
            throw new AuthException(400, "Invalid role.", "Use support, finance, or superadmin.");
        }

        var staff = await db.StaffUsers.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new AuthException(404, "Staff not found.", "No staff user matches that id.");

        if (staff.Role == StaffRoles.Superadmin && role != StaffRoles.Superadmin)
        {
            var otherSupers = await db.StaffUsers.CountAsync(
                s =>
                    s.Id != id
                    && s.Role == StaffRoles.Superadmin
                    && s.DisabledAt == null,
                ct
            );
            if (otherSupers == 0)
            {
                throw new AuthException(
                    400,
                    "Last superadmin.",
                    "Keep at least one active superadmin."
                );
            }
        }

        staff.Role = role;
        staff.TokensValidAfter = Now;
        await Audit(actor, "staff.setRole", staff.Id.ToString(), $"{staff.Email} → {role}", ct);
        await db.SaveChangesAsync(ct);
        return ToMember(staff);
    }

    public async Task RevokeSessionsAsync(Guid id, ClaimsPrincipal actor, CancellationToken ct)
    {
        StaffRoles.RequireSuperadmin(actor);
        var staff = await db.StaffUsers.FirstOrDefaultAsync(s => s.Id == id, ct)
            ?? throw new AuthException(404, "Staff not found.", "No staff user matches that id.");
        staff.TokensValidAfter = Now;
        await Audit(actor, "staff.revokeSessions", staff.Id.ToString(), staff.Email, ct);
        await db.SaveChangesAsync(ct);
    }

    async Task Audit(
        ClaimsPrincipal actor,
        string action,
        string targetId,
        string detail,
        CancellationToken ct
    )
    {
        db.AdminAuditEvents.Add(
            new AdminAuditEvent
            {
                Id = Guid.NewGuid(),
                StaffUserId = actor.RequireStaffId(),
                StaffEmail = actor.RequireStaffEmail(),
                Action = action,
                TargetType = "staff",
                TargetId = targetId,
                Detail = detail.Length > 500 ? detail[..500] : detail,
                CreatedAt = Now,
            }
        );
        await Task.CompletedTask;
    }

    static StaffMemberResponse ToMember(StaffUser s) =>
        new(
            s.Id.ToString(),
            s.Email,
            s.DisplayName,
            s.Role,
            s.CreatedAt,
            s.DisabledAt,
            s.LastLoginAt
        );
}

public sealed class AdminBootstrapHostedService(IServiceScopeFactory scopes) : IHostedService
{
    public async Task StartAsync(CancellationToken cancellationToken)
    {
        await using var scope = scopes.CreateAsyncScope();
        var auth = scope.ServiceProvider.GetRequiredService<IAdminAuthService>();
        try
        {
            await auth.EnsureBootstrapAsync(cancellationToken);
        }
        catch
        {
            // DB may be offline at boot; login will fail loudly later.
        }
    }

    public Task StopAsync(CancellationToken cancellationToken) => Task.CompletedTask;
}
