$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)

$roots = @(
    'docs',
    'tasks',
    'backend/src',
    'frontend/app',
    'frontend/src',
    'AGENTS.md'
)

$extensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
@('.md', '.java', '.sql', '.yml', '.yaml', '.ts', '.tsx', '.json') | ForEach-Object {
    [void]$extensions.Add($_)
}

$excludedParts = @(
    '\backend\build\',
    '\backend\.gradle\',
    '\frontend\node_modules\'
)

$excludedFiles = @(
    '\frontend\package-lock.json'
)

$failurePatterns = @(
    [string][char]0xFFFD,
    (-join ([char[]](0x003F, 0xAFA9))),
    (-join ([char[]](0x003F, 0xBA84))),
    (-join ([char[]](0x003F, 0xB6AF))),
    (-join ([char[]](0x003F, 0xC10F))),
    [string][char]0xC88F,
    [string][char]0x7337,
    [string][char]0xF9CD,
    [string][char]0xC493,
    (-join ([char[]](0x91C9, 0xB6AE))),
    (-join ([char[]](0x8ADB, 0xAE46))),
    (-join ([char[]](0x30EC, 0xC52A)))
)

function Convert-ToRelativePath([string] $path) {
    $rootPath = $repoRoot.Path.TrimEnd('\') + '\'
    if ($path.StartsWith($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $path.Substring($rootPath.Length)
    }

    return $path
}

function Test-IsExcluded([System.IO.FileInfo] $file) {
    $fullName = $file.FullName

    foreach ($part in $excludedParts) {
        if ($fullName.IndexOf($part, [System.StringComparison]::OrdinalIgnoreCase) -ge 0) {
            return $true
        }
    }

    foreach ($excludedFile in $excludedFiles) {
        if ($fullName.EndsWith($excludedFile, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
}

function Test-IsAllowedExample([string] $relativePath, [string] $line) {
    return $relativePath -eq 'AGENTS.md' -and $line.Contains('mojibake such as')
}

$files = New-Object System.Collections.Generic.List[System.IO.FileInfo]

foreach ($root in $roots) {
    $path = Join-Path $repoRoot.Path $root
    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }

    $item = Get-Item -LiteralPath $path
    if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $item.FullName -Recurse -File | ForEach-Object {
            if ($extensions.Contains($_.Extension) -and -not (Test-IsExcluded $_)) {
                $files.Add($_)
            }
        }
    } elseif ($extensions.Contains($item.Extension) -and -not (Test-IsExcluded $item)) {
        $files.Add($item)
    }
}

$findings = New-Object System.Collections.Generic.List[string]

foreach ($file in $files | Sort-Object FullName -Unique) {
    $relativePath = Convert-ToRelativePath $file.FullName

    try {
        $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
        $text = $utf8.GetString($bytes)
    } catch {
        $findings.Add("${relativePath}: strict UTF-8 decode failed: $($_.Exception.Message)")
        continue
    }

    $lines = $text -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if (Test-IsAllowedExample $relativePath $line) {
            continue
        }

        foreach ($pattern in $failurePatterns) {
            if ($line.Contains($pattern)) {
                $lineNumber = $i + 1
                $findings.Add("${relativePath}:${lineNumber}: suspicious Korean mojibake pattern '$pattern'")
            }
        }
    }
}

if ($findings.Count -gt 0) {
    $findings | ForEach-Object { Write-Output $_ }
    Write-Error "Korean mojibake scan failed with $($findings.Count) finding(s)."
    exit 1
}

Write-Output "Korean mojibake scan passed: 0 findings in $($files.Count) file(s)."
