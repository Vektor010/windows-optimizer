# ==============================================================================
#  NOVERSE APP & BROWSER OPTIMIZER
#  Based on app-guides (Discord, Chromium/Yandex/Brave, SteelSeries, Spotify)
# ==============================================================================

$ErrorActionPreference = "SilentlyContinue"

function Optimize-Discord {
    $discordPath = "$env:APPDATA\discord"
    $settingsPath = Join-Path $discordPath "settings.json"
    if (Test-Path $settingsPath) {
        try {
            $json = Get-Content $settingsPath -Raw | ConvertFrom-Json
            $json.enableHardwareAcceleration = $false
            $json.debugLogging = $false
            $json.OPEN_ON_STARTUP = $false
            $json | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
            Write-Host "[OK] Discord settings.json optimized (HW Accel OFF, Logging OFF, Startup OFF)" -ForegroundColor Green
        } catch {
            Write-Host "[!] Could not update Discord settings: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[-] Discord settings.json not found in $discordPath" -ForegroundColor DarkGray
    }
}

function Optimize-ChromiumBrowsers {
    # Covers Yandex, Chrome, Edge, Brave policies
    $policies = @(
        "HKLM:\SOFTWARE\Policies\YandexBrowser",
        "HKLM:\SOFTWARE\Policies\Google\Chrome",
        "HKLM:\SOFTWARE\Policies\BraveSoftware\Brave",
        "HKLM:\SOFTWARE\Policies\Microsoft\Edge"
    )

    foreach ($pol in $policies) {
        if (-not (Test-Path $pol)) { New-Item -Path $pol -Force | Out-Null }
        # 1. Disable running background apps when browser is closed
        Set-ItemProperty -Path $pol -Name "BackgroundModeEnabled" -Type DWord -Value 0 -Force
        # 2. Disable metrics / telemetry reporting
        Set-ItemProperty -Path $pol -Name "MetricsReportingEnabled" -Type DWord -Value 0 -Force
    }
    Write-Host "[OK] Browser policies applied (Yandex/Chrome/Brave/Edge background processes disabled, telemetry OFF)" -ForegroundColor Green
}

function Disable-SteelSeriesSonar {
    $services = @("SteelSeriesSonar", "SteelSeriesGGClient", "SteelSeriesAudioService")
    $found = $false
    foreach ($s in $services) {
        if (Get-Service $s -ErrorAction SilentlyContinue) {
            Stop-Service $s -Force -ErrorAction SilentlyContinue
            Set-Service $s -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Host "[OK] SteelSeries Sonar service disabled: $s" -ForegroundColor Green
            $found = $true
        }
    }
    if (-not $found) {
        Write-Host "[-] SteelSeries GG / Sonar services not detected on this system" -ForegroundColor DarkGray
    }
}

Write-Host "--- Applying Noverse App Guides Tweaks ---" -ForegroundColor Cyan
Optimize-Discord
Optimize-ChromiumBrowsers
Disable-SteelSeriesSonar
Write-Host "--- Done ---" -ForegroundColor Cyan
