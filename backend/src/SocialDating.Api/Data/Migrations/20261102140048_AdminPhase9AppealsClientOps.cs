using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase9AppealsClientOps : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "banner_body",
                table: "app_runtime_settings",
                type: "character varying(300)",
                maxLength: 300,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "banner_enabled",
                table: "app_runtime_settings",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<string>(
                name: "banner_title",
                table: "app_runtime_settings",
                type: "character varying(80)",
                maxLength: 80,
                nullable: true);

            migrationBuilder.AddColumn<bool>(
                name: "maintenance_mode",
                table: "app_runtime_settings",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddColumn<int>(
                name: "min_client_build",
                table: "app_runtime_settings",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.CreateTable(
                name: "moderation_appeals",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    kind = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    body = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    resolved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    resolved_by_staff_id = table.Column<Guid>(type: "uuid", nullable: true),
                    resolution_note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    filed_by = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_moderation_appeals", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_moderation_appeals_account_id",
                table: "moderation_appeals",
                column: "account_id");

            migrationBuilder.CreateIndex(
                name: "IX_moderation_appeals_status_created_at",
                table: "moderation_appeals",
                columns: new[] { "status", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "moderation_appeals");

            migrationBuilder.DropColumn(
                name: "banner_body",
                table: "app_runtime_settings");

            migrationBuilder.DropColumn(
                name: "banner_enabled",
                table: "app_runtime_settings");

            migrationBuilder.DropColumn(
                name: "banner_title",
                table: "app_runtime_settings");

            migrationBuilder.DropColumn(
                name: "maintenance_mode",
                table: "app_runtime_settings");

            migrationBuilder.DropColumn(
                name: "min_client_build",
                table: "app_runtime_settings");
        }
    }
}
