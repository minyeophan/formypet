$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$frontendRoot = Join-Path $repoRoot.Path 'frontend'
$catalogPath = 'lib/core/visuals/app_visual_catalog.dart'
$rendererPath = 'lib/widgets/app_visual.dart'
$findings = New-Object System.Collections.Generic.List[string]

function Invoke-RipgrepCheck {
    param(
        [string] $Label,
        [string] $Pattern,
        [string[]] $Paths,
        [string[]] $Globs = @(),
        [switch] $Pcre2
    )

    $arguments = @('--line-number', '--color', 'never')
    if ($Pcre2) { $arguments += '--pcre2' }
    foreach ($glob in $Globs) { $arguments += @('--glob', $glob) }
    $arguments += @($Pattern)
    $arguments += $Paths

    $output = & rg @arguments 2>&1
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        $findings.Add("${Label}:`n$($output -join "`n")")
        return
    }
    if ($exitCode -eq 1) { return }
    throw "rg failed while checking ${Label} with exit code ${exitCode}: $($output -join "`n")"
}

Push-Location $frontendRoot
try {
    Invoke-RipgrepCheck `
        -Label 'Unicode emoji outside the visual catalog' `
        -Pattern '(?:\p{Extended_Pictographic}|\p{Regional_Indicator}|[0-9#*]\x{FE0F}?\x{20E3})' `
        -Paths @('lib', 'test') `
        -Globs @('*.dart', "!$catalogPath") `
        -Pcre2

    Invoke-RipgrepCheck `
        -Label 'Asset renderer outside the allowlist' `
        -Pattern '(?:Image|SvgPicture)\.asset\s*\(' `
        -Paths @('lib') `
        -Globs @('*.dart', "!$rendererPath") `
        -Pcre2

    Invoke-RipgrepCheck `
        -Label 'Direct assets/visuals reference outside the catalog' `
        -Pattern 'assets/visuals/' `
        -Paths @('lib', 'test') `
        -Globs @('*.dart', "!$catalogPath")

    Invoke-RipgrepCheck `
        -Label 'Unsupported content visual asset extension' `
        -Pattern 'assets/visuals/[^'']+\.(?:jpe?g|gif|bmp|avif|ico|tiff?)' `
        -Paths @($catalogPath) `
        -Pcre2

    $catalog = Get-Content -Raw -Encoding utf8 $catalogPath
    $assetSpecs = [regex]::Matches(
        $catalog,
        'AppVisualSpec\((?:(?!AppVisualSpec\().)*?(?:Svg|Raster)AssetVisualSource\((?:(?!\)).)*\)(?:(?!AppVisualSpec\().)*?\)',
        [System.Text.RegularExpressions.RegexOptions]::Singleline
    )
    foreach ($match in $assetSpecs) {
        if ($match.Value -notmatch 'fallback\s*:') {
            $line = ($catalog.Substring(0, $match.Index) -split "`n").Count
            $findings.Add("Asset source without fallback at ${catalogPath}:${line}")
        }
    }
} finally {
    Pop-Location
}

if ($findings.Count -gt 0) {
    $findings | ForEach-Object { Write-Output $_ }
    Write-Error "Visual usage scan failed with $($findings.Count) finding group(s)."
    exit 1
}

Write-Output 'Visual usage scan passed: 0 findings.'
