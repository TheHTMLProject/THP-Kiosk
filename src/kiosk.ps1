$ErrorActionPreference = "Stop"

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

$hookDll = Join-Path $scriptDir "THPKioskHook.dll"
$hookSrc = Join-Path $scriptDir "THPKioskHook.cs"
$hookLoaded = $false
try {
    Add-Type -Path $hookDll
    $hookLoaded = $true
} catch {}
if (-not $hookLoaded -and (Test-Path $hookSrc)) {
    try {
        Add-Type -TypeDefinition (Get-Content -Raw $hookSrc) -ReferencedAssemblies System.Windows.Forms
        $hookLoaded = $true
    } catch {}
}
if (-not $hookLoaded) { exit 1 }

try {
    $consolePtr = [NativeWindow]::GetConsoleWindow()
    [NativeWindow]::ShowWindow($consolePtr, 6) | Out-Null
} catch {}
$logPath = "$env:LOCALAPPDATA\THPKiosk\kiosk.log"
function Write-Log($Message) { Add-Content -Path $logPath -Value "[$((Get-Date).ToString("HH:mm:ss"))] $Message" }

try {
    Start-Process "shutdown.exe" -ArgumentList "/a" -NoNewWindow -ErrorAction SilentlyContinue
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
$exitPinHash = $config.exitPinHash
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

function Get-PinHash($pin) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]$pin)
        return -join ($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") })
    } finally { $sha.Dispose() }
}

function Test-ExitPin($entered) {
    if ($exitPinHash) { return ((Get-PinHash $entered) -eq $exitPinHash) }
    return ($entered -eq $exitPin)
}

$appName = "msedge"
if ($targetApp -ne "msedge") {
    try { $appName = [System.IO.Path]::GetFileNameWithoutExtension($targetApp) } catch {}
}

[KioskKeyboardHook]::Configure($exitVk)

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

function Restore-Desktop {
    try { [KioskKeyboardHook]::Uninstall() } catch {}

    try { Set-ItemProperty -Path $winlogonPath -Name "AutoRestartShell" -Value 1 -Type DWord } catch {}

    try { Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue } catch {}
    Start-Sleep -Seconds 1

    Start-Process "explorer.exe"
}

try {
    if (-not (Test-Path $winlogonPath)) { New-Item -Path $winlogonPath -Force | Out-Null }
    Set-ItemProperty -Path $winlogonPath -Name "AutoRestartShell" -Value 0 -Type DWord
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

$allowedNames = @(
    "explorer", "dwm", "sihost", "ctfmon", "conhost", "winlogon", "csrss", "fontdrvhost",
    "ShellExperienceHost", "StartMenuExperienceHost", "SearchHost", "SearchApp",
    "TextInputHost", "ApplicationFrameHost", "SystemSettings", "LockApp", "SndVol",
    "msedge"
)
if ($appName -ne "msedge") {
    $allowedNames += $appName
}

$lastResetTime = [IdleDetector]::GetLastInputTime()
$idleWarningShown = $false

try {
    while ($true) {
        [System.Windows.Forms.Application]::DoEvents()

        Get-Process "explorer" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Get-Process "Taskmgr" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

        $rogues = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.Id -ne $PID -and $_.Name -notin $allowedNames }
        foreach ($r in $rogues) { try { Stop-Process -Id $r.Id -Force } catch {} }
        
        if ([KioskKeyboardHook]::ExitRequested) {
            [KioskKeyboardHook]::ExitRequested = $false
            
            try {
                $procs = Get-Process $appName -ErrorAction SilentlyContinue
                foreach ($p in $procs) {
                    if ($p.MainWindowHandle -ne 0) { [NativeWindow]::ShowWindow($p.MainWindowHandle, 6) }
                }
            } catch {}

            if ($requirePin) {
                $enteredPin = Show-PinDialog
                if (Test-ExitPin $enteredPin) {
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
            
            try {
                $procs = Get-Process $appName -ErrorAction SilentlyContinue
                foreach ($p in $procs) {
                    if ($p.MainWindowHandle -ne 0) { [NativeWindow]::ShowWindow($p.MainWindowHandle, 3) }
                }
            } catch {}
        }

        $hasVisibleWindow = $false
        try {
            $procs = Get-Process $appName -ErrorAction SilentlyContinue
            foreach ($p in $procs) {
                if ($p.MainWindowHandle -ne 0) { $hasVisibleWindow = $true; break }
            }
        } catch {}

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
                        $lastResetTime = [IdleDetector]::GetLastInputTime()
                    }
                }
            }
        }
        
        Start-Sleep -Milliseconds 500
    }
} catch {
    Restore-Desktop; exit 1
}
