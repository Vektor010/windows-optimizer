# ==============================================================================
# Gaming & System Optimizer - Modern Fluent Cursors
# Скачивание и установка плавного курсора Windows 11 (Fluent).
# ==============================================================================
Write-Host ">>> Запуск установки Modern Cursor Scheme (Windows 11 Fluent)..." -ForegroundColor Cyan

$cursorDir = "$env:systemroot\Cursors\FluentCursor"
if (-not (Test-Path $cursorDir)) {
    Write-Host "Создание папки курсора..." -ForegroundColor Yellow
    New-Item -Path $cursorDir -ItemType Directory -Force | Out-Null
}

$zipPath = "$env:TEMP\FluentCursor.zip"
$extractPath = "$env:TEMP\FluentCursorExtract"

Write-Host "Скачивание ассетов Fluent Cursor с GitHub..." -ForegroundColor Yellow
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri "https://github.com/tony-sung/FluentCursor-Win11/archive/refs/heads/main.zip" -OutFile $zipPath -UseBasicParsing

Write-Host "Распаковка курсоров..." -ForegroundColor Yellow
if (Test-Path $extractPath) { Remove-Item $extractPath -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$sourceCursors = "$extractPath\FluentCursor-Win11-main\DarkCursors"
if (Test-Path $sourceCursors) {
    Copy-Item -Path "$sourceCursors\*" -Destination $cursorDir -Force -Recurse
}

# Очистка Temp
Remove-Item $zipPath -Force -ErrorAction SilentlyContinue
Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "Применение новой схемы курсора в реестр..." -ForegroundColor Yellow
$regPath = "HKCU:\Control Panel\Cursors"

# Удаляем базовый размер, чтобы кастомные курсоры не искажались
Remove-ItemProperty $regPath -Name "CursorBaseSize" -ErrorAction SilentlyContinue

# Прописываем пути к каждому курсору
$scheme = @{
    "Arrow" = "arrow.cur"
    "Help" = "help.cur"
    "AppStarting" = "appstarting.ani"
    "Wait" = "wait.ani"
    "Crosshair" = "crosshair.cur"
    "IBeam" = "ibeam.cur"
    "NWPen" = "nwpen.cur"
    "No" = "no.cur"
    "SizeNS" = "sizens.cur"
    "SizeWE" = "sizewe.cur"
    "SizeNWSE" = "sizenwse.cur"
    "SizeNESW" = "sizenesw.cur"
    "SizeAll" = "sizeall.cur"
    "UpArrow" = "uparrow.cur"
    "Hand" = "hand.cur"
}

foreach ($key in $scheme.Keys) {
    $curPath = "$cursorDir\$($scheme[$key])"
    Set-ItemProperty $regPath -Name $key -Type ExpandString -Value $curPath
}

# Отключаем дефолтную схему (чтобы Windows читала ключи выше)
Set-ItemProperty $regPath -Name "(default)" -Type String -Value "Fluent Cursor Dark"
Set-ItemProperty $regPath -Name "Scheme Source" -Type DWord -Value 2

Write-Host "Обновление параметров системы..." -ForegroundColor Yellow

$csharp = @'
using System.Runtime.InteropServices;
public class MouseParams {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, string pvParam, uint fWinIni);
}
'@
Add-Type -TypeDefinition $csharp -ErrorAction SilentlyContinue
[MouseParams]::SystemParametersInfo(0x0057, 0, $null, 3) | Out-Null

Write-Host "[OK] Modern Cursor Dark успешно скачан и активирован!" -ForegroundColor Green
Start-Sleep 2