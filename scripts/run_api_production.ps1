# Runs the API with ASPNETCORE_ENVIRONMENT=Production.
# User-secrets are Development-only, so this copies them into process env vars.
# Secrets are not written to disk.

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$project = Join-Path $root "backend/src/SocialDating.Api/SocialDating.Api.csproj"

$raw = dotnet user-secrets list --project $project
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

foreach ($line in $raw) {
    if ($line -notmatch '^\s*(.+?)\s=\s(.*)$') { continue }
    $name = $Matches[1].Replace(":", "__")
    [Environment]::SetEnvironmentVariable($name, $Matches[2], "Process")
}

if ([string]::IsNullOrWhiteSpace($env:ConnectionStrings__Database)) {
    throw "ConnectionStrings:Database is not set. Run dotnet user-secrets set first."
}
if ([string]::IsNullOrWhiteSpace($env:Jwt__SigningKey)) {
    throw "Jwt:SigningKey is not set. Run dotnet user-secrets set first."
}

$env:ASPNETCORE_ENVIRONMENT = "Production"
$env:ASPNETCORE_URLS = "http://localhost:5088"
Set-Location (Join-Path $root "backend/src/SocialDating.Api")
dotnet run --launch-profile production
