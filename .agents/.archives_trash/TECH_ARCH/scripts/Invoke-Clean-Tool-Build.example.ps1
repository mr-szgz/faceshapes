[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ProjectRoot = (Join-Path $PSScriptRoot "..")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path

function Test-IsUnderProjectRoot {
    param([Parameter(Mandatory)][string]$CandidatePath)

    $rootWithSeparator = $resolvedProjectRoot.TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    $candidateFullPath = [IO.Path]::GetFullPath($CandidatePath)

    return $candidateFullPath.StartsWith($rootWithSeparator, [System.StringComparison]::OrdinalIgnoreCase) -or
        $candidateFullPath.Equals($resolvedProjectRoot, [System.StringComparison]::OrdinalIgnoreCase)
}

function Remove-DirectoryIfExists {
    param([Parameter(Mandatory)][string]$DirectoryPath)

    $fullPath = [IO.Path]::GetFullPath($DirectoryPath)
    if (-not (Test-IsUnderProjectRoot -CandidatePath $fullPath)) {
        throw "Refusing to delete path outside project root: $fullPath"
    }

    if (Test-Path -LiteralPath $fullPath -PathType Container) {
        if ($PSCmdlet.ShouldProcess($fullPath, "Remove directory recursively")) {
            try {
                Remove-Item -LiteralPath $fullPath -Recurse -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not remove directory '$fullPath': $($_.Exception.Message)"
            }
        }
    }
}

function Remove-FileIfExists {
    param([Parameter(Mandatory)][string]$FilePath)

    $fullPath = [IO.Path]::GetFullPath($FilePath)
    if (-not (Test-IsUnderProjectRoot -CandidatePath $fullPath)) {
        throw "Refusing to delete path outside project root: $fullPath"
    }

    if (Test-Path -LiteralPath $fullPath -PathType Leaf) {
        if ($PSCmdlet.ShouldProcess($fullPath, "Remove file")) {
            try {
                Remove-Item -LiteralPath $fullPath -Force -ErrorAction Stop
            } catch {
                Write-Warning "Could not remove file '$fullPath': $($_.Exception.Message)"
            }
        }
    }
}

$rootDirectoriesToDelete = @(
    "build",
    "dist",
    "pip-wheel-metadata",
    "htmlcov",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    ".tox",
    ".nox"
)

foreach ($relativeDirectory in $rootDirectoriesToDelete) {
    Remove-DirectoryIfExists -DirectoryPath (Join-Path $resolvedProjectRoot $relativeDirectory)
}

Get-ChildItem -LiteralPath $resolvedProjectRoot -Directory -Filter "*.egg-info" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-DirectoryIfExists -DirectoryPath $_.FullName
}

Get-ChildItem -LiteralPath $resolvedProjectRoot -File -Filter ".coverage*" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-FileIfExists -FilePath $_.FullName
}

$excludedTopLevelDirectoryNames = @(".git", ".venv", "venv", "env", "ENV")

$scanRoots = @()
Get-ChildItem -LiteralPath $resolvedProjectRoot -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    if ($excludedTopLevelDirectoryNames -notcontains $_.Name) {
        $scanRoots += $_.FullName
    }
}

foreach ($scanRoot in $scanRoots) {
    Get-ChildItem -LiteralPath $scanRoot -Directory -Recurse -Filter "__pycache__" -Force -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-DirectoryIfExists -DirectoryPath $_.FullName
    }

    foreach ($pattern in @("*.pyc", "*.pyo")) {
        Get-ChildItem -LiteralPath $scanRoot -File -Recurse -Filter $pattern -Force -ErrorAction SilentlyContinue | ForEach-Object {
            Remove-FileIfExists -FilePath $_.FullName
        }
    }
}

Write-Host "Build outputs and caches cleaned under: $resolvedProjectRoot"
