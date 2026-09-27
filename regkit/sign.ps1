#Requires -Version 5.1
<#
================================================================================
# 1. ЧТО ДЕЛАЕТ:
#    Служебный скрипт автоматизированной цифровой подписи сборок и исполняемых файлов
#    утилиты RegKit (signtool.exe /sha1 /fd SHA256 /tr ... /td SHA256).
#
# 2. ЗАЧЕМ:
#    Используется в процессе релизной сборки (CI/CD / Release Pipeline) проекта RegKit
#    для подписания скомпилированных бинарных файлов (regkit.exe, dll) сертификатом
#    разработчика Noverse / Nohuto с фиксацией штампа времени (DigiCert Timestamp Server).
#
# 3. ПОСЛЕДСТВИЯ:
#    Добавляет цифровую подпись Authenticode в заголовок целевых исполняемых файлов ($Path),
#    что предотвращает ложные срабатывания SmartScreen и антивирусных систем при запуске.
#
# 4. СОВМЕСТИМОСТЬ:
#    Windows 10 / Windows 11 (x64). Требует установленный Windows SDK (Windows Kits 10/11)
#    с утилитой signtool.exe и действующий сертификат подписи кода (Code Signing Certificate).
#
# 5. ОТКАТ:
#    Не требуется (бинарные файлы пересобираются или подпись удаляется через signtool remove).
#
# 6. ИСТОЧНИК:
#    Официальный репозиторий проекта RegKit от Nohuto:
#    https://github.com/nohuto/regkit
================================================================================
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
    [string[]]$Path,

    [Parameter()]
    [string]$Thumbprint,

    [Parameter()]
    [string]$CertSubject = "Noverse (nohuto)",

    [Parameter()]
    [string]$TimeStampServer = "http://timestamp.digicert.com",

    [Parameter()]
    [string]$Description = "RegKit",

    [Parameter()]
    [string]$DescriptionUrl = "https://github.com/nohuto/regkit"
)

begin {
    # 1. Поиск действующего сертификата подписи кода
    $cert = $null
    if ($Thumbprint) {
        $cert = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue |
            Where-Object { $_.Thumbprint -eq $Thumbprint -and $_.NotAfter -gt (Get-Date) } |
            Select-Object -First 1
    } else {
        $cert = Get-ChildItem -Path Cert:\CurrentUser\My, Cert:\LocalMachine\My -CodeSigningCert -ErrorAction SilentlyContinue |
            Where-Object { ($_.FriendlyName -eq $CertSubject -or $_.Subject -like "*$CertSubject*") -and $_.NotAfter -gt (Get-Date) } |
            Sort-Object -Property NotAfter -Descending |
            Select-Object -First 1
    }

    if (-not $cert) {
        Write-Warning "Сертификат подписи кода ('$CertSubject') не найден в хранилище сертификатов или истек его срок действия."
        return
    }

    # 2. Поиск утилиты signtool.exe в системе и Windows SDK
    $signtoolPath = $null
    $cmd = Get-Command -Name "signtool.exe" -ErrorAction SilentlyContinue
    if ($cmd) {
        $signtoolPath = $cmd.Source
    } else {
        $signtoolCandidates = [System.Collections.Generic.List[string]]::new()
        if (${env:ProgramFiles(x86)}) {
            $signtoolCandidates.Add("${env:ProgramFiles(x86)}\Windows Kits\10\bin\*\x64\signtool.exe")
            $signtoolCandidates.Add("${env:ProgramFiles(x86)}\Windows Kits\11\bin\*\x64\signtool.exe")
        }
        if ($env:ProgramFiles) {
            $signtoolCandidates.Add("$env:ProgramFiles\Windows Kits\10\bin\*\x64\signtool.exe")
            $signtoolCandidates.Add("$env:ProgramFiles\Windows Kits\11\bin\*\x64\signtool.exe")
        }

        $found = Get-ChildItem -Path $signtoolCandidates -ErrorAction SilentlyContinue |
            Sort-Object -Property FullName |
            Select-Object -Last 1
        if ($found) {
            $signtoolPath = $found.FullName
        }
    }

    if (-not $signtoolPath) {
        Write-Error "Утилита Windows SDK signtool.exe не найдена. Установите Windows Kits 10/11 для подписи сборок."
        return
    }
}

process {
    if (-not $cert -or -not $signtoolPath) { return }

    # 3. Подписание целевых файлов Authenticode SHA256
    foreach ($target in $Path) {
        if (-not (Test-Path -LiteralPath $target)) {
            Write-Warning "Целевой файл для подписи не найден: $target"
            continue
        }

        $resolvedTarget = (Resolve-Path -LiteralPath $target).Path
        if ($PSCmdlet.ShouldProcess($resolvedTarget, "Sign with Authenticode (SHA256, $Description)")) {
            Write-Verbose "Подписание файла: $resolvedTarget через $signtoolPath"
            & $signtoolPath sign /sha1 $cert.Thumbprint /fd SHA256 /tr $TimeStampServer /td SHA256 /d $Description /du $DescriptionUrl "`"$resolvedTarget`""
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Ошибка при подписании файла $resolvedTarget (signtool exit code: $LASTEXITCODE)"
            } else {
                Write-Host "[+] Файл успешно подписан: $resolvedTarget" -ForegroundColor Green
            }
        }
    }
}