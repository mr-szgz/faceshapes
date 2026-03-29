[CmdletBinding()]
param(
    [string]$Python,
    [string]$ProjectRoot = (Join-Path $PSScriptRoot ".."),
    [string]$OutputDir = "dist",
    [switch]$Clean,
    [switch]$SkipSdist,
    [switch]$UseCibuildwheel,
    [bool]$PreferProjectVenv = $true,
    [ValidateSet("auto", "windows", "linux", "macos")]
    [string]$Platform = "auto"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$resolvedProjectRoot = (Resolve-Path -LiteralPath $ProjectRoot).Path
$resolvedOutputDir = if ([IO.Path]::IsPathRooted($OutputDir)) {
    $OutputDir
} else {
    Join-Path $resolvedProjectRoot $OutputDir
}

function Resolve-PythonInterpreter {
    param(
        [string]$ConfiguredPython,
        [string]$ProjectRootPath,
        [bool]$UseProjectVenv
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPython)) {
        return $ConfiguredPython
    }

    if ($UseProjectVenv) {
        $venvCandidates = @(
            (Join-Path $ProjectRootPath ".venv\Scripts\python.exe"),
            (Join-Path $ProjectRootPath ".venv/bin/python"),
            (Join-Path $ProjectRootPath ".venv/bin/python3")
        )
        foreach ($candidate in $venvCandidates) {
            if (Test-Path -LiteralPath $candidate -PathType Leaf) {
                return $candidate
            }
        }
    }

    return "python"
}

function Test-CommandExists {
    param([string]$Name)
    return $null -ne (Get-Command -Name $Name -ErrorAction SilentlyContinue)
}

function Test-PythonModule {
    param(
        [string]$PythonPath,
        [string]$ModuleName
    )

    & $PythonPath -c "import $ModuleName" *> $null
    return $LASTEXITCODE -eq 0
}

function Install-PythonPackages {
    param(
        [string]$PythonPath,
        [string[]]$Packages
    )

    if (Test-PythonModule -PythonPath $PythonPath -ModuleName "pip") {
        & $PythonPath -m pip install --upgrade @Packages
        if ($LASTEXITCODE -eq 0) {
            return
        }
    } elseif (Test-PythonModule -PythonPath $PythonPath -ModuleName "ensurepip") {
        & $PythonPath -m ensurepip --upgrade
        if ($LASTEXITCODE -eq 0) {
            & $PythonPath -m pip install --upgrade @Packages
            if ($LASTEXITCODE -eq 0) {
                return
            }
        }
    }

    if (Test-CommandExists -Name "uv") {
        & uv pip install --python $PythonPath --upgrade @Packages
        if ($LASTEXITCODE -eq 0) {
            return
        }
    }

    throw "Unable to install required Python packages. Ensure pip or uv is available for $PythonPath."
}

$resolvedPython = Resolve-PythonInterpreter -ConfiguredPython $Python -ProjectRootPath $resolvedProjectRoot -UseProjectVenv $PreferProjectVenv
Write-Host "Using Python interpreter: $resolvedPython"

Push-Location -LiteralPath $resolvedProjectRoot
try {
    if ($Clean) {
        Remove-Item -LiteralPath (Join-Path $resolvedProjectRoot "build") -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath (Join-Path $resolvedProjectRoot "dist") -Recurse -Force -ErrorAction SilentlyContinue
        Get-ChildItem -LiteralPath $resolvedProjectRoot -Filter "*.egg-info" -Directory | ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    New-Item -ItemType Directory -Path $resolvedOutputDir -Force | Out-Null

    if ($UseCibuildwheel) {
        Install-PythonPackages -PythonPath $resolvedPython -Packages @("cibuildwheel")

        $resolvedPlatform = if ($Platform -ne "auto") {
            $Platform
        } elseif ($IsWindows) {
            "windows"
        } elseif ($IsMacOS) {
            "macos"
        } else {
            "linux"
        }

        & $resolvedPython -m cibuildwheel --platform $resolvedPlatform --output-dir $resolvedOutputDir
        if ($LASTEXITCODE -ne 0) {
            throw "cibuildwheel failed."
        }
    } else {
        Install-PythonPackages -PythonPath $resolvedPython -Packages @("build", "wheel")

        $buildArgs = @("-m", "build", "--wheel", "--outdir", $resolvedOutputDir)
        if (-not (Test-PythonModule -PythonPath $resolvedPython -ModuleName "venv")) {
            Write-Warning "Python '$resolvedPython' has no 'venv' module; building with --no-isolation."
            $buildArgs += "--no-isolation"
        }
        if (-not $SkipSdist) {
            $buildArgs += "--sdist"
        }

        & $resolvedPython @buildArgs
        if ($LASTEXITCODE -ne 0) {
            throw "python -m build failed."
        }
    }

    Write-Host "Build artifacts:"
    Get-ChildItem -LiteralPath $resolvedOutputDir -File | Sort-Object Name | ForEach-Object {
        Write-Host " - $($_.Name)"
    }
} finally {
    Pop-Location
}
