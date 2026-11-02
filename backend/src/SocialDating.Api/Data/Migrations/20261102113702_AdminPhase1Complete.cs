using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase1Complete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "last_warned_at",
                table: "accounts",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "suspended_at",
                table: "accounts",
                type: "timestamp with time zone",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "last_warned_at",
                table: "accounts");

            migrationBuilder.DropColumn(
                name: "suspended_at",
                table: "accounts");
        }
    }
}
