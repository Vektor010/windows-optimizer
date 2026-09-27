<#
================================================================================
Имя твика:              Оптимизация конфигурации Spotify Desktop (Spotify-Config)
Что делает:             Перенаправляет вызовы к оптимизированному модулю Spotify-Tweaks.ps1
Источник / Категория:   Gaming & System Optimizer: Audio & Media Players Tuning
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0)]
    [ValidateSet("Apply", "Restore", "Status")]
    [string]$Action,

    [Parameter()]
    [switch]$Apply,

    [Parameter()]
    [switch]$Restore,

    [Parameter()]
    [switch]$Quiet
)

$targetScript = Join-Path $PSScriptRoot "Spotify-Tweaks.ps1"
if (Test-Path -LiteralPath $targetScript) {
    & $targetScript @PSBoundParameters
} else {
    Write-Host "[-] Скрипт Spotify-Tweaks.ps1 не найден: $targetScript" -ForegroundColor Red
}
