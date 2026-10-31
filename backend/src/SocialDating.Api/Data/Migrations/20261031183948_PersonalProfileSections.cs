using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SocialDating.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class PersonalProfileSections : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "user_lifestyles",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    drink = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    smoke = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    exercise = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    food_preference = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    pets = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    sleep_schedule = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    social_lifestyle = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_lifestyles", x => x.account_id);
                });

            migrationBuilder.CreateTable(
                name: "user_personalities",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    personality = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    perfect_weekend = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    love_language = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    communication_style = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    ideal_first_date = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_personalities", x => x.account_id);
                });

            migrationBuilder.CreateTable(
                name: "user_preferences",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    looking_for = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    preferred_age_min = table.Column<int>(type: "integer", nullable: false),
                    preferred_age_max = table.Column<int>(type: "integer", nullable: false),
                    preferred_distance_km = table.Column<int>(type: "integer", nullable: true),
                    preferred_location = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    children_preference = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    relationship_status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    meet_frequency = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_preferences", x => x.account_id);
                });

            migrationBuilder.CreateTable(
                name: "user_privacies",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    show_distance = table.Column<bool>(type: "boolean", nullable: false),
                    show_online_status = table.Column<bool>(type: "boolean", nullable: false),
                    discoverable = table.Column<bool>(type: "boolean", nullable: false),
                    visibility = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_privacies", x => x.account_id);
                });

            migrationBuilder.CreateTable(
                name: "user_profiles",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    gender_detail = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    interested_in = table.Column<string>(type: "character varying(16)", maxLength: 16, nullable: true),
                    height_cm = table.Column<int>(type: "integer", nullable: true),
                    body_type = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    hair_color = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    eye_color = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    fitness_lifestyle = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    education_level = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    college = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    profession = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: true),
                    company = table.Column<string>(type: "character varying(120)", maxLength: 120, nullable: true),
                    job_title = table.Column<string>(type: "character varying(80)", maxLength: 80, nullable: true),
                    languages = table.Column<string>(type: "character varying(400)", maxLength: 400, nullable: false),
                    income_range = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: true),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_profiles", x => x.account_id);
                });

            migrationBuilder.CreateTable(
                name: "user_prompts",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    prompt_key = table.Column<string>(type: "character varying(40)", maxLength: 40, nullable: false),
                    answer = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    sort_order = table.Column<int>(type: "integer", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_prompts", x => x.id);
                });

            migrationBuilder.CreateTable(
                name: "user_verifications",
                columns: table => new
                {
                    account_id = table.Column<Guid>(type: "uuid", nullable: false),
                    phone_verified = table.Column<bool>(type: "boolean", nullable: false),
                    selfie_verified = table.Column<bool>(type: "boolean", nullable: false),
                    status = table.Column<string>(type: "character varying(24)", maxLength: 24, nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_user_verifications", x => x.account_id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_user_prompts_account_id_prompt_key",
                table: "user_prompts",
                columns: new[] { "account_id", "prompt_key" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_user_prompts_account_id_sort_order",
                table: "user_prompts",
                columns: new[] { "account_id", "sort_order" });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "user_lifestyles");

            migrationBuilder.DropTable(
                name: "user_personalities");

            migrationBuilder.DropTable(
                name: "user_preferences");

            migrationBuilder.DropTable(
                name: "user_privacies");

            migrationBuilder.DropTable(
                name: "user_profiles");

            migrationBuilder.DropTable(
                name: "user_prompts");

            migrationBuilder.DropTable(
                name: "user_verifications");
        }
    }
}
