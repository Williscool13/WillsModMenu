param([string]$keys, [int]$x = -1, [int]$y = -1)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W { [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
[DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
[DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, int f, int e); }
"@
$p = Get-Process -Name "PAYDAY3-Win64-Shipping" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($p) { [W]::SetForegroundWindow($p.MainWindowHandle) | Out-Null; Start-Sleep -Milliseconds 300 }
if ($x -ge 0) { [W]::SetCursorPos($x, $y) | Out-Null }
if ($keys -eq "ctrl+r") {
  [W]::keybd_event(0x11,0,0,0); Start-Sleep -Milliseconds 50; [W]::keybd_event(0x52,0,0,0); Start-Sleep -Milliseconds 80
  [W]::keybd_event(0x52,0,2,0); Start-Sleep -Milliseconds 50; [W]::keybd_event(0x11,0,2,0)
}
"done $keys"
