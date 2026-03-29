[CmdletBinding()]
param(
    [Alias("Bump")]
    [ValidateSet("auto", "major", "minor", "patch")]
    [string]$BumpVersion = "auto",
    [switch]$Apply,
    [switch]$CreateTag,
    [string]$TagPrefix = "v",
    [string]$Remote = "origin",
    [string]$ProjectRoot = (Join-Path $PSScriptRoot "..")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$pyprojectPath = Join-Path $resolvedProjectRoot "pyproject.toml"
$changelogPath = Join-Path $resolvedProjectRoot "CHANGELOG.md"

if (-not (Test-Path -LiteralPath $pyprojectPath -PathType Leaf)) {
    throw "Missing pyproject.toml at '$pyprojectPath'."
}

if ($CreateTag -and -not $Apply) {
    throw "-CreateTag requires -Apply so the tag matches the updated project version."
}

function Get-CurrentVersion {
    param([Parameter(Mandatory)][string]$PyprojectFilePath)

    $content = Get-Content -LiteralPath $PyprojectFilePath -Raw -Encoding UTF8
    $match = [regex]::Match($content, '(?m)^version\s*=\s*"(?<version>\d+\.\d+\.\d+)"\s*$')
    if (-not $match.Success) {
        throw "Could not find [project].version in pyproject.toml."
    }
    return $match.Groups["version"].Value
}

function Get-UnreleasedBody {
    param([Parameter(Mandatory)][string]$ChangelogFilePath)

    if (-not (Test-Path -LiteralPath $ChangelogFilePath -PathType Leaf)) {
        return ""
    }

    $content = Get-Content -LiteralPath $ChangelogFilePath -Raw -Encoding UTF8
    $match = [regex]::Match($content, '(?s)## \[Unreleased\]\s*(?<body>.*?)(?:\r?\n## \[|\z)')
    if ($match.Success) {
        return $match.Groups["body"].Value
    }
    return ""
}

function Get-RecommendedBump {
    param([Parameter(Mandatory)][string]$UnreleasedBody)

    if ([string]::IsNullOrWhiteSpace($UnreleasedBody)) {
        return "patch"
    }

    if ($UnreleasedBody -match '(?im)^\s*###\s*(Breaking|Removed)\b' -or
        $UnreleasedBody -match '(?i)\bBREAKING\b') {
        return "major"
    }

    if ($UnreleasedBody -match '(?im)^\s*###\s*(Added|Changed|Deprecated)\b') {
        return "minor"
    }

    return "patch"
}

function Get-NextVersion {
    param(
        [Parameter(Mandatory)][string]$CurrentVersion,
        [Parameter(Mandatory)][ValidateSet("major", "minor", "patch")][string]$BumpType
    )

    $parts = $CurrentVersion.Split(".")
    if ($parts.Count -ne 3) {
        throw "Version '$CurrentVersion' is not semver major.minor.patch."
    }

    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]

    switch ($BumpType) {
        "major" { $major += 1; $minor = 0; $patch = 0 }
        "minor" { $minor += 1; $patch = 0 }
        "patch" { $patch += 1 }
    }

    return "$major.$minor.$patch"
}

function Set-ProjectVersion {
    param(
        [Parameter(Mandatory)][string]$PyprojectFilePath,
        [Parameter(Mandatory)][string]$OldVersion,
        [Parameter(Mandatory)][string]$NewVersion
    )

    $content = Get-Content -LiteralPath $PyprojectFilePath -Raw -Encoding UTF8
    $updated = $content -replace "(?m)^version\s*=\s*`"$([regex]::Escape($OldVersion))`"\s*$", "version = `"$NewVersion`""

    if ($updated -eq $content) {
        throw "No version update was applied to pyproject.toml."
    }

    Set-Content -LiteralPath $PyprojectFilePath -Value $updated -Encoding UTF8
}

function Invoke-Git {
    param(
        [Parameter(Mandatory)][string]$ProjectRootPath,
        [Parameter(Mandatory)][string[]]$Arguments,
        [switch]$AllowFailure
    )

    $output = & git -C $ProjectRootPath @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).TrimEnd()

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        throw "git $($Arguments -join ' ') failed.`n$text"
    }

    return [pscustomobject]@{
        ExitCode = $exitCode
        Output = $text
    }
}

function Assert-GitRepository {
    param([Parameter(Mandatory)][string]$ProjectRootPath)

    $probe = Invoke-Git -ProjectRootPath $ProjectRootPath -Arguments @("rev-parse", "--is-inside-work-tree") -AllowFailure
    if ($probe.ExitCode -ne 0 -or $probe.Output -notmatch "true") {
        throw "Project root '$ProjectRootPath' is not a git working tree."
    }
}

function New-LocalTag {
    param(
        [Parameter(Mandatory)][string]$ProjectRootPath,
        [Parameter(Mandatory)][string]$TagName
    )

    $existing = Invoke-Git -ProjectRootPath $ProjectRootPath -Arguments @("tag", "--list", $TagName)
    if (-not [string]::IsNullOrWhiteSpace($existing.Output)) {
        throw "Tag '$TagName' already exists locally."
    }

    Invoke-Git -ProjectRootPath $ProjectRootPath -Arguments @("tag", $TagName) | Out-Null
}

$currentVersion = Get-CurrentVersion -PyprojectFilePath $pyprojectPath
$unreleasedBody = Get-UnreleasedBody -ChangelogFilePath $changelogPath
$recommendedBump = Get-RecommendedBump -UnreleasedBody $unreleasedBody
$selectedBump = if ($BumpVersion -eq "auto") { $recommendedBump } else { $BumpVersion }
$nextVersion = Get-NextVersion -CurrentVersion $currentVersion -BumpType $selectedBump
$nextTag = "$TagPrefix$nextVersion"

Write-Host "Current version   : $currentVersion"
Write-Host "Recommended bump : $recommendedBump"
Write-Host "Selected bump    : $selectedBump"
Write-Host "Next version     : $nextVersion"
Write-Host "Next tag         : $nextTag"

if ($Apply) {
    Set-ProjectVersion -PyprojectFilePath $pyprojectPath -OldVersion $currentVersion -NewVersion $nextVersion
    Write-Host "Updated pyproject.toml version to $nextVersion"

    if ($CreateTag) {
        Assert-GitRepository -ProjectRootPath $resolvedProjectRoot
        New-LocalTag -ProjectRootPath $resolvedProjectRoot -TagName $nextTag
        Write-Host "Created local git tag '$nextTag'"
    } else {
        Write-Host "Local tag was not created (use -CreateTag to create '$nextTag')."
    }
} else {
    Write-Host "Dry run only. Re-run with -Apply to update pyproject.toml."
}

Write-Host ""
Write-Host "Manual push commands:"
if (-not $CreateTag) {
    Write-Host "  git tag $nextTag"
}
Write-Host "  git push $Remote HEAD"
Write-Host "  git push $Remote $nextTag"
