using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ProfileDetails : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateOnly>(
                name: "birth_date",
                table: "accounts",
                type: "date",
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "interests",
                table: "accounts",
                type: "character varying(800)",
                maxLength: 800,
                nullable: false,
                defaultValue: "");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "birth_date",
                table: "accounts");

            migrationBuilder.DropColumn(
                name: "interests",
                table: "accounts");
        }
    }
}
