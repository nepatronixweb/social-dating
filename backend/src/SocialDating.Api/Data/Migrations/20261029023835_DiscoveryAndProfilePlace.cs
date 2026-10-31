using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class DiscoveryAndProfilePlace : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "city",
                table: "accounts",
                type: "character varying(40)",
                maxLength: 40,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "gender",
                table: "accounts",
                type: "character varying(16)",
                maxLength: 16,
                nullable: true);

            migrationBuilder.CreateTable(
                name: "matches",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_low_id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_high_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    unmatched_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    seen_by_low = table.Column<bool>(type: "boolean", nullable: false),
                    seen_by_high = table.Column<bool>(type: "boolean", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_matches", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "swipe_days",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    day_key = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    preview_used = table.Column<int>(type: "integer", nullable: false),
                    daily_used = table.Column<int>(type: "integer", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_swipe_days", x => new { x.account_id, x.day_key });
                });

            migrationBuilder.CreateTable(
                name: "swipes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    from_account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    to_account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    direction = table.Column<string>(type: "character varying(8)", maxLength: 8, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    undone_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    match_id = table.Column<Guid>(type: "uuid", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_swipes", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_matches_account_low_id_account_high_id",
                table: "matches",
                columns: new[] { "account_low_id", "account_high_id" });

            migrationBuilder.CreateIndex(
                name: "IX_swipes_from_account_id",
                table: "swipes",
                column: "from_account_id");

            migrationBuilder.CreateIndex(
                name: "IX_swipes_from_account_id_to_account_id",
                table: "swipes",
                columns: new[] { "from_account_id", "to_account_id" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "matches");

            migrationBuilder.DropTable(
                name: "swipe_days");

            migrationBuilder.DropTable(
                name: "swipes");

            migrationBuilder.DropColumn(
                name: "city",
                table: "accounts");

            migrationBuilder.DropColumn(
                name: "gender",
                table: "accounts");
        }
    }
}
