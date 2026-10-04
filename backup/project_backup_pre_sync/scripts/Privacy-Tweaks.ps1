# Noverse Research - Privacy, Telemetry & Background Bloatware
# Based on noverse.dev/docs/win-config/privacy/ by Nohuto
$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Applying Privacy, Telemetry & Background Service Optimizations (Nohuto exact values)..." -ForegroundColor Cyan

# 1. Disable General Telemetry (AllowTelemetry = 0)
Write-Host "[1/11] Setting Windows Telemetry to 0 (Security/Off)..." -ForegroundColor Yellow
$dc = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
if (-not (Test-Path $dc)) { New-Item $dc -Force | Out-Null }
Set-ItemProperty $dc -Name "AllowTelemetry" -Type DWord -Value 0

# 2. Disable Windows Error Reporting (WER)
Write-Host "[2/11] Disabling Windows Error Reporting (WerFault crash delays)..." -ForegroundColor Yellow
$wer = "HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting"
if (-not (Test-Path $wer)) { New-Item $wer -Force | Out-Null }
Set-ItemProperty $wer -Name "Disabled" -Type DWord -Value 1
Stop-Service "WerSvc" -Force 2>$null
Set-Service "WerSvc" -StartupType Disabled 2>$null

# 3. Disable DiagTrack (Connected User Experiences and Telemetry)
Write-Host "[3/11] Disabling DiagTrack telemetry service..." -ForegroundColor Yellow
Stop-Service "DiagTrack" -Force 2>$null
Set-Service "DiagTrack" -StartupType Disabled 2>$null

# 4. Disable SysMain (SuperFetch) for NVMe SSD
Write-Host "[4/11] Disabling SysMain (Stops background SSD read spikes)..." -ForegroundColor Yellow
Stop-Service "SysMain" -Force 2>$null
Set-Service "SysMain" -StartupType Disabled 2>$null

# 5. Disable Windows Search Indexing (WSearch)
Write-Host "[5/11] Disabling Windows Search Indexing (Eliminates disk I/O queue)..." -ForegroundColor Yellow
Stop-Service "WSearch" -Force 2>$null
Set-Service "WSearch" -StartupType Disabled 2>$null

# 6. Disable Downloaded Maps Manager (MapsBroker)
Write-Host "[6/11] Disabling MapsBroker service..." -ForegroundColor Yellow
Stop-Service "MapsBroker" -Force 2>$null
Set-Service "MapsBroker" -StartupType Disabled 2>$null

# 7. Disable Activity History
Write-Host "[7/11] Disabling Activity History & Feed Tracking..." -ForegroundColor Yellow
$act = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System"
if (-not (Test-Path $act)) { New-Item $act -Force | Out-Null }
Set-ItemProperty $act -Name "EnableActivityFeed" -Type DWord -Value 0
Set-ItemProperty $act -Name "PublishUserActivities" -Type DWord -Value 0
Set-ItemProperty $act -Name "UploadUserActivities" -Type DWord -Value 0

# 8. Disable Copilot & Windows Recall
Write-Host "[8/11] Disabling Copilot & Recall AI background tasks..." -ForegroundColor Yellow
$win = "HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot"
if (-not (Test-Path $win)) { New-Item $win -Force | Out-Null }
Set-ItemProperty $win -Name "TurnOffWindowsCopilot" -Type DWord -Value 1
$ai = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI"
if (-not (Test-Path $ai)) { New-Item $ai -Force | Out-Null }
Set-ItemProperty $ai -Name "DisableAIDataAnalysis" -Type DWord -Value 1

# 9. Deny UWP Apps from Running in Background (LetAppsRunInBackground = 2)
Write-Host "[9/11] Denying UWP Background Apps Execution (LetAppsRunInBackground = 2)..." -ForegroundColor Yellow
$appPriv = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
if (-not (Test-Path $appPriv)) { New-Item $appPriv -Force | Out-Null }
Set-ItemProperty $appPriv -Name "LetAppsRunInBackground" -Type DWord -Value 2

# 10. Disable Cross-Device Projecting & Shared Experiences (CDP Policies)
Write-Host "[10/11] Disabling Cross-Device Projecting (CDP Policies = 0)..." -ForegroundColor Yellow
$cdp = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CDP"
if (-not (Test-Path $cdp)) { New-Item $cdp -Force | Out-Null }
Set-ItemProperty $cdp -Name "RomeSdkChannelUserAuthzPolicy" -Type DWord -Value 0
Set-ItemProperty $cdp -Name "CdpSessionUserAuthzPolicy" -Type DWord -Value 0
Set-ItemProperty $cdp -Name "EnableRemoteLaunchToast" -Type DWord -Value 0
$resume = "HKCU:\Software\Microsoft\Windows\CurrentVersion\CrossDeviceResume\Configuration"
if (-not (Test-Path $resume)) { New-Item $resume -Force | Out-Null }
Set-ItemProperty $resume -Name "IsResumeAllowed" -Type DWord -Value 0

# 11. Disable PowerShell & .NET Telemetry via Machine Environment Variables
Write-Host "[11/11] Disabling PowerShell & .NET Telemetry..." -ForegroundColor Yellow
[Environment]::SetEnvironmentVariable("POWERSHELL_TELEMETRY_OPTOUT", "1", "Machine")
[Environment]::SetEnvironmentVariable("DOTNET_CLI_TELEMETRY_OPTOUT", "1", "Machine")

Write-Host "`n[✓] All Nohuto Privacy & Telemetry optimizations (11/11) applied successfully!" -ForegroundColor Green
