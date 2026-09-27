#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Добавляет или удаляет каскадное контекстное меню "Hashes" в Проводнике Windows
#    для всех типов файлов (*) и папок (Directory) с возможностью быстрого
#    вычисления хэш-сумм выбранным алгоритмом (All, MD5, SHA1, SHA256, SHA384,
#    SHA512, MACTripleDES, RIPEMD160). Копирует движок HashGen.ps1 в %LOCALAPPDATA%\Optimizer.
#
# 2. ЗАЧЕМ:
#    Для мгновенной проверки контрольных сумм и целостности скачанных дистрибутивов,
#    образов и файлов прямо из Проводника без необходимости установки сторонних
#    тяжеловесных утилит (типа HashTab, 7-Zip GUI или сторонних шелл-расширений).
#
# 3. ПОСЛЕДСТВИЯ:
#    В контекстном меню файлов и папок появляется каскадный пункт "Hashes". При клике
#    на выбранный алгоритм открывается консоль PowerShell, вычисляет контрольные суммы
#    и сохраняет лог в файл Hashes.txt в папке с файлом.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). В Windows 11 пункт доступен
#    через "Показать дополнительные параметры" (Shift+F10) или в основном меню,
#    если включен классический вид контекстного меню.
#
# 5. ОТКАТ:
#    Запуск скрипта с параметром -Restore (или -Uninstall) полностью удаляет ветки
#    реестра HKCU:\Software\Classes\*\shell\Hashes, HKCU:\Software\Classes\Directory\shell\Hashes,
#    HKCU:\Software\Classes\hashGen.ContextMenu и файл %LOCALAPPDATA%\Optimizer\HashGen.ps1.
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий System win-config:
#    https://github.com/system-optimizer
#    Документация Optimizer:
#    Gaming & System Optimizer Reference
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [switch]$Restore,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

function Write-NvLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Tag = "[+]",
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$TagColor = [ConsoleColor]::Green,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$MsgColor = [ConsoleColor]::White
    )
    Write-Host -NoNewline $Tag -ForegroundColor $TagColor
    Write-Host " $Message" -ForegroundColor $MsgColor
}

$nvfolder = Join-Path $env:LOCALAPPDATA "Optimizer"
$gen = Join-Path $nvfolder "HashGen.ps1"
$extended = "hashGen.ContextMenu"
$shell = "HKCU:\Software\Classes\$extended\shell"

$menuTargets = @(
    "HKCU:\Software\Classes\*\shell\Hashes",
    "HKCU:\Software\Classes\Directory\shell\Hashes"
)

$legacyTargets = @(
    "HKCU:\Software\Classes\*\shell\NV-Hash",
    "HKCU:\Software\Classes\Directory\shell\NV-Hash"
)

# ---------------------------------------------------------
# Режим отката / удаления (-Restore или -Uninstall)
# ---------------------------------------------------------
if ($Restore -or $Uninstall) {
    if ($PSCmdlet.ShouldProcess("Explorer Context Menu", "Удалить пункты Hashes и файл HashGen.ps1")) {
        Write-NvLog -Tag "[*]" -Message "Удаление контекстного меню Hashes и движка HashGen..." -TagColor Yellow -MsgColor Cyan

        foreach ($path in ($menuTargets + $legacyTargets + @("HKCU:\Software\Classes\$extended"))) {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
                Write-NvLog -Tag "[+]" -Message "Удален ключ реестра: $path"
            }
        }

        foreach ($genFile in @($gen, (Join-Path $nvfolder "hashGen.ps1"))) {
            if (Test-Path -LiteralPath $genFile) {
                Remove-Item -LiteralPath $genFile -Force -ErrorAction SilentlyContinue
                Write-NvLog -Tag "[+]" -Message "Удален файл скрипта: $genFile"
            }
        }

        if ((Test-Path -LiteralPath $nvfolder) -and ((Get-ChildItem -LiteralPath $nvfolder -Force -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0)) {
            Remove-Item -LiteralPath $nvfolder -Force -Recurse -ErrorAction SilentlyContinue
            Write-NvLog -Tag "[+]" -Message "Удалена пустая директория: $nvfolder"
        }

        Write-NvLog -Tag "[+]" -Message "Контекстное меню Hashes успешно удалено." -TagColor Green -MsgColor White
    }
    return
}

# ---------------------------------------------------------
# Режим установки контекстного меню
# ---------------------------------------------------------
if ($PSCmdlet.ShouldProcess("Explorer Context Menu", "Установить каскадное меню Hashes")) {
    Write-NvLog -Tag "[*]" -Message "Установка каскадного контекстного меню Hashes..." -TagColor Cyan -MsgColor White

    if (!(Test-Path -LiteralPath $nvfolder)) {
        New-Item -ItemType Directory -Path $nvfolder -Force | Out-Null
    }

    # Поиск локального исходника HashGen.ps1 (совместимо с PS 5.1 и PS 7+)
    $candidatePaths = [System.Collections.Generic.List[string]]::new()
    if ($PSScriptRoot) {
        $candidatePaths.Add((Join-Path $PSScriptRoot "HashGen.ps1"))
        $candidatePaths.Add((Join-Path $PSScriptRoot "hashGen.ps1"))
        $parent = Split-Path $PSScriptRoot -Parent
        if ($parent) {
            $candidatePaths.Add((Join-Path $parent "scripts\HashGen.ps1"))
            $candidatePaths.Add((Join-Path $parent "misc\assets\HashGen.ps1"))
        }
    }
    $candidatePaths.Add((Join-Path $home "Downloads\HashGen.ps1"))
    $candidatePaths.Add((Join-Path $home "Downloads\hashGen.ps1"))

    $sourceFound = $false
    foreach ($cand in $candidatePaths) {
        if ($cand -and (Test-Path -LiteralPath $cand)) {
            try {
                $resolved = (Resolve-Path -LiteralPath $cand -ErrorAction SilentlyContinue).ProviderPath
                if ($resolved -and (Test-Path -LiteralPath $resolved)) {
                    Copy-Item -LiteralPath $resolved -Destination $gen -Force
                    Write-NvLog -Tag "[+]" -Message "Скопирован локальный HashGen.ps1 из: $resolved"
                    $sourceFound = $true
                    break
                }
            } catch {
                $null = $_
            }
        }
    }

    if (-not $sourceFound) {
        Write-NvLog -Tag "[*]" -Message "Локальный HashGen.ps1 не найден. Загрузка из официального репозитория System..." -TagColor Yellow -MsgColor Yellow
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
            $uri = "https://raw.githubusercontent.com/System/win-config/refs/heads/main/misc/assets/HashGen.ps1"
            Invoke-WebRequest -Uri $uri -OutFile $gen -UseBasicParsing -TimeoutSec 15
            Write-NvLog -Tag "[+]" -Message "HashGen.ps1 успешно загружен в: $gen"
        } catch {
            throw "Не удалось загрузить HashGen.ps1: $($_.Exception.Message)"
        }
    }

    # Очистка старых веток перед регистрацией
    foreach ($old in ($menuTargets + $legacyTargets + @("HKCU:\Software\Classes\$extended"))) {
        if (Test-Path -LiteralPath $old) {
            Remove-Item -LiteralPath $old -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # Создание каскадного обработчика hashGen.ContextMenu\shell
    New-Item -Path $shell -Force | Out-Null

    $entries = @(
        @{Key='All';          Label='All Hashes';   Argument='All'},
        @{Key='MD5';          Label='MD5';          Argument='MD5'},
        @{Key='SHA1';         Label='SHA1';         Argument='SHA1'},
        @{Key='SHA256';       Label='SHA256';       Argument='SHA256'},
        @{Key='SHA384';       Label='SHA384';       Argument='SHA384'},
        @{Key='SHA512';       Label='SHA512';       Argument='SHA512'},
        @{Key='MACTripleDES'; Label='MACTripleDES'; Argument='MACTripleDES'},
        @{Key='RIPEMD160';    Label='RIPEMD160';    Argument='RIPEMD160'}
    )

    foreach ($entry in $entries) {
        $entryPath = Join-Path $shell $entry.Key
        New-Item -Path $entryPath -Force | Out-Null
        Set-ItemProperty -LiteralPath $entryPath -Name "MUIVerb" -Value $entry.Label

        $cmdPath = Join-Path $entryPath "command"
        New-Item -Path $cmdPath -Force | Out-Null
        $command = ('powershell.exe -NoLogo -NoExit -ExecutionPolicy Bypass -File "{0}" -nvstringin "%1" -Algorithm "{1}"' -f $gen, $entry.Argument)
        Set-Item -LiteralPath $cmdPath -Value $command
    }

    # Привязка каскадного меню к * (файлы) и Directory (папки)
    foreach ($menu in $menuTargets) {
        New-Item -Path $menu -Force | Out-Null
        Set-ItemProperty -LiteralPath $menu -Name "MUIVerb" -Value "Hashes"
        Set-ItemProperty -LiteralPath $menu -Name "ExtendedSubCommandsKey" -Value $extended
    }

    Write-NvLog -Tag "[+]" -Message "Каскадное контекстное меню 'Hashes' успешно зарегистрировано." -TagColor Green -MsgColor White
}
