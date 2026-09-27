<#
================================================================================
Имя твика:              Переключатель служб и драйверов Logitech G HUB (LGHUB-Toggle)
Что делает:             Перенаправляет вызовы к оптимизированному модулю LGHUB-Tweaks.ps1
Источник / Категория:   Gaming & System Optimizer: Peripherals & Drivers Tuning
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Enable", "Disable", "Restore", "Status")]
    [string]$Action,

    [Parameter()]
    [switch]$Enable,

    [Parameter()]
    [switch]$Disable,

    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

$targetScript = Join-Path $PSScriptRoot "LGHUB-Tweaks.ps1"
if (Test-Path -LiteralPath $targetScript) {
    & $targetScript @PSBoundParameters
} else {
    Write-Host "[-] Скрипт LGHUB-Tweaks.ps1 не найден: $targetScript" -ForegroundColor Red
}
