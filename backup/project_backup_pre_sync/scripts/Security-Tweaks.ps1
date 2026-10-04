# Noverse Research - Security & Virtualization Tweaks
# Based on noverse.dev/docs/win-config/security/ by Nohuto
$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Applying Security, Virtualization & Kernel Stability Tweaks..." -ForegroundColor Cyan

# 1. Disable VBS / HVCI (Virtualization-Based Security)
Write-Host "[1/5] Disabling VBS / Core Isolation (Hyper-V overhead elimination)..." -ForegroundColor Yellow
$dg = "HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard"
if (-not (Test-Path $dg)) { New-Item $dg -Force | Out-Null }
Set-ItemProperty $dg -Name "EnableVirtualizationBasedSecurity" -Type DWord -Value 0
$sc = "$dg\Scenarios\HypervisorEnforcedCodeIntegrity"
if (-not (Test-Path $sc)) { New-Item $sc -Force | Out-Null }
Set-ItemProperty $sc -Name "Enabled" -Type DWord -Value 0

# 2. Disable WPBT (Windows Platform Binary Table OEM BIOS injection)
Write-Host "[2/5] Disabling WPBT (Blocks OEM motherboard background bloatware injection)..." -ForegroundColor Yellow
Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "SmpDisableWpbtExecution" -Type DWord -Value 1

# 3. Increase TDR Delay (GPU timeout recovery)
Write-Host "[3/5] Increasing TDR Delay (8s) for RTX 5080 stability during shader compiling..." -ForegroundColor Yellow
$gfx = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
Set-ItemProperty $gfx -Name "TdrDelay" -Type DWord -Value 8
Set-ItemProperty $gfx -Name "TdrDdiDelay" -Type DWord -Value 8

# 4. Disable Delivery Optimization P2P seeding
Write-Host "[4/5] Disabling Delivery Optimization P2P (Stops network seeding of updates)..." -ForegroundColor Yellow
$do = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization"
if (-not (Test-Path $do)) { New-Item $do -Force | Out-Null }
Set-ItemProperty $do -Name "DODownloadMode" -Type DWord -Value 0

# 5. UAC Prompt on Secure Desktop
Write-Host "[5/5] Disabling PromptOnSecureDesktop (Instant UAC response without desktop dimming hitch)..." -ForegroundColor Yellow
Set-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" -Name "PromptOnSecureDesktop" -Type DWord -Value 0

Write-Host "`n[✓] Security, Virtualization & Kernel Stability tweaks applied!" -ForegroundColor Green
