# ==============================================================================
# Gaming & System Optimizer - Службы (Отключение мусора)
# ==============================================================================
Write-Host ">>> Зачистка фоновых служб Windows (Перфекционист/Киберспорт)..." -ForegroundColor Cyan

$junkServices = @(
    "Fax", "shpamsvc", "RetailDemo", "DPS", "WdiServiceHost", "WdiSystemHost", 
    "WalletService", "wisvc", "EntAppSvc", "PhoneSvc", "AJRouter", "tzautoupdate",
    "MapsBroker", "lfsvc", "DiagTrack", "WerSvc", "SysMain", "WSearch", "PcaSvc"
)

foreach ($svc in $junkServices) {
    if (Get-Service -Name $svc -ErrorAction SilentlyContinue) {
        Write-Host " Отключение службы: $svc..." -ForegroundColor DarkGray
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
        Set-Service -Name $svc -StartupType Disabled -ErrorAction SilentlyContinue
        # Хардкорное отключение через реестр, если Set-Service не сработал
        Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\$svc" -Name "Start" -Value 4 -Type DWord -ErrorAction SilentlyContinue
    }
}

Write-Host "[OK] Мусорные службы отключены. Фоновая активность снижена!" -ForegroundColor Green