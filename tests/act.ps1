param([string]$what, [int]$x = -1, [int]$y = -1)
Add-Type @"
using System; using System.Runtime.InteropServices;
public class A { [DllImport("user32.dll")] public static extern bool SetCursorPos(int x,int y);
[DllImport("user32.dll")] public static extern void mouse_event(int f,int x,int y,int d,int e);
[DllImport("user32.dll")] public static extern void keybd_event(byte k, byte s, int f, int e); }
"@
if ($x -ge 0) { [A]::SetCursorPos($x, $y) | Out-Null; Start-Sleep -Milliseconds 150 }
if ($what -eq "click") { [A]::mouse_event(2,0,0,0,0); Start-Sleep -Milliseconds 70; [A]::mouse_event(4,0,0,0,0) }
if ($what -eq "esc") { [A]::keybd_event(0x1B,0x01,0,0); Start-Sleep -Milliseconds 80; [A]::keybd_event(0x1B,0x01,2,0) }
"$what done"
