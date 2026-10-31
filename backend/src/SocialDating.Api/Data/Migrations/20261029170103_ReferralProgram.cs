using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ReferralProgram : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "referral_code",
                table: "accounts",
                type: "character varying(12)",
                maxLength: 12,
                nullable: true);

            migrationBuilder.AddColumn<Guid>(
                name: "referred_by_account_id",
                table: "accounts",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateTable(
                name: "referral_commissions",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    invite_id = table.Column<Guid>(type: "uuid", nullable: false),
                    referrer_account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    amount_paisa = table.Column<int>(type: "integer", nullable: false),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    detail = table.Column<string>(type: "character varying(300)", maxLength: 300, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    resolved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_referral_commissions", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "referral_invites",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    referrer_account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    invitee_account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    code_used = table.Column<string>(type: "character varying(12)", maxLength: 12, nullable: false),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    purchased_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true),
                    refunded_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_referral_invites", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_accounts_referral_code",
                table: "accounts",
                column: "referral_code",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_referral_commissions_invite_id",
                table: "referral_commissions",
                column: "invite_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_referral_commissions_referrer_account_id",
                table: "referral_commissions",
                column: "referrer_account_id");

            migrationBuilder.CreateIndex(
                name: "IX_referral_invites_invitee_account_id",
                table: "referral_invites",
                column: "invitee_account_id",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_referral_invites_referrer_account_id",
                table: "referral_invites",
                column: "referrer_account_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "referral_commissions");

            migrationBuilder.DropTable(
                name: "referral_invites");

            migrationBuilder.DropIndex(
                name: "IX_accounts_referral_code",
                table: "accounts");

            migrationBuilder.DropColumn(
                name: "referral_code",
                table: "accounts");

            migrationBuilder.DropColumn(
                name: "referred_by_account_id",
                table: "accounts");
        }
    }
}
