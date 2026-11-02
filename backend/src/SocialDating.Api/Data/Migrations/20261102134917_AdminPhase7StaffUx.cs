using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase7StaffUx : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTimeOffset>(
                name: "tokens_valid_after",
                table: "staff_users",
                type: "timestamp with time zone",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "app_config_revisions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    snapshot_json = table.Column<string>(type: "character varying(4000)", maxLength: 4000, nullable: false),
                    changed_by_email = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_app_config_revisions", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_app_config_revisions_created_at",
                table: "app_config_revisions",
                column: "created_at");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "app_config_revisions");

            migrationBuilder.DropColumn(
                name: "tokens_valid_after",
                table: "staff_users");
        }
    }
}
