using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class AdminPhase12IdSnakeCase : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "Id",
                table: "staff_watch_entries",
                newName: "id");

            migrationBuilder.RenameColumn(
                name: "Id",
                table: "moderation_appeals",
                newName: "id");

            migrationBuilder.RenameColumn(
                name: "Id",
                table: "chat_keyword_hits",
                newName: "id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "id",
                table: "staff_watch_entries",
                newName: "Id");

            migrationBuilder.RenameColumn(
                name: "id",
                table: "moderation_appeals",
                newName: "Id");

            migrationBuilder.RenameColumn(
                name: "id",
                table: "chat_keyword_hits",
                newName: "Id");
        }
    }
}
