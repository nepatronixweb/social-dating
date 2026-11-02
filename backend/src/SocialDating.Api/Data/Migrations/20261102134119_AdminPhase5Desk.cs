using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase5Desk : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "device_id",
                table: "refresh_tokens",
                type: "character varying(128)",
                maxLength: 128,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "ip_address",
                table: "refresh_tokens",
                type: "character varying(64)",
                maxLength: 64,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "user_agent",
                table: "refresh_tokens",
                type: "character varying(256)",
                maxLength: 256,
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_refresh_tokens_device_id",
                table: "refresh_tokens",
                column: "device_id");

            migrationBuilder.CreateIndex(
                name: "IX_refresh_tokens_ip_address",
                table: "refresh_tokens",
                column: "ip_address");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_refresh_tokens_device_id",
                table: "refresh_tokens");

            migrationBuilder.DropIndex(
                name: "IX_refresh_tokens_ip_address",
                table: "refresh_tokens");

            migrationBuilder.DropColumn(
                name: "device_id",
                table: "refresh_tokens");

            migrationBuilder.DropColumn(
                name: "ip_address",
                table: "refresh_tokens");

            migrationBuilder.DropColumn(
                name: "user_agent",
                table: "refresh_tokens");
        }
    }
}
