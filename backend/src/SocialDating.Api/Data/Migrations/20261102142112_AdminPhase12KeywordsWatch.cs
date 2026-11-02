using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase12KeywordsWatch : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "chat_keyword_list",
                table: "app_runtime_settings",
                type: "character varying(2000)",
                maxLength: 2000,
                nullable: false,
                defaultValue: "");

            migrationBuilder.CreateTable(
                name: "chat_keyword_hits",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    message_id = table.Column<Guid>(type: "uuid", nullable: false),
                    match_id = table.Column<Guid>(type: "uuid", nullable: false),
                    sender_account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    keyword = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    message_body = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    resolved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    resolved_by_staff_id = table.Column<Guid>(type: "uuid", nullable: true),
                    resolution_note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_chat_keyword_hits", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "staff_watch_entries",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    staff_user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    note = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_staff_watch_entries", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_chat_keyword_hits_sender_account_id",
                table: "chat_keyword_hits",
                column: "sender_account_id");

            migrationBuilder.CreateIndex(
                name: "IX_chat_keyword_hits_status_created_at",
                table: "chat_keyword_hits",
                columns: new[] { "status", "created_at" });

            migrationBuilder.CreateIndex(
                name: "IX_staff_watch_entries_staff_user_id_account_id",
                table: "staff_watch_entries",
                columns: new[] { "staff_user_id", "account_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "chat_keyword_hits");

            migrationBuilder.DropTable(
                name: "staff_watch_entries");

            migrationBuilder.DropColumn(
                name: "chat_keyword_list",
                table: "app_runtime_settings");
        }
    }
}
