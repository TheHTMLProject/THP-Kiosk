Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

$ErrorActionPreference = "Stop"
$logPath = "$env:LOCALAPPDATA\THPKiosk\kiosk.log"
function Write-Log($Message) { Add-Content -Path $logPath -Value "[$((Get-Date).ToString("HH:mm:ss"))] $Message" }

try {
    Start-Process "shutdown.exe" -ArgumentList "/a" -WindowStyle Hidden -ErrorAction SilentlyContinue
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
} catch { exit 1 }

$configPath = "$env:LOCALAPPDATA\THPKiosk\config.json"
if (-not (Test-Path $configPath)) { exit 1 }

$config = Get-Content -Path $configPath -Raw | ConvertFrom-Json
$targetApp = $config.targetApp
$targetArgs = $config.targetArgs
$requirePin = $config.requirePin
$exitPin = $config.exitPin
$exitKey = $config.exitKey
if (-not $exitKey) { $exitKey = "Q" }
$exitVk = 0x51
switch ($exitKey.ToUpper()) {
    "W" { $exitVk = 0x57 }
    "E" { $exitVk = 0x45 }
    "X" { $exitVk = 0x58 }
    "Z" { $exitVk = 0x5A }
    "ESC" { $exitVk = 0x1B }
    Default { $exitVk = 0x51 }
}
$doRestart = $config.doRestart
$restartTimeout = $config.restartTimeout
$enableIdle = $config.enableIdle
$idleTimeout = $config.idleTimeout
$idleWarningDuration = $config.idleWarningDuration

$appName = "msedge"
if ($targetApp -ne "msedge") {
    try { $appName = [System.IO.Path]::GetFileNameWithoutExtension($targetApp) } catch {}
}

try {
    Add-Type -TypeDefinition @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
public static class KioskKeyboardHook {
    private const int WH_KEYBOARD_LL = 13;
    private const int WM_KEYDOWN = 0x0100;
    private const int WM_SYSKEYDOWN = 0x0104;
    private static IntPtr hookId = IntPtr.Zero;
    private static Thread pumpThread;
    public static bool ExitRequested = false;
    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);
    
    // Static delegate to prevent garbage collection!
    private static LowLevelKeyboardProc _proc = HookCallback;
    
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelKeyboardProc lpfn, IntPtr hMod, uint dwThreadId);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);
    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);
    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
    [DllImport("user32.dll")]
    private static extern short GetAsyncKeyState(int vKey);
    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT { public int vkCode; public int scanCode; public int flags; public int time; public IntPtr dwExtraInfo; }
    
    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam) {
        if (nCode >= 0 && (wParam == (IntPtr)WM_KEYDOWN || wParam == (IntPtr)WM_SYSKEYDOWN)) {
            KBDLLHOOKSTRUCT hookStruct = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(KBDLLHOOKSTRUCT));
            int vk = hookStruct.vkCode;
            bool ctrlDown = (GetAsyncKeyState(0x11) & 0x8000) != 0;
            bool shiftDown = (GetAsyncKeyState(0x10) & 0x8000) != 0;
            bool altDown = (GetAsyncKeyState(0x12) & 0x8000) != 0;
            if (ctrlDown && shiftDown && vk == $($exitVk)) { ExitRequested = true; return CallNextHookEx(hookId, nCode, wParam, lParam); }
            if (altDown && vk == 0x73) return (IntPtr)1; // Alt+F4
            if (ctrlDown && shiftDown && vk == 0x1B) return (IntPtr)1; // Ctrl+Shift+Esc
            if (vk == 0x5B || vk == 0x5C) return (IntPtr)1; // Win
            if (altDown && vk == 0x09) return (IntPtr)1; // Alt+Tab
        }
        return CallNextHookEx(hookId, nCode, wParam, lParam);
    }
    public static void Install() {
        pumpThread = new Thread(() => {
            try {
                using (Process curProcess = Process.GetCurrentProcess())
                using (ProcessModule curModule = curProcess.MainModule) {
                    hookId = SetWindowsHookEx(WH_KEYBOARD_LL, _proc, GetModuleHandle(curModule.ModuleName), 0);
                }
                Application.Run();
            } catch {}
        });
        pumpThread.IsBackground = true;
        pumpThread.SetApartmentState(ApartmentState.STA);
        pumpThread.Start();
        Thread.Sleep(200);
    }
    public static void Uninstall() { if (hookId != IntPtr.Zero) { UnhookWindowsHookEx(hookId); hookId = IntPtr.Zero; } Application.ExitThread(); }
}
"@ -ReferencedAssemblies System.Windows.Forms
} catch {}

try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class IdleDetector {
    [StructLayout(LayoutKind.Sequential)]
    private struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
    [DllImport("user32.dll")]
    private static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
    
    public static uint GetLastInputTime() {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(info);
        if (GetLastInputInfo(ref info)) { return info.dwTime; }
        return 0;
    }
    
    public static int GetIdleSeconds() {
        LASTINPUTINFO info = new LASTINPUTINFO();
        info.cbSize = (uint)Marshal.SizeOf(info);
        if (GetLastInputInfo(ref info)) {
            uint idleMs = (uint)Environment.TickCount - info.dwTime;
            return (int)(idleMs / 1000);
        }
        return 0;
    }
}
"@
} catch {}

function Show-PinDialog {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "THP Kiosk - Exit"
    $form.Size = New-Object System.Drawing.Size(350, 150)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Enter exit PIN to restore desktop:"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.AutoSize = $true
    $form.Controls.Add($lbl)
    $txt = New-Object System.Windows.Forms.TextBox
    $txt.Location = New-Object System.Drawing.Point(20, 45)
    $txt.Width = 290
    $txt.UseSystemPasswordChar = $true
    $form.Controls.Add($txt)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Unlock"
    $btn.Location = New-Object System.Drawing.Point(120, 75)
    $btn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $btn
    $form.Controls.Add($btn)
    $btn2 = New-Object System.Windows.Forms.Button
    $btn2.Text = "Cancel"
    $btn2.Location = New-Object System.Drawing.Point(210, 75)
    $btn2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $btn2
    $form.Controls.Add($btn2)
    
    $secTimer = New-Object System.Windows.Forms.Timer
    $secTimer.Interval = 200
    $secTimer.add_Tick({
        Get-Process "explorer", "Taskmgr" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    })
    $secTimer.Start()
    
    $res = $form.ShowDialog()
    $secTimer.Stop(); $secTimer.Dispose()
    
    if ($res -eq [System.Windows.Forms.DialogResult]::OK) { return $txt.Text }
    return $null
}

function Show-NoPinWarning {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "THP Kiosk - Warning"
    $form.Size = New-Object System.Drawing.Size(400, 160)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "You will be returned to the desktop.`nUnauthorized use is strictly prohibited.`n`nContinue?"
    $lbl.Location = New-Object System.Drawing.Point(20, 20)
    $lbl.Size = New-Object System.Drawing.Size(350, 50)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lbl)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Yes, Exit Kiosk"
    $btn.Location = New-Object System.Drawing.Point(130, 80)
    $btn.Size = New-Object System.Drawing.Size(120, 30)
    $btn.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $form.AcceptButton = $btn
    $form.Controls.Add($btn)
    $btn2 = New-Object System.Windows.Forms.Button
    $btn2.Text = "Cancel"
    $btn2.Location = New-Object System.Drawing.Point(260, 80)
    $btn2.Size = New-Object System.Drawing.Size(120, 30)
    $btn2.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.CancelButton = $btn2
    $form.Controls.Add($btn2)
    
    $secTimer = New-Object System.Windows.Forms.Timer
    $secTimer.Interval = 200
    $secTimer.add_Tick({
        Get-Process "explorer", "Taskmgr" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    })
    $secTimer.Start()
    
    $res = $form.ShowDialog()
    $secTimer.Stop(); $secTimer.Dispose()
    
    return ($res -eq [System.Windows.Forms.DialogResult]::OK)
}

function Show-IdleWarning {
    param($Duration)
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Inactivity Warning"
    $form.Size = New-Object System.Drawing.Size(400, 150)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = "FixedDialog"
    $form.ControlBox = $false
    $form.TopMost = $true
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = "Your session will reset due to inactivity in $Duration seconds."
    $lbl.Location = New-Object System.Drawing.Point(30, 25)
    $lbl.Size = New-Object System.Drawing.Size(350, 30)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $form.Controls.Add($lbl)
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = "Stay Logged In"
    $btn.Location = New-Object System.Drawing.Point(130, 70)
    $btn.Size = New-Object System.Drawing.Size(120, 30)
    $btn.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    $form.Controls.Add($btn)
    
    $timer = New-Object System.Windows.Forms.Timer
    $timer.Interval = 1000
    $form.Tag = $Duration
    
    $origInput = [IdleDetector]::GetLastInputTime()
    
    $timer.add_Tick({
        # Auto-cancel if user moves mouse or types
        $curInput = [IdleDetector]::GetLastInputTime()
        if ($curInput -ne $origInput) {
            $timer.Stop()
            $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
            $form.Close()
            return
        }
        
        $val = [int]$form.Tag - 1
        $form.Tag = $val
        $lbl.Text = "Your session will reset due to inactivity in $val seconds."
        if ($val -le 0) {
            $timer.Stop()
            $form.DialogResult = [System.Windows.Forms.DialogResult]::Abort
            $form.Close()
        }
    })
    $timer.Start()
    $res = $form.ShowDialog()
    $timer.Stop(); $timer.Dispose()
    return $res
}

$winlogonPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
$policiesPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"

function Restore-Desktop {
    try { [KioskKeyboardHook]::Uninstall() } catch {}
    
    # Restore AutoRestartShell to 1 so Windows will auto-restart the shell
    try { Set-ItemProperty -Path $winlogonPath -Name "AutoRestartShell" -Value 1 -Type DWord } catch {}
    try { Remove-ItemProperty -Path $policiesPath -Name "DisableTaskMgr" -ErrorAction SilentlyContinue } catch {}
    
    # Kill any leftover explorer then wait for the registry change to propagate
    try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Seconds 1
    
    # Explicitly launch explorer as a safety net in case AutoRestartShell hasn't kicked in yet
    Start-Process "explorer.exe"
}

try {
    if (-not (Test-Path $winlogonPath)) { New-Item -Path $winlogonPath -Force | Out-Null }
    Set-ItemProperty -Path $winlogonPath -Name "AutoRestartShell" -Value 0 -Type DWord
    
    if (-not (Test-Path $policiesPath)) { New-Item -Path $policiesPath -Force | Out-Null }
    Set-ItemProperty -Path $policiesPath -Name "DisableTaskMgr" -Value 1 -Type DWord
} catch {}

try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {}
try { [KioskKeyboardHook]::Install() } catch {}

function Start-TargetApp {
    try {
        if ($targetArgs) { return Start-Process -FilePath $targetApp -ArgumentList $targetArgs -WindowStyle Maximized -PassThru -ErrorAction Stop }
        else { return Start-Process -FilePath $targetApp -WindowStyle Maximized -PassThru -ErrorAction Stop }
    } catch { return $null }
}

$launchTime = Get-Date
$process = Start-TargetApp
if (-not $process) {
    [System.Windows.Forms.MessageBox]::Show("Failed to launch target app.", "Error", 0, 16)
    Restore-Desktop; exit 1
}

$allowedNames = @("msedge", "explorer", "Taskmgr", "powershell", "wscript", "cmd", "conhost", "cmdlet", "winlogon", "csrss")
if ($appName -ne "msedge") {
    $allowedNames += $appName
}

$lastResetTime = [IdleDetector]::GetLastInputTime()
$idleWarningShown = $false

try {
    while ($true) {
        [System.Windows.Forms.Application]::DoEvents()
        
        # Redundancy kill
        Get-Process "explorer" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process "Taskmgr" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        
        # Kill stray windows (unauthorized apps like spawned command prompts or file viewers)
        $rogues = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.Name -notin $allowedNames }
        foreach ($r in $rogues) { try { Stop-Process -Id $r.Id -Force } catch {} }
        
        if ([KioskKeyboardHook]::ExitRequested) {
            [KioskKeyboardHook]::ExitRequested = $false
            
            # Minimize custom app windows before showing popup
            try {
                $procs = Get-Process $appName -ErrorAction SilentlyContinue
                foreach ($p in $procs) {
                    if ($p.MainWindowHandle -ne 0) { [Console.Window]::ShowWindow($p.MainWindowHandle, 6) }
                }
            } catch {}
            
            if ($requirePin) {
                $enteredPin = Show-PinDialog
                if ($enteredPin -eq $exitPin) {
                    try { Stop-Process -Name $appName -Force -ErrorAction SilentlyContinue } catch {}
                    Restore-Desktop; exit 0
                } elseif ($null -ne $enteredPin) {
                    [System.Windows.Forms.MessageBox]::Show("Incorrect PIN.", "THP Kiosk", 0, 48)
                }
            } else {
                if (Show-NoPinWarning) {
                    try { Stop-Process -Name $appName -Force -ErrorAction SilentlyContinue } catch {}
                    if ($doRestart -and $restartTimeout -gt 0) {
                        Start-Process shutdown.exe -ArgumentList "/r /t $($restartTimeout * 60) /c `"Kiosk Session Ended. System will restart in $restartTimeout minutes.`"" -NoNewWindow
                    }
                    Restore-Desktop; exit 0
                }
            }
            
            # If the user cancels the dialog or enters the wrong PIN, restore and maximize the app!
            try {
                $procs = Get-Process $appName -ErrorAction SilentlyContinue
                foreach ($p in $procs) {
                    if ($p.MainWindowHandle -ne 0) { [Console.Window]::ShowWindow($p.MainWindowHandle, 3) }
                }
            } catch {}
        }
        
        # Advanced window tracking to prevent multi-instance loops when custom apps use background wrappers
        $hasVisibleWindow = $false
        try {
            $procs = Get-Process $appName -ErrorAction SilentlyContinue
            foreach ($p in $procs) {
                if ($p.MainWindowHandle -ne 0) { $hasVisibleWindow = $true; break }
            }
        } catch {}
        
        # Give the app 15 seconds to create a window, if it doesn't or if it was closed, restart it cleanly
        if (-not $hasVisibleWindow -and (Get-Date) -gt $launchTime.AddSeconds(15)) {
            try { Stop-Process -Name $appName -Force -ErrorAction SilentlyContinue } catch {}
            Start-Sleep -Seconds 2
            $process = Start-TargetApp
            $launchTime = Get-Date
            $lastResetTime = [IdleDetector]::GetLastInputTime()
        }
        
        if ($enableIdle -and $idleTimeout -gt 0) {
            $curTime = 0
            try { $curTime = [IdleDetector]::GetLastInputTime() } catch {}
            
            # Only start tracking idle if there HAS been input since the last reset!
            if ($curTime -ne $lastResetTime) {
                $idleSeconds = [IdleDetector]::GetIdleSeconds()
                
                if ($idleSeconds -ge $idleTimeout -and -not $idleWarningShown) {
                    $idleWarningShown = $true
                    if ((Show-IdleWarning -Duration $idleWarningDuration) -eq [System.Windows.Forms.DialogResult]::Abort) {
                        try { Stop-Process -Name $appName -Force -ErrorAction SilentlyContinue } catch {}
                        Start-Sleep -Seconds 2
                        $process = Start-TargetApp
                        $launchTime = Get-Date
                        $lastResetTime = [IdleDetector]::GetLastInputTime()
                        $idleWarningShown = $false
                    } else {
                        $idleWarningShown = $false
                        $lastResetTime = [IdleDetector]::GetLastInputTime() # Reset tracking baseline if they stayed logged in
                    }
                }
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
} catch {
    Restore-Desktop; exit 1
}
