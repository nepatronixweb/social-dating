using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase4Trust : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "review_reason",
                table: "photos",
                type: "character varying(32)",
                maxLength: 32,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "review_status",
                table: "photos",
                type: "character varying(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "pending");

            // Existing photos were already live — treat as approved so decks do not go blank.
            migrationBuilder.Sql(
                """UPDATE photos SET review_status = 'approved' WHERE review_status = 'pending';"""
            );

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "reviewed_at",
                table: "photos",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "reviewed_by_email",
                table: "photos",
                type: "character varying(120)",
                maxLength: 120,
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "shadow_banned_at",
                table: "accounts",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "staff_case_notes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    staff_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    staff_email = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    body = table.Column<string>(type: "character varying(1000)", maxLength: 1000, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_staff_case_notes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_photos_review_status",
                table: "photos",
                column: "review_status");

            migrationBuilder.CreateIndex(
                name: "IX_staff_case_notes_account_id_created_at",
                table: "staff_case_notes",
                columns: new[] { "account_id", "created_at" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "staff_case_notes");

            migrationBuilder.DropIndex(
                name: "IX_photos_review_status",
                table: "photos");

            migrationBuilder.DropColumn(
                name: "review_reason",
                table: "photos");

            migrationBuilder.DropColumn(
                name: "review_status",
                table: "photos");

            migrationBuilder.DropColumn(
                name: "reviewed_at",
                table: "photos");

            migrationBuilder.DropColumn(
                name: "reviewed_by_email",
                table: "photos");

            migrationBuilder.DropColumn(
                name: "shadow_banned_at",
                table: "accounts");
        }
    }
}
