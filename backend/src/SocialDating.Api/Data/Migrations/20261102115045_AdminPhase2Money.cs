using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase2Money : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "staff_complimentary_premium",
                table: "accounts",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateTable(
                name: "admin_refund_requests",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    source_id = table.Column<string>(type: "character varying(64)", maxLength: 64, nullable: false),
                    points = table.Column<int>(type: "integer", nullable: false),
                    requested_by_staff_id = table.Column<Guid>(type: "uuid", nullable: false),
                    requested_by_email = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: false),
                    resolved_by_staff_id = table.Column<Guid>(type: "uuid", nullable: true),
                    resolved_by_email = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    status = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: false),
                    note = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: false),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    resolved_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: true)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_admin_refund_requests", x => x.Id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_admin_refund_requests_account_id_source_id_status",
                table: "admin_refund_requests",
                columns: new[] { "account_id", "source_id", "status" });

            migrationBuilder.CreateIndex(
                name: "IX_admin_refund_requests_created_at",
                table: "admin_refund_requests",
                column: "created_at");

            migrationBuilder.CreateIndex(
                name: "IX_admin_refund_requests_status",
                table: "admin_refund_requests",
                column: "status");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "admin_refund_requests");

            migrationBuilder.DropColumn(
                name: "staff_complimentary_premium",
                table: "accounts");
        }
    }
}
