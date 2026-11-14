# ==============================================================================
# MePharma Variant - Automated Windows Installer Builder with Digital Signature
# ==============================================================================

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$VariantDir = Join-Path $ProjectRoot "app-varient"
$IssFile = Join-Path $ScriptDir "mepharma_variant_setup.iss"
$OutputDir = Join-Path $ScriptDir "Output"
$ReleaseDir = Join-Path $VariantDir "build\windows\x64\runner\Release"
$ReleaseDataDir = Join-Path $ReleaseDir "data"
$AssembledDir = Join-Path $VariantDir "build\windows_assembled"

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "  MePharma Variant Windows Installer Builder" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

# 1. Locate Inno Setup Compiler (ISCC.exe)
Write-Host "`n[1/5] Locating Inno Setup compiler (ISCC.exe)..." -ForegroundColor Yellow

$IsccPaths = @(
    "ISCC.exe",
    "${env:ProgramFiles}\Inno Setup 7\ISCC.exe",
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
    throw "Inno Setup compiler (ISCC.exe) was not found."
}
Write-Host "Found ISCC compiler: $IsccExe" -ForegroundColor Green

# 2. Assemble Release Assets & Binaries
Write-Host "`n[2/5] Synchronizing Variant AOT engine and flutter assets..." -ForegroundColor Yellow
if (-not (Test-Path $ReleaseDataDir)) {
    New-Item -ItemType Directory -Path $ReleaseDataDir -Force | Out-Null
}

# Ensure base runner DLLs and executable are present
Copy-Item "d:\mepharma\frontend\build\windows\x64\runner\Release\*.dll" "$ReleaseDir\" -Force
Copy-Item "d:\mepharma\frontend\build\windows\x64\runner\Release\mepharma.exe" "$ReleaseDir\mepharma_variant.exe" -Force
Copy-Item "d:\mepharma\frontend\build\windows\x64\runner\Release\mepharma.exe" "$ReleaseDir\mepharma.exe" -Force
Copy-Item "d:\mepharma\frontend\build\windows\x64\runner\Release\data\icudtl.dat" "$ReleaseDataDir\icudtl.dat" -Force

# Synchronize assembled Variant AOT binary and flutter_assets
$AssembledAppSo = Join-Path $AssembledDir "windows\app.so"
$AssembledAssets = Join-Path $AssembledDir "flutter_assets"
$TargetAppSo = Join-Path $ReleaseDataDir "app.so"
$TargetAssets = Join-Path $ReleaseDataDir "flutter_assets"

if (Test-Path $AssembledAppSo) {
    Copy-Item $AssembledAppSo $TargetAppSo -Force
    Write-Host "Updated Variant AOT binary: $TargetAppSo" -ForegroundColor Green
}
if (Test-Path $AssembledAssets) {
    Copy-Item $AssembledAssets\* $TargetAssets -Recurse -Force
    Write-Host "Updated Variant flutter assets: $TargetAssets" -ForegroundColor Green
}

# 3. Create / Retrieve Variant Digital Signature
Write-Host "`n[3/5] Resolving Variant Digital Code Signing Certificate..." -ForegroundColor Yellow
$certThumbprint = "A79A4DCE9E067920664B98723E5A5FA21DBD386D"
$cert = Get-Item "Cert:\CurrentUser\My\$certThumbprint" -ErrorAction SilentlyContinue

if (-not $cert) {
    Write-Host "Creating new cryptographic Code Signing certificate for MePharma Variant..." -ForegroundColor Cyan
    $cert = New-SelfSignedCertificate `
        -Type CodeSigningCert `
        -Subject "CN=MePharma Systems (Variant Edition), O=MePharma Systems, OU=POS Variant Client, C=SD" `
        -KeySpec Signature `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddYears(5) `
        -FriendlyName "MePharma Variant Code Signing"
}

Write-Host "Certificate Subject: $($cert.Subject)" -ForegroundColor Green
Write-Host "Certificate Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green

# Digitally sign payload binaries
Write-Host "Digitally signing variant release executables and libraries..." -ForegroundColor Cyan
$binariesToSign = Get-ChildItem "$ReleaseDir\*.exe", "$ReleaseDir\*.dll"
foreach ($b in $binariesToSign) {
    Set-AuthenticodeSignature -Certificate $cert -FilePath $b.FullName -HashAlgorithm SHA256 | Out-Null
    Write-Host "  Signed: $($b.Name)" -ForegroundColor Gray
}

# 4. Compile Inno Setup Script
Write-Host "`n[4/5] Compiling Inno Setup script ($IssFile)..." -ForegroundColor Yellow
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

& "$IsccExe" "$IssFile"
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup compilation failed with exit code $LASTEXITCODE"
}
Write-Host "Inno Setup compilation completed successfully!" -ForegroundColor Green

# 5. Sign the Output Installer and provide alternate name variants
Write-Host "`n[5/5] Digitally signing installer and packaging variants..." -ForegroundColor Yellow
$PrimaryInstaller = Join-Path $OutputDir "MePharma_Variant_Setup.exe"

if (-not (Test-Path $PrimaryInstaller)) {
    throw "Primary installer executable not found at: $PrimaryInstaller"
}

# Sign primary installer
Set-AuthenticodeSignature -Certificate $cert -FilePath $PrimaryInstaller -HashAlgorithm SHA256 | Out-Null
Write-Host "Primary installer digitally signed: $PrimaryInstaller" -ForegroundColor Green

# Generate appname_varient.exe and mepharma_variant.exe aliases
$VarientCopy1 = Join-Path $OutputDir "mepharma_varient.exe"
$VarientCopy2 = Join-Path $OutputDir "MePharma_Varient.exe"
$VarientCopy3 = Join-Path $OutputDir "mepharma_variant.exe"

Copy-Item $PrimaryInstaller $VarientCopy1 -Force
Copy-Item $PrimaryInstaller $VarientCopy2 -Force
Copy-Item $PrimaryInstaller $VarientCopy3 -Force

Set-AuthenticodeSignature -Certificate $cert -FilePath $VarientCopy1 -HashAlgorithm SHA256 | Out-Null
Set-AuthenticodeSignature -Certificate $cert -FilePath $VarientCopy2 -HashAlgorithm SHA256 | Out-Null
Set-AuthenticodeSignature -Certificate $cert -FilePath $VarientCopy3 -HashAlgorithm SHA256 | Out-Null

Write-Host "`n==================================================" -ForegroundColor Green
Write-Host "  MePharma Variant Installer Built Successfully!" -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Host "Generated Installers:" -ForegroundColor Cyan
Get-ChildItem -Path $OutputDir -Filter "*varian*.exe" | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize
Get-ChildItem -Path $OutputDir -Filter "*varien*.exe" | Select-Object Name, Length, LastWriteTime | Format-Table -AutoSize

Write-Host "`nDigital Signature Verification:" -ForegroundColor Cyan
Get-AuthenticodeSignature $PrimaryInstaller | Format-List SignerCertificate, Status, Path
