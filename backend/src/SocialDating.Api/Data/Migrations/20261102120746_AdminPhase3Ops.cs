using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase3Ops : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "hidden_at",
                table: "photos",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "hidden_at",
                table: "messages",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "app_runtime_settings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    premium_action_points = table.Column<int>(type: "integer", nullable: false),
                    extra_swipe_points = table.Column<int>(type: "integer", nullable: false),
                    daily_free_points_male = table.Column<int>(type: "integer", nullable: false),
                    free_daily_swipes_male = table.Column<int>(type: "integer", nullable: false),
                    min_withdrawal_points = table.Column<int>(type: "integer", nullable: false),
                    kill_withdrawals = table.Column<bool>(type: "boolean", nullable: false),
                    kill_premium_charges = table.Column<bool>(type: "boolean", nullable: false),
                    kill_referrals = table.Column<bool>(type: "boolean", nullable: false),
                    kill_discovery = table.Column<bool>(type: "boolean", nullable: false),
                    kill_chat_messaging = table.Column<bool>(type: "boolean", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_by_email = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_app_runtime_settings", x => x.Id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "app_runtime_settings");

            migrationBuilder.DropColumn(
                name: "hidden_at",
                table: "photos");

            migrationBuilder.DropColumn(
                name: "hidden_at",
                table: "messages");
        }
    }
}
