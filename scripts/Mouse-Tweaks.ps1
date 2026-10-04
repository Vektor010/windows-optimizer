# ==============================================================================
# Gaming & System Optimizer - Настройка мыши (Отключение акселерации)
# ==============================================================================
Write-Host '>>> Применение киберспортивных настроек мыши...' -ForegroundColor Cyan

Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseSpeed' -Value '0'
Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold1' -Value '0'
Set-ItemProperty -Path 'HKCU:\Control Panel\Mouse' -Name 'MouseThreshold2' -Value '0'

$csharp = @'
using System.Runtime.InteropServices;
public class Mouse {
    [DllImport("user32.dll")]
    public static extern bool SystemParametersInfo(uint uiAction, uint uiParam, uint[] pvParam, uint fWinIni);
}
'@
Add-Type -TypeDefinition $csharp
[Mouse]::SystemParametersInfo(0x0004, 0, @(0,0,0), 3) | Out-Null

Write-Host '[OK] Акселерация отключена (1:1 Input)!' -ForegroundColor Green