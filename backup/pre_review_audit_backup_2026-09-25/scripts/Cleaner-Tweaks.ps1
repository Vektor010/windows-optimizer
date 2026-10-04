# Noverse Research - Maintenance & Cache Cleaners
# Based on noverse.dev/docs/win-config/cleanup/ by Nohuto
$ErrorActionPreference = "SilentlyContinue"

Write-Host ">>> Starting Comprehensive System Cache & Shader Cleaner..." -ForegroundColor Cyan

# 1. Flush DNS Client Cache
Write-Host "[1/5] Flushing DNS Client Cache..." -ForegroundColor Yellow
Clear-DnsClientCache
Write-Host " [+] DNS Cache flushed." -ForegroundColor Green

# 2. Clear DirectX & NVIDIA Shader Caches
Write-Host "[2/5] Cleaning DirectX & NVIDIA Shader Caches..." -ForegroundColor Yellow
$shaderPaths = @(
    "$env:LOCALAPPDATA\D3DSCache",
    "$env:LOCALAPPDATA\NVIDIA\DXCache",
    "$env:LOCALAPPDATA\NVIDIA\GLCache",
    "$env:LOCALAPPDATA\NVIDIA Corporation\NV_Cache"
)
foreach ($sp in $shaderPaths) {
    if (Test-Path $sp) {
        Remove-Item "$sp\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host " [+] Cleaned: $sp" -ForegroundColor Green
    }
}

# 3. Clear Windows & User Temp Files
Write-Host "[3/5] Cleaning Temporary Files..." -ForegroundColor Yellow
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host " [+] Temp files cleaned." -ForegroundColor Green

# 4. Clear Delivery Optimization Files
Write-Host "[4/5] Cleaning Delivery Optimization Files..." -ForegroundColor Yellow
$doPath = "C:\Windows\SoftwareDistribution\DeliveryOptimization"
if (Test-Path $doPath) {
    Remove-Item "$doPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host " [+] Delivery Optimization files cleaned." -ForegroundColor Green
}

# 5. Clear Event Logs
Write-Host "[5/5] Clearing Windows Event Logs..." -ForegroundColor Yellow
wevtutil el | ForEach-Object { wevtutil cl "$_" 2>$null }
Write-Host " [+] Event logs cleared." -ForegroundColor Green

Write-Host "`n[✓] System Maintenance & Cleanup completed successfully!" -ForegroundColor Green
