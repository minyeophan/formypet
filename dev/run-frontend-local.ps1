$ErrorActionPreference = 'Stop'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$envFile = Join-Path $repoRoot '.env'

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "Missing $envFile. Add KAKAO_NATIVE_APP_KEY before starting Flutter."
}

$kakaoKey = $null
foreach ($line in Get-Content -LiteralPath $envFile) {
    if ($line -match '^\s*KAKAO_NATIVE_APP_KEY\s*=\s*(.*)\s*$') {
        $kakaoKey = $Matches[1].Trim().Trim('"').Trim("'")
        break
    }
}

if ([string]::IsNullOrWhiteSpace($kakaoKey)) {
    throw 'KAKAO_NATIVE_APP_KEY is missing from .env.'
}

Push-Location (Join-Path $repoRoot 'frontend')
try {
    flutter run --dart-define="KAKAO_NATIVE_APP_KEY=$kakaoKey"
}
finally {
    Pop-Location
}
