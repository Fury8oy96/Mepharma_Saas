# MePharma Windows Installer (Inno Setup)

This directory contains the Inno Setup configuration and build automation for creating the standalone Windows installer (`MePharma_Setup.exe`).

## Features

- **Interactive Environment Selection Wizard**:
  - **Standalone Local SQLite (Offline Mode)**: Automatically configures MePharma to run with 100% offline local SQLite storage and bcrypt authentication without requiring Docker or a web server.
  - **Online Server API (Cloud / Network Mode)**: Prompts for custom API server URL and Branch ID to connect to a centralized backend or Docker container.
- **Auto Configuration Injection**: Writes `api_config.json` directly into the installation directory.
- **Desktop & Start Menu Shortcuts**: Creates shortcuts with app icon and uninstaller support.
- **High Compression**: Packaged using `lzma2/ultra64` solid compression.

---

## How to Build the Installer

### Prerequisites
1. **Flutter SDK** (configured with Windows desktop support).
2. **Inno Setup 6** (download from [jrsoftware.org](https://jrsoftware.org/isdl.php) or via Winget: `winget install JRSoftware.InnoSetup`).

---

### Option 1: One-Click Build Script (Recommended)
Run the batch file or PowerShell script:
```cmd
setup\build_installer.bat
```
or
```powershell
powershell -ExecutionPolicy Bypass -File setup\build_installer.ps1
```

This script will:
1. Build the Flutter Windows Release bundle (`flutter build windows --release`).
2. Detect the Inno Setup compiler (`ISCC.exe`).
3. Compile `mepharma_setup.iss` into `setup\Output\MePharma_Setup_v1.0.0.exe`.

---

### Option 2: Using Inno Setup Compiler GUI
1. Open Inno Setup Compiler GUI.
2. Open `setup\mepharma_setup.iss`.
3. First ensure you have run `flutter build windows --release` in the `frontend` folder.
4. Click **Build -> Compile** (or press `Ctrl + F9`).
5. Your installer will be generated in `setup\Output\`.
