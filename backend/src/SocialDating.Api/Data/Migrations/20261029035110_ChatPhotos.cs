using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class ChatPhotos : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "kind",
                table: "photos",
                type: "character varying(16)",
                maxLength: 16,
                nullable: false,
                defaultValue: "profile");

            migrationBuilder.AddColumn<Guid>(
                name: "photo_id",
                table: "messages",
                type: "uuid",
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "kind",
                table: "photos");

            migrationBuilder.DropColumn(
                name: "photo_id",
                table: "messages");
        }
    }
}
