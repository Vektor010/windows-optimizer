#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Устанавливает и регистрирует утилиту сбора системной информации NVFetch
#    в профиль текущего пользователя PowerShell ($PROFILE).
#    Копирует NVFetch.ps1 в каталог %LOCALAPPDATA%\Optimizer и регистрирует глобальную
#    функцию/команду 'nvfetch', доступную в любой новой сессии терминала.
#
# 2. ЗАЧЕМ:
#    Позволяет вызывать быструю диагностику системы командой `nvfetch` (аналог
#    neofetch / fastfetch) прямо из консоли без указания полного пути к скрипту.
#
# 3. ПОСЛЕДСТВИЯ:
#    - Создаёт директорию %LOCALAPPDATA%\Optimizer (если отсутствует).
#    - Копирует файл NVFetch.ps1 в %LOCALAPPDATA%\Optimizer\NVFetch.ps1 (не перемещает,
#      сохраняя исходник).
#    - Создаёт файл профиля PowerShell (если отсутствует) и безопасно регистрирует
#      функцию 'nvfetch' без повторного дублирования при повторных запусках.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (любые редакции, x64). Полная поддержка Windows
#    PowerShell 5.1 и PowerShell 7+. Не требует прав Администратора.
#
# 5. ОТКАТ:
#    Запуск с параметром -Uninstall (или -Restore) удаляет регистрацию функции
#    'nvfetch' из $PROFILE и удаляет скопированный файл %LOCALAPPDATA%\Optimizer\NVFetch.ps1.
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий System / win-config:
#    https://github.com/system-optimizer
#    Документация Optimizer:
#    Gaming & System Optimizer Reference
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$SourcePath,

    [Parameter()]
    [Alias('Restore', 'r', 'u')]
    [switch]$Uninstall
)

$targetDir  = [System.IO.Path]::Combine($env:LOCALAPPDATA, 'Optimizer')
$targetFile = [System.IO.Path]::Combine($targetDir, 'NVFetch.ps1')

# Режим отката (деинсталляция)
if ($Uninstall) {
    if (Test-Path -LiteralPath $PROFILE) {
        $profileContent = Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
        if ($profileContent -match 'function\s+nvfetch\b') {
            $updatedContent = $profileContent -replace '(?m)^\s*(?:#.*?\r?\n)*\s*function\s+nvfetch\b.*?\}(?:\r?\n)?', ''
            [System.IO.File]::WriteAllText($PROFILE, $updatedContent.TrimEnd() + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
            Write-Host "[+] Команда 'nvfetch' удалена из профиля: $PROFILE" -ForegroundColor Green
        }
    }
    if (Test-Path -LiteralPath $targetFile) {
        Remove-Item -LiteralPath $targetFile -Force -ErrorAction SilentlyContinue
        Write-Host "[+] Файл $targetFile успешно удалён." -ForegroundColor Green
    }
    if (Test-Path -LiteralPath $targetDir) {
        $remaining = Get-ChildItem -LiteralPath $targetDir -ErrorAction SilentlyContinue
        if (-not $remaining) {
            Remove-Item -LiteralPath $targetDir -Force -ErrorAction SilentlyContinue
        }
    }
    return
}

# Поиск исходного файла NVFetch.ps1
$candidateSources = @(
    $SourcePath,
    (Join-Path $PSScriptRoot 'NVFetch.ps1'),
    (Join-Path $PSScriptRoot '..\scripts\NVFetch.ps1'),
    (Join-Path $env:USERPROFILE 'Downloads\NVFetch.ps1')
)

$resolvedSource = $null
foreach ($cand in $candidateSources) {
    if (-not [string]::IsNullOrWhiteSpace($cand) -and (Test-Path -LiteralPath $cand)) {
        $resolvedSource = (Get-Item -LiteralPath $cand).FullName
        break
    }
}

if (-not $resolvedSource) {
    throw 'Не удалось найти исходный файл NVFetch.ps1. Укажите путь через параметр -SourcePath.'
}

# Создание целевой директории
if (-not (Test-Path -LiteralPath $targetDir)) {
    [System.IO.Directory]::CreateDirectory($targetDir) | Out-Null
}

# Безопасное копирование без удаления источника
Copy-Item -LiteralPath $resolvedSource -Destination $targetFile -Force
Write-Host "[+] NVFetch.ps1 скопирован в: $targetFile" -ForegroundColor Green

# Подготовка директории профиля PowerShell
$profileDir = [System.IO.Path]::GetDirectoryName($PROFILE)
if (-not [string]::IsNullOrWhiteSpace($profileDir) -and -not (Test-Path -LiteralPath $profileDir)) {
    [System.IO.Directory]::CreateDirectory($profileDir) | Out-Null
}

$functionCode = @"

# Optimizer NVFetch CLI integration
function nvfetch { & "$targetFile" @args }
"@

$existingProfile = if (Test-Path -LiteralPath $PROFILE) {
    Get-Content -Path $PROFILE -Raw -ErrorAction SilentlyContinue
} else {
    ''
}

if ($existingProfile -match 'function\s+nvfetch\b') {
    $updatedProfile = $existingProfile -replace '(?m)^\s*(?:#.*?\r?\n)*\s*function\s+nvfetch\b.*?\}(?:\r?\n)?', ''
    $updatedProfile = $updatedProfile.TrimEnd() + $functionCode + [Environment]::NewLine
    [System.IO.File]::WriteAllText($PROFILE, $updatedProfile, [System.Text.Encoding]::UTF8)
    Write-Host "[+] Функция 'nvfetch' в `$PROFILE обновлена." -ForegroundColor Green
} else {
    $newProfile = $existingProfile.TrimEnd() + $functionCode + [Environment]::NewLine
    [System.IO.File]::WriteAllText($PROFILE, $newProfile, [System.Text.Encoding]::UTF8)
    Write-Host "[+] Функция 'nvfetch' успешно зарегистрирована в: $PROFILE" -ForegroundColor Green
}

# Регистрация функции в текущей сессии
${function:nvfetch} = [scriptblock]::Create("& `"$targetFile`" @args")
Write-Host "[i] Команда 'nvfetch' теперь доступна в текущей и всех последующих сессиях консоли." -ForegroundColor Cyan
