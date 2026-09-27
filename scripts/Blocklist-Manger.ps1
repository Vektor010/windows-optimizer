# ==============================================================================
# Gaming & System Optimizer - Модификатор списков блокировки DNS и файла hosts
# Документация: Gaming & System Optimizer Reference
# Официальный источник: HaGeZi DNS Blocklists (https://github.com/hagezi/dns-blocklists)
#                       Steven Black Hosts (https://github.com/StevenBlack/hosts)
# ==============================================================================
# Описание:
#   Утилита для управления системным файлом hosts (C:\Windows\System32\drivers\etc\hosts).
#   Позволяет загружать проверенные списки фильтрации рекламы, трекеров телеметрии,
#   фишинговых ресурсов и вредоносного ПО (HaGeZi, Steven Black, 1Hosts, OISD).
#
# Что делает:
#   - Загружает официальные списки блокировок напрямую из репозиториев;
#   - Сжимает структуру (группирует до 9 доменов на строку по стандарту Windows TCP/IP);
#   - Устраняет дубликаты доменов через высокопроизводительный HashSet;
#   - Создает автоматическую резервную копию hosts.backup перед записью;
#   - Сбрасывает кэш распознавателя DNS (ipconfig /flushdns);
#   - Поддерживает как графический интерфейс (GUI), так и консольные флаги (-Default, -Minimal, -Maximum, -Restore).
#
# Влияние на систему:
#   DNS sinkhole (перенаправление на 0.0.0.0) блокирует телеметрические и рекламные
#   запросы на самом раннем этапе до установки TCP-соединения, экономя трафик и снижая CPU-оверхед.
# ==============================================================================

param(
    [switch]$Minimal,
    [switch]$Default,
    [switch]$Maximum,
    [switch]$Restore,
    [switch]$ShowGUI
)

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'
$nvhosts = "C:\Windows\System32\drivers\etc\hosts"
$nvhostsb = "$nvhosts.backup"

# Гарантия наличия файла hosts
if (-not (Test-Path $nvhosts)) {
    New-Item -Path $nvhosts -ItemType File -Force | Out-Null
}

# Каталог списков блокировки
$nvlists = @(
    @{
        Name = "Hagezi"
        Value = $false
        Column = "Col1"
        Link = "https://github.com/hagezi/dns-blocklists"
        Lists = @(
            @{ Name = "Light"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/light.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/light.txt" }
            @{ Name = "Normal"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/multi.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/multi.txt" }
            @{ Name = "Pro"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/pro.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt" }
            @{ Name = "Pro Mini"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.mini.txt" }
            @{ Name = "Pro++"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/pro.plus.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.txt" }
            @{ Name = "Pro++ Mini"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.plus.mini.txt" }
            @{ Name = "Ultimate"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/ultimate.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/ultimate.txt" }
            @{ Name = "Ultimate Mini"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/ultimate.mini.txt" }
            @{ Name = "Fakes/Scams/Traps"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/fake.txt" }
            @{ Name = "Pop-Up Ads"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/popupads.txt" }
            @{ Name = "TIF"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/tif.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt" }
            @{ Name = "TIF Medium"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.medium.txt" }
            @{ Name = "TIF Mini"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.mini.txt" }
            @{ Name = "DoH/VPN/TOR/Proxy Bypass"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/doh-vpn-proxy-bypass.txt" }
            @{ Name = "DoH Servers"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/doh.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/doh.txt" }
            @{ Name = "Unsupported Safesearch"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/nosafesearch.txt" }
            @{ Name = "Dynamic DNS"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/dyndns.txt" }
            @{ Name = "Badware Hoster"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/hoster.txt" }
            @{ Name = "URL Shortener"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/urlshortener.txt" }
            @{ Name = "Abused TLDs"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/spam-tlds-ublock.txt" }
            @{ Name = "DNS Rebind Protection"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adguard/dns-rebind-protection.txt" }
            @{ Name = "Anti Piracy"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/anti.piracy.txt" }
            @{ Name = "Gambling"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.txt" }
            @{ Name = "Gambling Medium"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.medium.txt" }
            @{ Name = "Gambling Mini"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/gambling.mini.txt" }
            @{ Name = "Social Networks"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/social.txt" }
            @{ Name = "NSFW"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/nsfw.txt" }
            @{ Name = "Native Microsoft"; Value = $false; Url = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/hosts/native.winoffice.txt"; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/native.winoffice.txt" }
            @{ Name = "Referral Domains"; Value = $false; Urlf = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/blocklist-referral-native.txt" }
        )
    },
    @{
        Name = "Steven Black"
        Column = "Col2"
        Value = $false
        Link = "https://github.com/StevenBlack/hosts"
        Lists = @(
            @{ Name = "Adware/Malware"; Value = $false; Url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts" }
            @{ Name = "Fakenews"; Value = $false; Url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-only/hosts" }
            @{ Name = "Gambling"; Value = $false; Url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/gambling-only/hosts" }
            @{ Name = "Porn"; Value = $false; Url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/porn-only/hosts" }
            @{ Name = "Social"; Value = $false; Url = "https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/social-only/hosts" }
        )
    },
    @{
        Name = "Badmojr"
        Column = "Col2"
        Value = $false
        Link = "https://o0.pages.dev"
        Lists = @(
            @{ Name = "Lite"; Value = $false; Url = "https://raw.githubusercontent.com/badmojr/1Hosts/master/Lite/hosts.win"; Urlf = "https://o0.pages.dev/Lite/adblock.txt" }
            @{ Name = "Pro"; Value = $false; Url = "https://raw.githubusercontent.com/badmojr/1Hosts/master/Pro/hosts.win"; Urlf = "https://o0.pages.dev/Pro/adblock.txt" }
            @{ Name = "Xtra"; Value = $false; Url = "https://raw.githubusercontent.com/badmojr/1Hosts/master/Xtra/hosts.win"; Urlf = "https://o0.pages.dev/Xtra/adblock.txt" }
        )
    },
    @{
        Name = "Dan Pollock"
        Column = "Col2"
        Value = $false
        Link = "https://someonewhocares.org/"
        Lists = @(
            @{ Name = "Zero"; Value = $false; Url = "https://someonewhocares.org/hosts/zero/" }
        )
    },
    @{
        Name = "OISD"
        Column = "Col3"
        Value = $false
        Link = "https://oisd.nl/"
        Lists = @(
            @{ Name = "Big"; Value = $false; Urlf = "https://big.oisd.nl/" }
            @{ Name = "Small"; Value = $false; Urlf = "https://small.oisd.nl/" }
            @{ Name = "NSFW"; Value = $false; Urlf = "https://nsfw.oisd.nl/" }
            @{ Name = "NSFW Small"; Value = $false; Urlf = "https://nsfw-small.oisd.nl/" }
        )
    },
    @{
        Name = "Stamus Labs / OpenSquat"
        Column = "Col3"
        Value = $false
        Link = "https://github.com/hagezi/dns-blocklists#new-newly-registered-domains-nrddga-"
        Lists = @(
            @{ Name = "NRD 7D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/nrd7.txt" }
            @{ Name = "NRD 14-8D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/nrd14-8.txt" }
            @{ Name = "NRD 21-15D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/nrd21-15.txt" }
            @{ Name = "NRD 28-22D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/nrd28-22.txt" }
            @{ Name = "NRD 35-29D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/nrd35-29.txt" }
            @{ Name = "DGA 7D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/dga7.txt" }
            @{ Name = "DGA 14D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/dga14.txt" }
            @{ Name = "DGA 30D"; Value = $false; Urlf = "https://gitlab.com/hagezi/mirror/-/raw/main/dns-blocklists/adblock/dga30.txt" }
        )
    },
    @{
        Name = "Peter Lowe"
        Column = "Col2"
        Value = $false
        Link = "https://pgl.yoyo.org/adservers/"
        Lists = @(
            @{ Name = "Ads"; Value = $false; Url = "https://pgl.yoyo.org/as/serverlist.php?hostformat=hosts;showintro=0" }
        )
    },
    @{
        Name = "Iam-py-test"
        Column = "Col2"
        Value = $false
        Link = "https://github.com/iam-py-test/my_filters_001"
        Lists = @(
            @{ Name = "Malware"; Value = $false; Url = "https://raw.githubusercontent.com/iam-py-test/my_filters_001/refs/heads/main/Alternative%20list%20formats/antimalware_hosts.txt"; Urlf = "https://raw.githubusercontent.com/iam-py-test/my_filters_001/refs/heads/main/antimalware.txt" }
            @{ Name = "Brave Clean-Up"; Value = $false; Urlf = "https://raw.githubusercontent.com/iam-py-test/my_filters_001/refs/heads/main/brave-clean-up.txt" }
            @{ Name = "DuckDuckGo Clean-Up"; Value = $false; Urlf = "https://raw.githubusercontent.com/iam-py-test/my_filters_001/refs/heads/main/duckduckgo-clean-up.txt" }
            @{ Name = "uBlock Combo"; Value = $false; Urlf = "https://raw.githubusercontent.com/iam-py-test/uBlock-combo/refs/heads/main/list.txt" }
            @{ Name = "VXVault Domains"; Value = $false; Url = "https://raw.githubusercontent.com/iam-py-test/vxvault_filter/refs/heads/main/hosts.txt"; Urlf = "https://raw.githubusercontent.com/iam-py-test/vxvault_filter/main/domains_file.txt" }
        )
    },
    @{
        Name = "Privacy Sexy"
        Column = "Col2"
        Value = $false
        Link = "https://privacy.sexy/"
        Lists = @(
            @{ Name = "Tracking"; Value = $false; Url = "https://github.com/5Noxi/Files/releases/download/hosts/privacysexy.txt" }
        )
    },
    @{
        Name = "Brave"
        Column = "Col3"
        Value = $false
        Link = "https://github.com/brave/adblock-lists/tree/master/brave-lists"
        Lists = @(
            @{ Name = "Twitch"; Value = $false; Urlf = "https://raw.githubusercontent.com/brave/adblock-lists/refs/heads/master/brave-lists/brave-twitch.txt" }
            @{ Name = "Experimental"; Value = $false; Urlf = "https://raw.githubusercontent.com/brave/adblock-lists/refs/heads/master/brave-lists/experimental.txt" }
        )
    }
)

# Функция применения списков
function Apply-Blocklists {
    param([array]$SelectedItems, [scriptblock]$LogCallback)

    if (-not (Test-Path $nvhostsb)) {
        Copy-Item -Path $nvhosts -Destination $nvhostsb -Force
    }

    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $buffer0 = [System.Collections.Generic.List[string]]::new()
    $buffer1 = [System.Collections.Generic.List[string]]::new()

    foreach ($sub in $SelectedItems) {
        if ($sub.Url) {
            try {
                if ($LogCallback) { & $LogCallback "[~]" "Загрузка '$($sub.Name)'" "Gray" } else { Write-Host "Загрузка '$($sub.Name)'..." -ForegroundColor Gray }
                $data = Invoke-RestMethod -Uri $sub.Url -UseBasicParsing -TimeoutSec 30
                $lines = $data -split "`r?`n"

                foreach ($line in $lines) {
                    $clean = ($line -replace '(::|#).*$', '').Trim()
                    if (-not $clean) { continue }

                    if ($clean -like "0.0.0.0*") {
                        $parts = $clean -split '\s+'
                        for ($idx = 1; $idx -lt $parts.Count; $idx++) {
                            $domain = $parts[$idx]
                            if ($domain -and $seen.Add($domain)) {
                                $buffer0.Add($domain)
                            }
                        }
                    } elseif ($clean -like "127.0.0.1*") {
                        if ($clean -match 'localhost|local') { continue }
                        $parts = $clean -split '\s+'
                        for ($idx = 1; $idx -lt $parts.Count; $idx++) {
                            $domain = $parts[$idx]
                            if ($domain -and $seen.Add($domain)) {
                                $buffer1.Add($domain)
                            }
                        }
                    }
                }

                if ($LogCallback) { & $LogCallback "[+]" "Список '$($sub.Name)' обработан (уникальных доменов: $($seen.Count))" "Green" } else { Write-Host " [+] Список '$($sub.Name)' обработан (уникальных доменов: $($seen.Count))" -ForegroundColor Green }
            } catch {
                if ($LogCallback) { & $LogCallback "[-]" "Ошибка загрузки '$($sub.Name)': $_" "Red" } else { Write-Host " [-] Ошибка загрузки '$($sub.Name)': $_" -ForegroundColor Red }
            }
        } else {
            if ($LogCallback) { & $LogCallback "[-]" "'$($sub.Name)' не поддерживает формат hosts" "Red" } else { Write-Host " [-] '$($sub.Name)' не поддерживает формат hosts" -ForegroundColor DarkGray }
        }
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $outputLines = [System.Collections.Generic.List[string]]::new()
    $outputLines.Add("# ==============================================================================")
    $outputLines.Add("# Optimizer Blocklists Hosts File (HaGeZi & Community DNS Filters)")
    $outputLines.Add("# Gaming & System Optimizer Reference")
    $outputLines.Add("# Всего заблокировано доменов: $($seen.Count)")
    $outputLines.Add("# Сгенерировано: $timestamp")
    $outputLines.Add("# ==============================================================================")
    $outputLines.Add("")

    # Группировка по 9 доменов на строку для 0.0.0.0
    for ($k = 0; $k -lt $buffer0.Count; $k += 9) {
        $count = [Math]::Min(9, $buffer0.Count - $k)
        $chunk = $buffer0.GetRange($k, $count)
        $outputLines.Add("0.0.0.0 $($chunk -join ' ')")
    }

    # Группировка по 9 доменов на строку для 127.0.0.1
    for ($k = 0; $k -lt $buffer1.Count; $k += 9) {
        $count = [Math]::Min(9, $buffer1.Count - $k)
        $chunk = $buffer1.GetRange($k, $count)
        $outputLines.Add("127.0.0.1 $($chunk -join ' ')")
    }

    try {
        [System.IO.File]::WriteAllLines($nvhosts, $outputLines, [System.Text.Encoding]::UTF8)
        ipconfig /flushdns | Out-Null
        if ($LogCallback) { & $LogCallback "[✓]" "Файл hosts успешно записан ($($seen.Count) доменов), DNS сброшен!" "Green" } else { Write-Host "`n[✓] Файл hosts успешно записан ($($seen.Count) доменов), DNS сброшен!" -ForegroundColor Green }
    } catch {
        if ($LogCallback) { & $LogCallback "[-]" "Не удалось записать файл hosts: $_" "Red" } else { Write-Host " [-] Не удалось записать файл hosts: $_" -ForegroundColor Red }
    }
}

# Функция отката к оригинальному hosts
function Restore-HostsFile {
    param([scriptblock]$LogCallback)
    if (Test-Path $nvhostsb) {
        try {
            $content = [System.IO.File]::ReadAllText($nvhostsb, [System.Text.Encoding]::UTF8)
            [System.IO.File]::WriteAllText($nvhosts, $content, [System.Text.Encoding]::UTF8)
            ipconfig /flushdns | Out-Null
            if ($LogCallback) { & $LogCallback "[✓]" "Оригинальный файл hosts восстановлен из резервной копии" "Green" } else { Write-Host "[✓] Оригинальный файл hosts восстановлен из hosts.backup" -ForegroundColor Green }
        } catch {
            if ($LogCallback) { & $LogCallback "[-]" "Ошибка восстановления: $_" "Red" } else { Write-Host "[-] Ошибка восстановления: $_" -ForegroundColor Red }
        }
    } else {
        if ($LogCallback) { & $LogCallback "[-]" "Резервная копия hosts.backup не найдена" "Red" } else { Write-Host "[-] Резервная копия hosts.backup не найдена" -ForegroundColor Red }
    }
}

# ------------------------------------------------------------------------------
# Консольные режимы автоматизации (CLI)
# ------------------------------------------------------------------------------
if ($Restore) {
    Write-Host ">>> Восстановление системного файла hosts..." -ForegroundColor Yellow
    Restore-HostsFile
    return
}

if ($Minimal) {
    Write-Host ">>> Применение профиля Minimal (HaGeZi Light)..." -ForegroundColor Cyan
    $targets = @(
        $nvlists[0].Lists.Where({ $_.Name -eq "Light" })[0]
    )
    Apply-Blocklists -SelectedItems $targets
    return
}

if ($Default) {
    Write-Host ">>> Применение профиля Default (HaGeZi Pro + Native Microsoft)..." -ForegroundColor Cyan
    $targets = @(
        $nvlists[0].Lists.Where({ $_.Name -eq "Pro" })[0],
        $nvlists[0].Lists.Where({ $_.Name -eq "Native Microsoft" })[0]
    )
    Apply-Blocklists -SelectedItems $targets
    return
}

if ($Maximum) {
    Write-Host ">>> Применение профиля Maximum (HaGeZi Pro++ + TIF + Native Microsoft)..." -ForegroundColor Cyan
    $targets = @(
        $nvlists[0].Lists.Where({ $_.Name -eq "Pro++" })[0],
        $nvlists[0].Lists.Where({ $_.Name -eq "TIF" })[0],
        $nvlists[0].Lists.Where({ $_.Name -eq "Native Microsoft" })[0]
    )
    Apply-Blocklists -SelectedItems $targets
    return
}

# Если не указан ни один из CLI флагов или указан -ShowGUI — запускаем интерактивный интерфейс
if (-not $ShowGUI -and ($Restore -or $Minimal -or $Default -or $Maximum)) {
    return
}

# ------------------------------------------------------------------------------
# Графический интерфейс (GUI Windows Forms)
# ------------------------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
if (-not ([System.Management.Automation.PSTypeName]'WinAPI').Type) {
    Add-Type -TypeDefinition 'using System;using System.Runtime.InteropServices;public class WinAPI{[DllImport("user32.dll")]public static extern bool ShowWindow(IntPtr hWnd,int nCmdShow);}'
}

$inputf = [System.Drawing.Font]::new('Segoe UI', 10, [System.Drawing.FontStyle]::Regular)
$blue = [System.Drawing.Color]::CornflowerBlue
$gray = [System.Drawing.Color]::FromArgb(40, 40, 40)
$white = [System.Drawing.Color]::White
$boxempty = [System.Drawing.Color]::Transparent

$nvmain = [System.Windows.Forms.Form]@{
    Text = 'Optimizer Blocklists Modifier'
    Size = [System.Drawing.Size]::new(1161, 700)
    StartPosition = 'CenterScreen'
    BackColor = [System.Drawing.Color]::FromArgb(28, 28, 28)
    FormBorderStyle = 'Sizable'
    Font = [System.Drawing.Font]::new('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
    MinimumSize = [System.Drawing.Size]::new(600, 200)
}

# Безопасная загрузка иконки без падения процесса
$icoPath = "$env:temp\Optimizer.ico"
if (-not (Test-Path $icoPath)) {
    try {
        Invoke-WebRequest -Uri "https://github.com/5Noxi/5Noxi/releases/download/Logo/Optimizer.ico" -OutFile $icoPath -UseBasicParsing -TimeoutSec 3 -ErrorAction SilentlyContinue
    } catch {
        $null = $_
    }
}
if (Test-Path $icoPath) {
    try {
        $nvmain.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon($icoPath)
    } catch {
        $null = $_
    }
}

$checkboxpanel = [System.Windows.Forms.Panel]@{
    Location = [System.Drawing.Point]::new(5, 35)
    Size = [System.Drawing.Size]::new(620, 590)
    BackColor = $gray
    BorderStyle = 'FixedSingle'
    AutoScroll = $true
}
$nvmain.Controls.Add($checkboxpanel)

$hostspanel = [System.Windows.Forms.Panel]@{
    Location = [System.Drawing.Point]::new(630, 5)
    Size = [System.Drawing.Size]::new(510, 440)
    BackColor = $gray
    BorderStyle = 'FixedSingle'
}
$nvmain.Controls.Add($hostspanel)

$hosts = [System.Windows.Forms.RichTextBox]@{
    Multiline = $true
    ReadOnly = $false
    ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Both
    WordWrap = $false
    BackColor = $gray
    ForeColor = $white
    Font = [System.Drawing.Font]::new('Consolas', 9)
    BorderStyle = 'None'
    Location = [System.Drawing.Point]::new(1, 1)
    Size = [System.Drawing.Size]::new(510, 440)
}
$hostspanel.Controls.Add($hosts)

$savehosts = New-Object System.Windows.Forms.Timer
$savehosts.Interval = 600
$hosts.Add_TextChanged({
    $savehosts.Stop()
    $savehosts.Start()
})
$savehosts.Add_Tick({
    $savehosts.Stop()
    try {
        if (-not (Test-Path $nvhosts)) { New-Item -ItemType File -Path $nvhosts -Force | Out-Null }
        [System.IO.File]::WriteAllText($nvhosts, $hosts.Text, [System.Text.Encoding]::UTF8)
        log "[+]" "Сохранены изменения hosts" "Green"
    } catch {
        log "[-]" "Не удалось сохранить hosts: $_" "Red"
    }
})

function Refresh-HostsPreview {
    if (Test-Path $nvhosts) {
        try {
            $hosts.Text = [System.IO.File]::ReadAllText($nvhosts, [System.Text.Encoding]::UTF8)
            log "[+]" "Предпросмотр hosts обновлен" "Green"
        } catch {
            log "[-]" "Не удалось прочитать hosts" "Red"
        }
    } else {
        log "[-]" "Файл hosts не найден" "Red"
    }
}

$logspanel = [System.Windows.Forms.Panel]@{
    Location = [System.Drawing.Point]::new(630, 450)
    Size = [System.Drawing.Size]::new(510, 205)
    BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    BorderStyle = 'FixedSingle'
}
$nvmain.Controls.Add($logspanel)

$logs = [System.Windows.Forms.RichTextBox]@{
    Multiline = $true
    ReadOnly = $true
    ScrollBars = [System.Windows.Forms.RichTextBoxScrollBars]::Vertical
    BackColor = [System.Drawing.Color]::FromArgb(40, 40, 40)
    ForeColor = $white
    Font = [System.Drawing.Font]::new('Consolas', 9)
    BorderStyle = 'None'
    Location = [System.Drawing.Point]::new(1, 1)
    Size = [System.Drawing.Size]::new(510, 205)
}
$logspanel.Controls.Add($logs)

function log {
    param (
        [string]$HighlightMessage,
        [string]$Message,
        [string]$ColorName = 'White'
    )
    $timestamp = "[{0:HH:mm:ss}]" -f (Get-Date)

    function append-color-text($text, $color) {
        $logs.SelectionStart = $logs.Text.Length
        $logs.SelectionColor = [System.Drawing.Color]::FromName($color)
        $logs.AppendText($text)
    }

    append-color-text "$timestamp " "DarkGray"
    append-color-text "$HighlightMessage " $ColorName
    append-color-text "$Message`r`n" "White"
    $logs.SelectionStart = $logs.Text.Length
    $logs.ScrollToCaret()
}

$nvmain.Add_Resize({
    $hostspanel.Width  = $nvmain.ClientSize.Width - $hostspanel.Left - 5
    $hostspanel.Height = [Math]::Max(200, $nvmain.ClientSize.Height - $hostspanel.Top - 215)
    $hosts.Width  = $hostspanel.ClientSize.Width - 2
    $hosts.Height = $hostspanel.ClientSize.Height - 2

    $logspanel.Top    = $hostspanel.Bottom + 5
    $logspanel.Width  = $nvmain.ClientSize.Width - $logspanel.Left - 5
    $logspanel.Height = [Math]::Max(100, $nvmain.ClientSize.Height - $logspanel.Top - 5)
    $logs.Width  = $logspanel.ClientSize.Width - 2
    $logs.Height = $logspanel.ClientSize.Height - 2
})

$checkboxes = @()
$columnY = @{ Col1 = 10; Col2 = 10; Col3 = 10 }
$columnlocation = @{
    "Col1" = @{ X = 10; Y = $columnY["Col1"] }
    "Col2" = @{ X = 240; Y = $columnY["Col2"] }
    "Col3" = @{ X = 450; Y = $columnY["Col3"] }
}

foreach ($blocklists in $nvlists) {
    $col = $blocklists.Column
    if (-not $columnlocation.ContainsKey($col)) { continue }

    $x = $columnlocation[$col].X
    $y = $columnY[$col]

    $listname = [System.Windows.Forms.Label]@{
        Text = $blocklists.Name
        ForeColor = 'CornflowerBlue'
        Location = [System.Drawing.Point]::new($x, $y)
        AutoSize = $true
        Tag = $blocklists
    }
    $listname.Add_Click({ Start-Process $this.Tag.Link })
    $checkboxpanel.Controls.Add($listname)
    $y += 23

    if ($blocklists.ContainsKey('Lists')) {
        foreach ($subOption in $blocklists.Lists) {
            $boxY = $y
            $labelY = $y - 2
            $box = [System.Windows.Forms.Panel]@{
                Size = [System.Drawing.Size]::new(13, 13)
                Location = [System.Drawing.Point]::new($x + 5, $boxY)
                BackColor = $boxempty
                BorderStyle = 'FixedSingle'
                Tag = @{ Checked = $subOption.Value; Ref = $subOption }
            }
            $label = [System.Windows.Forms.Label]@{
                Text = $subOption.Name
                ForeColor = 'White'
                BackColor = $boxempty
                Location = [System.Drawing.Point]::new($x + 25, $labelY)
                AutoSize = $true
                Font = [System.Drawing.Font]::new('Segoe UI', 9)
            }
            $click = {
                $tag = $box.Tag
                $tag.Checked = -not $tag.Checked
                $tag.Ref.Value = $tag.Checked
                $box.BackColor = if ($tag.Checked) { $blue } else { $boxempty }
            }.GetNewClosure()

            $box.Add_Click($click)
            $label.Add_Click($click)

            $checkboxpanel.Controls.AddRange(@($box, $label))
            $checkboxes += $box
            $y += 22
        }
    }
    $columnY[$col] = [int]($y + 15)
}

function Copy-SelectedUrls {
    $urls = foreach ($setting in $nvlists) {
        if ($setting.ContainsKey("Lists")) {
            foreach ($sub in $setting.Lists) {
                if ($sub.Value) {
                    if ($sub.ContainsKey("Urlf")) { $sub.Urlf } elseif ($sub.ContainsKey("Url")) { $sub.Url }
                }
            }
        }
    }
    if ($urls.Count -gt 0) {
        try {
            Set-Clipboard -Value ($urls -join "`r`n")
            log "[+]" "Скопировано $($urls.Count) URL в буфер обмена" "Green"
        } catch {
            log "[-]" "Не удалось скопировать URL в буфер" "Red"
        }
    } else {
        log "[-]" "Не выбрано ни одного списка" "Red"
    }
}

$buttonsb = @(
    @{ Text = "Import"; X = 5; Y = 630; Action = {
        $selected = $checkboxes.Where({ $_.Tag.Checked }) | ForEach-Object { $_.Tag.Ref }
        if ($selected.Count -eq 0) {
            log "[-]" "Выберите хотя бы один список для импорта" "Red"
            return
        }
        Apply-Blocklists -SelectedItems $selected -LogCallback { param($h, $m, $c) log $h $m $c }
        Refresh-HostsPreview
    } },
    @{ Text = "Copy Links"; X = 90; Y = 630; Action = { Copy-SelectedUrls } },
    @{ Text = "Restore"; X = 175; Y = 630; Action = {
        Restore-HostsFile -LogCallback { param($h, $m, $c) log $h $m $c }
        Refresh-HostsPreview
    } },
    @{ Text = "Open File"; X = 260; Y = 630; Action = { Start-Process "notepad.exe" -ArgumentList $nvhosts } },
    @{ Text = "Optimizer Docs"; X = 500; Y = 630; Action = { Start-Process "Gaming & System Optimizer Reference" } },

    @{ Text = "Minimal"; X = 5; Y = 5; Action = {
        $targets = @(
            $nvlists[0].Lists.Where({ $_.Name -eq "Light" })[0]
        )
        foreach ($singlebox in $checkboxes) {
            $set = $targets -contains $singlebox.Tag.Ref
            $singlebox.Tag.Checked = $set
            $singlebox.Tag.Ref.Value = $set
            $singlebox.BackColor = if ($set) { $blue } else { $boxempty }
        }
    } },
    @{ Text = "Default"; X = 90; Y = 5; Action = {
        $targets = @(
            $nvlists[0].Lists.Where({ $_.Name -eq "Pro" })[0],
            $nvlists[0].Lists.Where({ $_.Name -eq "Native Microsoft" })[0]
        )
        foreach ($singlebox in $checkboxes) {
            $set = $targets -contains $singlebox.Tag.Ref
            $singlebox.Tag.Checked = $set
            $singlebox.Tag.Ref.Value = $set
            $singlebox.BackColor = if ($set) { $blue } else { $boxempty }
        }
    } },
    @{ Text = "Maximum"; X = 175; Y = 5; Action = {
        $targets = @(
            $nvlists[0].Lists.Where({ $_.Name -eq "Pro++" })[0],
            $nvlists[0].Lists.Where({ $_.Name -eq "TIF" })[0],
            $nvlists[0].Lists.Where({ $_.Name -eq "Native Microsoft" })[0]
        )
        foreach ($singlebox in $checkboxes) {
            $set = $targets -contains $singlebox.Tag.Ref
            $singlebox.Tag.Checked = $set
            $singlebox.Tag.Ref.Value = $set
            $singlebox.BackColor = if ($set) { $blue } else { $boxempty }
        }
    } },
    @{ Text = "Clear"; X = 545; Y = 5; Action = {
        foreach ($singlebox in $checkboxes) {
            $singlebox.Tag.Checked = $false
            $singlebox.Tag.Ref.Value = $false
            $singlebox.BackColor = $boxempty
        }
    } }
)

foreach ($btnprops in $buttonsb) {
    $btn = [System.Windows.Forms.Button]@{
        Text = $btnprops.Text
        Location = [System.Drawing.Point]::new($btnprops.X, $btnprops.Y)
        BackColor = [System.Drawing.Color]::FromArgb(50, 50, 50)
        ForeColor = $white
        FlatStyle = 'Flat'
        Size = [System.Drawing.Size]::new(80, 25)
        Font = $inputf
    }
    $btn.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
    $btn.FlatAppearance.BorderSize = 1
    $btn.Add_Click($btnprops.Action)
    $nvmain.Controls.Add($btn)
}

Refresh-HostsPreview

# Не убиваем родительский PowerShell процесс при закрытии формы!
$nvmain.Add_FormClosed({
    # Корректное закрытие формы без Stop-Process
})

[System.Windows.Forms.Application]::Run($nvmain)
