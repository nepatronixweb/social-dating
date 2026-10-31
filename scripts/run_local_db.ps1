# Starts local PostgreSQL (Docker) on localhost:5433, points user-secrets at it,
# and applies EF migrations. Uses port 5433 so it does not collide with the
# Windows PostgreSQL service on 5432.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "backend/src/SocialDating.Api/SocialDating.Api.csproj"
$compose = Join-Path $root "backend/docker-compose.yml"
$connection = "Host=127.0.0.1;Port=5433;Database=social_dating;Username=social_dating;Password=social_dating_dev;SSL Mode=Disable"

function Wait-Docker {
    $deadline = (Get-Date).AddMinutes(2)
    do {
        docker info 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { return }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)
    throw "Docker Desktop did not become ready. Open Docker Desktop and run this script again."
}

docker info 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    $dockerDesktop = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (-not (Test-Path $dockerDesktop)) {
        throw "Docker Desktop is not installed."
    }
    Start-Process $dockerDesktop
    Wait-Docker
}

docker compose -f $compose up -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$deadline = (Get-Date).AddMinutes(2)
do {
    $status = docker inspect --format "{{.State.Health.Status}}" social-dating-postgres 2>$null
    if ($status -eq "healthy") { break }
    Start-Sleep -Seconds 2
} while ((Get-Date) -lt $deadline)

if ($status -ne "healthy") {
    throw "Local PostgreSQL did not become healthy."
}

dotnet user-secrets set "ConnectionStrings:Database" $connection --project $project
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

dotnet ef database update --project $project --startup-project $project
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Output "Local database is ready on localhost:5433 (database social_dating)."
