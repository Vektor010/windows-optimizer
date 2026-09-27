#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Вычисляет криптографические контрольные суммы (хэши) для указанного файла
#    или рекурсивно для всех файлов в директории с использованием одного или всех
#    алгоритмов: All, MD5, SHA1, SHA256, SHA384, SHA512, MACTripleDES, RIPEMD160.
#    Результаты выводятся в консоль в реальном времени и сохраняются в файл Hashes.txt.
#
# 2. ЗАЧЕМ:
#    Для быстрой проверки целостности, оригинальности и неизменности скачанных
#    файлов, установщиков игр, драйверов и архивов без стороннего ПО с помощью
#    нативных криптопровайдеров .NET Framework (System.Security.Cryptography).
#
# 3. ПОСЛЕДСТВИЯ:
#    В консоли отображаются вычисленные хэши выбранных алгоритмов; создаётся или
#    дополняется текстовый отчёт Hashes.txt в папке с проверяемым файлом/каталогом.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (x64). Полная поддержка Windows PowerShell 5.1 и
#    PowerShell 7+. Устаревшие алгоритмы MACTripleDES и RIPEMD160 нативно
#    поддерживаются в Windows PowerShell 5.1 (в PS 7+ безопасно помечаются как
#    неподдерживаемые средой .NET Core без сбоя остальных алгоритмов).
#
# 5. ОТКАТ:
#    Не требуется (утилита только для чтения данных). Созданный файл Hashes.txt
#    может быть удален в любой момент вручную.
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий System / win-config:
#    https://github.com/system-optimizer
#    Документация Optimizer:
#    Gaming & System Optimizer Reference
================================================================================
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [Alias('Path', 'InputPath', 'LiteralPath')]
    [string]$nvstringin,

    [Parameter(Position = 1)]
    [ValidateSet('All', 'MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'RIPEMD160')]
    [string]$algorithm = 'All'
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Безопасная инициализация консоли (предотвращает сбои в headless-средах и перенаправленных потоках)
try {
    if ([System.Environment]::UserInteractive -and [System.Console]::WindowHeight -gt 0) {
        [System.Console]::Title = "Optimizer Hash Generator"
        [System.Console]::BackgroundColor = [ConsoleColor]::Black
        Clear-Host
    }
} catch {
    $null = $_
}

function Write-NvLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$HighlightMessage,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [Parameter(Mandatory = $false)]
        [string]$Sequence = "",
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$TimeColor = [ConsoleColor]::DarkGray,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$HighlightColor = [ConsoleColor]::White,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$MessageColor = [ConsoleColor]::White,
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$SequenceColor = [ConsoleColor]::White
    )
    $time = " [{0:HH:mm:ss}]" -f (Get-Date)
    Write-Host -ForegroundColor $TimeColor $time -NoNewline
    Write-Host -NoNewline " "
    Write-Host -ForegroundColor $HighlightColor $HighlightMessage -NoNewline
    Write-Host -ForegroundColor $MessageColor " $Message" -NoNewline
    if ($Sequence) {
        Write-Host -ForegroundColor $SequenceColor " $Sequence"
    } else {
        Write-Host ""
    }
}

# Поддержка позиционных аргументов
if ([string]::IsNullOrWhiteSpace($nvstringin) -and $args.Count -gt 0) {
    $nvstringin = ($args -join ' ')
}

if ([string]::IsNullOrWhiteSpace($nvstringin)) {
    Write-NvLog -HighlightMessage "[-]" -Message "Не указан путь к файлу или папке." -Sequence "Используйте: -Path <путь>" -HighlightColor Red -SequenceColor DarkGray
    return
}

$nvstringin = $nvstringin.Trim().Trim('"')
try {
    $nvstringin = (Resolve-Path -LiteralPath $nvstringin -ErrorAction Stop).ProviderPath
} catch {
    Write-NvLog -HighlightMessage "[-]" -Message "Указанный путь не существует:" -Sequence "$nvstringin" -HighlightColor Red -SequenceColor DarkGray
    return
}

function Get-NvHasherInstance {
    param([string]$Name)
    try {
        switch ($Name.ToUpperInvariant()) {
            'MD5'          { return [System.Security.Cryptography.MD5]::Create() }
            'SHA1'         { return [System.Security.Cryptography.SHA1]::Create() }
            'SHA256'       { return [System.Security.Cryptography.SHA256]::Create() }
            'SHA384'       { return [System.Security.Cryptography.SHA384]::Create() }
            'SHA512'       { return [System.Security.Cryptography.SHA512]::Create() }
            'MACTRIPLEDES' { return [System.Security.Cryptography.MACTripleDES]::Create() }
            'RIPEMD160'    { return [System.Security.Cryptography.RIPEMD160]::Create() }
            default        { return $null }
        }
    } catch {
        return $null
    }
}

function Get-NvFileHash {
    param(
        [string]$Path,
        [string[]]$Algorithms
    )
    $result = @{}
    $hashers = [System.Collections.Generic.List[psobject]]::new()

    foreach ($algo in $Algorithms) {
        $hasherInstance = Get-NvHasherInstance -Name $algo
        if ($hasherInstance) {
            $hashers.Add([pscustomobject]@{ Name = $algo; Hasher = $hasherInstance })
        } else {
            $result[$algo] = "Unsupported on current runtime"
        }
    }

    if ($hashers.Count -eq 0) {
        return $result
    }

    $buffer = New-Object byte[] 1048576 # 1 MB буфер для высокой скорости чтения NVMe/SSD
    $stream = $null
    $empty = New-Object byte[] 0

    try {
        $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
            foreach ($entry in $hashers) {
                $entry.Hasher.TransformBlock($buffer, 0, $read, $null, 0) | Out-Null
            }
        }
        foreach ($entry in $hashers) {
            $entry.Hasher.TransformFinalBlock($empty, 0, 0) | Out-Null
            $result[$entry.Name] = [System.BitConverter]::ToString($entry.Hasher.Hash).Replace("-", "")
        }
    } finally {
        if ($stream) {
            $stream.Dispose()
        }
        foreach ($entry in $hashers) {
            if ($entry.Hasher) {
                $entry.Hasher.Dispose()
            }
        }
    }
    return $result
}

if (!(Test-Path -LiteralPath $nvstringin)) {
    Write-NvLog -HighlightMessage "[-]" -Message "Указанный путь не найден:" -Sequence "$nvstringin" -HighlightColor Red -SequenceColor DarkGray
    return
}

$isContainer = Test-Path -LiteralPath $nvstringin -PathType Container
$nvoutdir = if ($isContainer) { $nvstringin } else { Split-Path $nvstringin -Parent }
$nvout = Join-Path $nvoutdir "Hashes.txt"

$targetFiles = if ($isContainer) {
    Get-ChildItem -LiteralPath $nvstringin -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -ne $nvout }
} else {
    @(Get-Item -LiteralPath $nvstringin)
}

if (-not $targetFiles -or $targetFiles.Count -eq 0) {
    Write-NvLog -HighlightMessage "[-]" -Message "Нет файлов для вычисления хэшей в:" -Sequence "$nvstringin" -HighlightColor Red -SequenceColor DarkGray
    return
}

$allAlgorithms = @('MD5', 'SHA1', 'SHA256', 'SHA384', 'SHA512', 'MACTripleDES', 'RIPEMD160')
$activeAlgorithms = if ($algorithm -ieq 'All') { $allAlgorithms } else { @($algorithm.ToUpperInvariant()) }
$outputLines = [System.Collections.Generic.List[string]]::new()

foreach ($file in $targetFiles) {
    $outputLines.Add("[$($file.Name)]")
    try {
        $computedHashes = Get-NvFileHash -Path $file.FullName -Algorithms $activeAlgorithms
        foreach ($algo in $activeAlgorithms) {
            $hashValue = $computedHashes[$algo]
            if ($hashValue -and $hashValue -notlike "Unsupported*") {
                Write-NvLog -HighlightMessage "[+]" -Message "${algo}:" -Sequence "$hashValue" -HighlightColor Green -SequenceColor Cyan
                $outputLines.Add("${algo}: $hashValue")
            } elseif ($hashValue -like "Unsupported*") {
                Write-NvLog -HighlightMessage "[-]" -Message "${algo}:" -Sequence "Не поддерживается средой .NET Core (требуется PS 5.1)" -HighlightColor Yellow -SequenceColor DarkGray
                $outputLines.Add("${algo}: Unsupported on current .NET runtime")
            } else {
                Write-NvLog -HighlightMessage "[-]" -Message "Ошибка вычисления хэша $algo" -Sequence "($($file.Name))" -HighlightColor Red -SequenceColor DarkGray
                $outputLines.Add("${algo}: Error")
            }
        }
    } catch {
        foreach ($algo in $activeAlgorithms) {
            Write-NvLog -HighlightMessage "[-]" -Message "Ошибка чтения файла $algo" -Sequence "($($file.Name)): $($_.Exception.Message)" -HighlightColor Red -SequenceColor DarkGray
            $outputLines.Add("${algo}: Error ($($_.Exception.Message))")
        }
    }
    $outputLines.Add("")
}

try {
    $outputLines | Out-File -FilePath $nvout -Encoding UTF8 -Append
    Write-NvLog -HighlightMessage "[+]" -Message "Хэши успешно сохранены в:" -Sequence "$nvout" -HighlightColor Green -SequenceColor DarkGray
} catch {
    Write-NvLog -HighlightMessage "[-]" -Message "Не удалось записать отчёт Hashes.txt:" -Sequence "$($_.Exception.Message)" -HighlightColor Red -SequenceColor DarkGray
}