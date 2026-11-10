# ==============================================================================
# MePharma - Inno Setup Automated Build Script (PowerShell)
# ==============================================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$FrontendDir = Join-Path $ProjectRoot "frontend"
$IssFile = Join-Path $ScriptDir "mepharma_setup.iss"
$OutputDir = Join-Path $ScriptDir "Output"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  MePharma Windows Installer Builder" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Locate Inno Setup Compiler (ISCC.exe)
Write-Host "`n[1/3] Locating Inno Setup compiler (ISCC.exe)..." -ForegroundColor Yellow

$IsccPaths = @(
    "ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 6\ISCC.exe",
    "${env:LOCALAPPDATA}\Programs\Inno Setup 6\ISCC.exe"
)

$IsccExe = $null
foreach ($path in $IsccPaths) {
    if (Get-Command $path -ErrorAction SilentlyContinue) {
        $IsccExe = $path
        break
    } elseif (Test-Path $path) {
        $IsccExe = $path
        break
    }
}

if (-not $IsccExe) {
    Write-Host "WARNING: Inno Setup 6 (ISCC.exe) was not found on your system." -ForegroundColor Red
    Write-Host "You can download and install Inno Setup from: https://jrsoftware.org/isdl.php" -ForegroundColor Red
    Write-Host "Or install via Winget: winget install JRSoftware.InnoSetup" -ForegroundColor Yellow
} else {
    Write-Host "Found ISCC compiler: $IsccExe" -ForegroundColor Green
}

# 2. Build Flutter Windows Release
Write-Host "`n[2/3] Building Flutter Windows application in Release mode..." -ForegroundColor Yellow
Push-Location $FrontendDir
try {
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter release build failed with exit code $LASTEXITCODE"
    }
    Write-Host "Flutter release build succeeded!" -ForegroundColor Green
} finally {
    Pop-Location
}

# 3. Compile Inno Setup Script
if ($IsccExe) {
    Write-Host "`n[3/3] Compiling Inno Setup script ($IssFile)..." -ForegroundColor Yellow
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }

    & "$IsccExe" "$IssFile"
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n==================================================" -ForegroundColor Green
        Write-Host "  Setup Installer successfully created!" -ForegroundColor Green
        Write-Host "  Output location: $OutputDir" -ForegroundColor Green
        Write-Host "==================================================" -ForegroundColor Green
    } else {
        Write-Host "Inno Setup compilation failed with exit code $LASTEXITCODE" -ForegroundColor Red
    }
} else {
    Write-Host "`n[3/3] Skipped installer packaging because ISCC.exe is not installed yet." -ForegroundColor Yellow
    Write-Host "Once Inno Setup is installed, run this script again or open '$IssFile' in Inno Setup GUI to build." -ForegroundColor Cyan
}
