using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase11ClaimsNotify : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "last_login_at",
                table: "staff_users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "claimed_at",
                table: "moderation_reports",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "claimed_by_email",
                table: "moderation_reports",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "claimed_by_staff_id",
                table: "moderation_reports",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_moderation_reports_claimed_by_staff_id",
                table: "moderation_reports",
                column: "claimed_by_staff_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_moderation_reports_claimed_by_staff_id",
                table: "moderation_reports");

            migrationBuilder.DropColumn(
                name: "last_login_at",
                table: "staff_users");

            migrationBuilder.DropColumn(
                name: "claimed_at",
                table: "moderation_reports");

            migrationBuilder.DropColumn(
                name: "claimed_by_email",
                table: "moderation_reports");

            migrationBuilder.DropColumn(
                name: "claimed_by_staff_id",
                table: "moderation_reports");
        }
    }
}
