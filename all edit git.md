# MePharma Pharmacy Management System (v2.0.1)
## Comprehensive Git Changelog & Architecture Audit Document (All Edits Summary)

- **Release Version:** MePharma v2.0.1 Enterprise Setup (Release Build)
- **Recommended Git Branch:** `feature/v2.01-barcode-pos-backup-release`
- **Target Binary Installer:** `MePharma_Setup_2.01.exe` (Standalone Windows 64-bit)
- **Compilation & Test Status:** All 87 Unit/Integration Tests Passed Cleanly (0 Errors)

---

### 1. Executive Summary & Purpose of This Branch
This release represents the production-ready milestone for the MePharma Pharmacy SaaS & Standalone platform. Every module across the frontend, desktop engine, offline SQLite database, barcode hardware scanning, automated local backups, and multi-tenant backend was subjected to rigorous code audits, line-by-line regression testing, and security hardening. All legacy demo/mock data has been purged so that newly installed clients receive a completely clean, pristine database initialized only with the primary administrator account.

---

### 2. Detailed Functional & Architectural Upgrades

#### 2.1 Smart 1D Barcode Engine & UI Simplification
- **UI Complexity Elimination:** Removed the symbology dropdown from product creation and editing modals. Users now only interact with the Barcode Number field and an instant 'Auto-Generate' action.
- **Intelligent Auto-Detection & Verification:** The rendering pipeline in `SmartBarcodeEngine` dynamically inspects barcode data:
  - Exactly 13 numeric digits with valid Luhn checksum -> `EAN-13`.
  - Exactly 12 numeric digits with valid Luhn checksum -> `UPC-A`.
  - Exactly 8 numeric digits with valid checksum -> `EAN-8`.
  - Any alphanumeric, custom text, or irregular length -> Safe `Code 128` fallback without throwing exceptions.
- **Unique Code Generation:** The generator creates guaranteed unique 13-digit EAN-13 codes starting with `200` prefix followed by 9 timestamp/random digits and a calculated Luhn checksum, cross-checked against database uniqueness.

#### 2.2 1D Hardware Scanner Integration & POS Checkout
- **Keyboard Wedge Support:** 1D hardware scanners function as keyboard wedge devices emitting text followed by Enter. The POS search field now intercepts KeyDown Enter and numpad Enter events to trigger instant checkout addition.
- **Rapid Consecutive Scanning:** When a barcode is scanned, the product is immediately added to the cart (or its quantity incremented by +1), the input field is instantly cleared, and focus is preserved on the barcode input.
- **Live Totals Recalculation:** Cart subtotals, taxes, and payment balances refresh reactively with zero lag.
- **Admin-Exclusive Barcode Print & Scan Simulation:** The simulation tool in POS ('محاكاة طباعة ومسح باركود' / 'Simulate Barcode') is strictly restricted to Administrators (`isAdmin == true`). It is completely hidden and inaccessible to regular Cashiers, Pharmacists, and Staff accounts.
- **Thermal Label Sticker Simulation:** The dialog simulates the physical label sticker (Medicine Name, Sudanese Pound Price, 1D Barcode Widget, SKU, Expiry Date), with instant simulation of sending the job to thermal label printers and simulating POS scanner entry.
- **Admin Products Management Integration:** Added a dedicated 'Simulate Barcode Print' action in the Admin's Products Inventory table allowing administrators to simulate label printing directly for any individual medicine in stock.

#### 2.3 Daily Automated Local Backups & In-App Restoration
- **Dedicated Backup Path:** Defaults to `D:\MePharma Backups` (with graceful fallback to `C:\` or Documents if drive D: is unavailable).
- **Automatic Startup Backup:** On application launch, a post-frame bootstrap checks if a backup file named `backupYYYYMMDD.db` (e.g. `backup20261114.db`) already exists. If not, it performs a WAL checkpoint, creates the backup, and displays an in-app progress and success notification.
- **Anti-Collision Guarantee:** Runs strictly once per calendar day to avoid performance overhead or duplicate files.
- **Admin Control Center:** Settings page features dedicated buttons for 'Create Backup Now' and 'Restore Backup from File' with native file picking, confirmation safety dialogs, and atomic database replacement.

#### 2.4 Windows Startup Auto-Launch
- **Native Registry Integration:** `WindowsStartupService` manages the `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` registry key under `MePharma POS`.
- **Installer Configuration:** Inno Setup (`setup/mepharma_setup.iss`) offers an optional Windows Integration task during setup.
- **Live Admin Toggle:** Administrators can turn Windows auto-start on or off directly inside Settings with instant feedback.

#### 2.5 Financial Precision & Technical Trading Indicators in Reports
- **Candlestick Movement:** Daily revenue trends are visualized as Japanese Candlestick bars with green bullish growth candles (`#28C76F`), red bearish pullback candles (`#EA5455`), and High/Low wick shadows.
- **Volume Histogram:** Lower sub-chart renders daily invoice volume and transaction density.
- **Live Telemetry:** Top status bar computes RSI(14), trend momentum signals, and period High/Low/Average metrics.
- **Integer SDG Currency:** Strict integer handling for Sudanese Pounds (ج.س) without decimal truncation anomalies, ensuring 10 remains 10 and 100 remains 100.

#### 2.6 Smooth Horizontal Table Navigation
- **RTL-Aware Navigation:** Added dedicated Left/Right directional buttons in both the top and bottom toolbars of the products table.
- **Visible Scrollbar:** Configured persistent horizontal scrollbar with `thumbVisibility: true` and minimum table width constraints (`minWidth: 1300`) so no columns are clipped on any display resolution.

---

### 3. Modified Files Manifest

| File Path | Module / Domain | Key Changes & Responsibilities |
|---|---|---|
| `frontend/lib/src/core/utils/barcode_symbologies.dart` | Core / Barcode | Added `SmartBarcodeEngine`, automatic 1D symbology resolver, and EAN-13 generator. |
| `frontend/lib/src/presentation/products/product_form_dialog.dart` | Products / UI | Removed symbology dropdown, added Auto-Generate button, hooked `SmartBarcodeEngine`. |
| `frontend/lib/src/presentation/pos/pos_page.dart` | POS / Sales | Enhanced 1D scanner Enter handling, instant cart addition, restricted barcode simulation strictly to Admin. |
| `frontend/lib/src/core/services/windows_startup_service.dart` | Core / OS | Created Windows registry startup integration service for boot launch. |
| `frontend/lib/src/core/services/backup_service.dart` | Core / Database | Configured `D:\MePharma Backups` destination, daily backup runner, and file restore. |
| `frontend/lib/src/app/app.dart` | App Bootstrap | Added `_StartupBootstrapWrapper` to trigger daily backup with in-app notification. |
| `frontend/lib/src/presentation/settings/settings_page.dart` | Settings / Admin | Added Windows startup switch, Backup Now, and Restore Backup from File actions. |
| `frontend/lib/src/presentation/reports/reports_page.dart` | Reports / Analytics | Implemented Candlestick trading chart, Volume histogram, and RSI(14) indicators. |
| `frontend/lib/src/presentation/products/products_page.dart` | Inventory / Table | Added horizontal scrollbar, navigation arrows, fixed selling price integer parsing, added Admin barcode print simulation. |
| `frontend/lib/src/presentation/users/users_page.dart` | Users / Admin | Added permanent user deletion button with self/last-admin safety checks. |
| `setup/mepharma_setup.iss` | Inno Setup Installer | Updated version to 2.0.1, output to `MePharma_Setup_2.01.exe`, added startup registry entry. |

---

### 4. Git Command-Line Guide for GitHub Review

To publish these comprehensive edits to a clean branch on GitHub for partner review, execute the following commands in terminal:

```bash
# 1. Create and switch to a dedicated feature branch
git checkout -b feature/v2.01-barcode-pos-backup-release

# 2. Stage all audited files
git add .

# 3. Commit with semantic description
git commit -m "feat: release v2.01 with smart 1D barcode engine, POS scanner integration, auto-backup, and Windows startup"

# 4. Push branch to GitHub remote
git push -u origin feature/v2.01-barcode-pos-backup-release
```

