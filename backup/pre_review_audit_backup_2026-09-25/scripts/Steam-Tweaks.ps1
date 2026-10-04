# Noverse Research - Steam Optimization & CEF Killer
# Applies Steam-Config.ps1 & manages umpdc.dll (NoSteamWebHelper)

param (
    [switch]$InstallCEFKiller,
    [switch]$RemoveCEFKiller,
    [switch]$RunConfigOnly
)

$ErrorActionPreference = "SilentlyContinue"
$steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue).SteamPath
if (-not $steamPath -or -not (Test-Path $steamPath)) {
    $steamPath = "C:\Program Files (x86)\Steam"
}

Write-Host ">>> Steam Optimization Suite (Noverse Research)" -ForegroundColor Cyan
Write-Host "Detected Steam Path: $steamPath" -ForegroundColor DarkGray

# 1. Run Nohuto's Steam-Config.ps1
$configScript = Join-Path $PSScriptRoot "Steam-Config.ps1"
if (Test-Path $configScript) {
    Write-Host "`n[1/3] Applying Steam configuration to localconfig.vdf..." -ForegroundColor Yellow
    & $configScript
    Write-Host " [+] Steam settings applied (Overlay off, Low bandwidth/perf mode on, Community feeds off)" -ForegroundColor Green
} else {
    Write-Host " [-] Steam-Config.ps1 not found in scripts folder" -ForegroundColor Red
}

# 2. Steam Client Registry Optimization (GPU & WebHelper Acceleration)
Write-Host "`n[2/3] Configuring Steam Registry Parameters..." -ForegroundColor Yellow
$steamReg = "HKCU:\Software\Valve\Steam"
if (Test-Path $steamReg) {
    Set-ItemProperty -Path $steamReg -Name "GPUAccelWebViewsV3" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "H264HWAccel" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "SmoothScrollWebViews" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "DWriteEnable" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $steamReg -Name "DPIScaling" -Value 0 -Type DWord -Force
    Write-Host " [+] Steam registry values applied: GPUAccelWebViewsV3=0, H264HWAccel=0, SmoothScrollWebViews=0, DWriteEnable=0" -ForegroundColor Green
} else {
    Write-Host " [!] Steam registry key not found (Steam might not be installed yet)" -ForegroundColor DarkGray
}

# 3. Manage umpdc.dll (NoSteamWebHelper)
$umpdcPath = Join-Path $steamPath "umpdc.dll"

if ($RemoveCEFKiller) {
    if (Test-Path $umpdcPath) {
        $p = Get-Process steam* -ErrorAction SilentlyContinue
        if ($p) { $p | Stop-Process -Force; Start-Sleep -Seconds 1 }
        Remove-Item -Path $umpdcPath -Force
        Write-Host "`n[3/3] Removed umpdc.dll (SteamWebHelper will run normally)" -ForegroundColor Yellow
    } else {
        Write-Host "`n[3/3] umpdc.dll is not currently installed." -ForegroundColor DarkGray
    }
} elseif ($InstallCEFKiller) {
    Write-Host "`n[3/3] Installing umpdc.dll (NoSteamWebHelper v5.0.2)..." -ForegroundColor Yellow
    try {
        $p = Get-Process steam* -ErrorAction SilentlyContinue
        if ($p) { 
            Write-Host " Closing Steam to install DLL..." -ForegroundColor DarkGray
            $p | Stop-Process -Force
            Start-Sleep -Seconds 2
        }
        $url = "https://github.com/Aetopia/NoSteamWebHelper/releases/download/v5.0.2/umpdc.dll"
        Invoke-WebRequest -Uri $url -OutFile $umpdcPath -Headers @{"User-Agent"="PowerShell"}
        Write-Host " [+] umpdc.dll installed successfully into Steam directory!" -ForegroundColor Green
        Write-Host "     When any game launches, all steamwebhelper.exe processes will automatically terminate." -ForegroundColor Cyan
        Write-Host "     When the game closes, Steam UI will automatically restore." -ForegroundColor Cyan
    } catch {
        Write-Host " [-] Failed to download/install umpdc.dll: $_" -ForegroundColor Red
    }
}

Write-Host "`n[✓] Steam optimization completed!" -ForegroundColor Green
