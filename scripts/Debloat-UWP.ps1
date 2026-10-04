# ==============================================================================
# Gaming & System Optimizer - UWP Debloat (Очистка встроенных приложений)
# Удалитель мусорных приложений Windows для снижения фоновой активности.
# ==============================================================================
Write-Host ">>> Запуск очистки встроенных приложений Windows (UWP Debloat)..." -ForegroundColor Cyan

$bloatApps = @(
    "*3DBuilder*", "*WindowsAlarms*", "*Appconnector*", "*FeedbackHub*",
    "*GetHelp*", "*ZuneMusic*", "*ZuneVideo*", "*BingFinance*", "*BingNews*",
    "*BingSports*", "*BingWeather*", "*MicrosoftOfficeHub*", "*MicrosoftSolitaireCollection*",
    "*MicrosoftStickyNotes*", "*OneConnect*", "*People*", "*SkypeApp*", "*SoundRecorder*",
    "*WindowsMaps*", "*XboxApp*", "*XboxOneSmartGlass*", "*WindowsFeedbackHub*",
    "*Cortana*", "*MixedReality*", "*Getstarted*", "*Todos*", "*Wallet*"
)

foreach ($app in $bloatApps) {
    Write-Host "Удаление $app..." -ForegroundColor Yellow
    Get-AppxPackage -Name $app -AllUsers -ErrorAction SilentlyContinue | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like $app } | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}

Write-Host "Очистка завершена!" -ForegroundColor Green