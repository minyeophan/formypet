$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envFile = Join-Path $repoRoot '.env'
$composeFile = Join-Path $repoRoot 'backend/docker/docker-compose.yml'

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Missing $envFile. Create it from the variables documented in backend/src/main/resources/application.yml."
}

function Import-DotEnv([string]$path) {
    foreach ($line in Get-Content -LiteralPath $path) {
        if ($line -match '^\s*(?:#.*)?$') { continue }
        if ($line -notmatch '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)\s*$') { continue }
        $name = $Matches[1]
        $value = $Matches[2].Trim()
        if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
            $value = $value.Substring(1, $value.Length - 2)
        }
        [Environment]::SetEnvironmentVariable($name, $value, 'Process')
    }
}

Import-DotEnv $envFile
docker compose --env-file $envFile -f $composeFile up -d mysql

Push-Location (Join-Path $repoRoot 'backend')
try {
    .\gradlew.bat bootRun
}
finally {
    Pop-Location
}
