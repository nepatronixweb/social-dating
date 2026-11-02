using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase6Growth : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "promo_codes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    code = table.Column<string>(type: "character varying(32)", maxLength: 32, nullable: false),
                    points = table.Column<int>(type: "integer", nullable: false),
                    bucket = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    max_redemptions = table.Column<int>(type: "integer", nullable: false),
                    redemption_count = table.Column<int>(type: "integer", nullable: false),
                    expires_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    active = table.Column<bool>(type: "boolean", nullable: false),
                    created_by_email = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_promo_codes", x => x.Id);
                });

            migrationBuilder.CreateTable(
                name: "promo_redemptions",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    promo_code_id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_promo_redemptions", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_promo_codes_code",
                table: "promo_codes",
                column: "code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_promo_redemptions_promo_code_id_account_id",
                table: "promo_redemptions",
                columns: new[] { "promo_code_id", "account_id" },
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "promo_codes");

            migrationBuilder.DropTable(
                name: "promo_redemptions");
        }
    }
}
