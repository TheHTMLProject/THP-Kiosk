Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'
$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$configDir = "$env:LOCALAPPDATA\THPKiosk"
$configPath = "$configDir\config.json"

$config = @{
    targetApp = "msedge"
    targetArgs = "--kiosk https://www.thehtmlproject.com --edge-kiosk-type=fullscreen --no-first-run"
    requirePin = $true
    exitPin = ""
    exitKey = "Q"
    doRestart = $true
    restartTimeout = 5
    enableIdle = $true
    idleTimeout = 150
    idleWarningDuration = 30
}

if (Test-Path $configPath) {
    try {
        $loaded = Get-Content $configPath -Raw | ConvertFrom-Json
        if ($null -ne $loaded.targetApp) { $config.targetApp = $loaded.targetApp }
        if ($null -ne $loaded.targetArgs) { $config.targetArgs = $loaded.targetArgs }
        if ($null -ne $loaded.exitPin) { $config.exitPin = $loaded.exitPin }
        if ($null -ne $loaded.exitKey) { $config.exitKey = $loaded.exitKey }
        if ($null -ne $loaded.requirePin) { $config.requirePin = $loaded.requirePin }
        if ($null -ne $loaded.doRestart) { $config.doRestart = $loaded.doRestart }
        if ($null -ne $loaded.restartTimeout) { $config.restartTimeout = $loaded.restartTimeout }
        if ($null -ne $loaded.enableIdle) { $config.enableIdle = $loaded.enableIdle }
        if ($null -ne $loaded.idleTimeout) { $config.idleTimeout = $loaded.idleTimeout }
    } catch {}
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "THP Kiosk Configuration"
$form.Size = New-Object System.Drawing.Size(430, 600)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false
$form.TopMost = $true
$font = New-Object System.Drawing.Font("Segoe UI", 9)
$form.Font = $font

# Group: App
$grpApp = New-Object System.Windows.Forms.GroupBox
$grpApp.Text = "Target Application"
$grpApp.Location = New-Object System.Drawing.Point(15, 15)
$grpApp.Size = New-Object System.Drawing.Size(385, 200)
$form.Controls.Add($grpApp)
$radEdge = New-Object System.Windows.Forms.RadioButton
$radEdge.Text = "Browser"
$radEdge.Location = New-Object System.Drawing.Point(15, 25)
$radEdge.Size = New-Object System.Drawing.Size(200, 24)
$radEdge.Checked = ($config.targetApp -eq "msedge")
$grpApp.Controls.Add($radEdge)
$lblUrl = New-Object System.Windows.Forms.Label
$lblUrl.Text = "Target URL:"
$lblUrl.Location = New-Object System.Drawing.Point(35, 55)
$lblUrl.Size = New-Object System.Drawing.Size(100, 20)
$grpApp.Controls.Add($lblUrl)
$txtUrl = New-Object System.Windows.Forms.TextBox
$txtUrl.Location = New-Object System.Drawing.Point(140, 52)
$txtUrl.Size = New-Object System.Drawing.Size(220, 23)
if ($config.targetApp -eq "msedge") {
    $txtUrl.Text = $config.targetArgs -replace '--kiosk\s+','' -replace '\s+--edge-kiosk.*',''
} else { $txtUrl.Text = "https://" }
$grpApp.Controls.Add($txtUrl)

$radCustom = New-Object System.Windows.Forms.RadioButton
$radCustom.Text = "Custom Application"
$radCustom.Location = New-Object System.Drawing.Point(15, 90)
$radCustom.Size = New-Object System.Drawing.Size(200, 24)
$radCustom.Checked = ($config.targetApp -ne "msedge")
$grpApp.Controls.Add($radCustom)
$lblExe = New-Object System.Windows.Forms.Label
$lblExe.Text = "Executable Path:"
$lblExe.Location = New-Object System.Drawing.Point(35, 120)
$lblExe.Size = New-Object System.Drawing.Size(100, 20)
$grpApp.Controls.Add($lblExe)
$cmbExe = New-Object System.Windows.Forms.ComboBox
$cmbExe.Location = New-Object System.Drawing.Point(140, 117)
$cmbExe.Size = New-Object System.Drawing.Size(140, 23)
$cmbExe.Items.AddRange(@("notepad.exe", "calc.exe", "mspaint.exe"))
if ($config.targetApp -ne "msedge") { $cmbExe.Text = $config.targetApp }
$grpApp.Controls.Add($cmbExe)
$btnBrowse = New-Object System.Windows.Forms.Button
$btnBrowse.Text = "Browse..."
$btnBrowse.Location = New-Object System.Drawing.Point(285, 116)
$btnBrowse.Size = New-Object System.Drawing.Size(75, 25)
$btnBrowse.add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "Executables (*.exe)|*.exe|All Files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $cmbExe.Text = $dlg.FileName }
})
$grpApp.Controls.Add($btnBrowse)
$lblArgs = New-Object System.Windows.Forms.Label
$lblArgs.Text = "Arguments (Optional):"
$lblArgs.Location = New-Object System.Drawing.Point(35, 150)
$lblArgs.Size = New-Object System.Drawing.Size(130, 20)
$grpApp.Controls.Add($lblArgs)
$txtArgs = New-Object System.Windows.Forms.TextBox
$txtArgs.Location = New-Object System.Drawing.Point(170, 147)
$txtArgs.Size = New-Object System.Drawing.Size(190, 23)
if ($config.targetApp -ne "msedge") { $txtArgs.Text = $config.targetArgs }
$grpApp.Controls.Add($txtArgs)

$radEvent = {
    $txtUrl.Enabled = $radEdge.Checked
    $cmbExe.Enabled = $radCustom.Checked
    $btnBrowse.Enabled = $radCustom.Checked
    $txtArgs.Enabled = $radCustom.Checked
}
$radEdge.add_CheckedChanged($radEvent)
$radCustom.add_CheckedChanged($radEvent)
& $radEvent

# Group: Security
$grpSec = New-Object System.Windows.Forms.GroupBox
$grpSec.Text = "Security"
$grpSec.Location = New-Object System.Drawing.Point(15, 225)
$grpSec.Size = New-Object System.Drawing.Size(385, 190)
$form.Controls.Add($grpSec)

$radPin = New-Object System.Windows.Forms.RadioButton
$radPin.Text = "Require PIN to exit Kiosk Mode"
$radPin.Location = New-Object System.Drawing.Point(15, 25)
$radPin.Size = New-Object System.Drawing.Size(200, 20)
$radPin.Checked = $config.requirePin
$grpSec.Controls.Add($radPin)

$lblPin = New-Object System.Windows.Forms.Label
$lblPin.Text = "Exit PIN:"
$lblPin.Location = New-Object System.Drawing.Point(35, 55)
$lblPin.Size = New-Object System.Drawing.Size(60, 20)
$grpSec.Controls.Add($lblPin)
$txtPin = New-Object System.Windows.Forms.TextBox
$txtPin.Location = New-Object System.Drawing.Point(100, 52)
$txtPin.Size = New-Object System.Drawing.Size(80, 23)
$txtPin.UseSystemPasswordChar = $true
$txtPin.Text = $config.exitPin
$grpSec.Controls.Add($txtPin)

$radNoPin = New-Object System.Windows.Forms.RadioButton
$radNoPin.Text = "Allow exit without PIN"
$radNoPin.Location = New-Object System.Drawing.Point(15, 85)
$radNoPin.Size = New-Object System.Drawing.Size(200, 20)
$radNoPin.Checked = (-not $config.requirePin)
$grpSec.Controls.Add($radNoPin)

$chkRestart = New-Object System.Windows.Forms.CheckBox
$chkRestart.Text = "Force Restart PC After Exit"
$chkRestart.Location = New-Object System.Drawing.Point(35, 115)
$chkRestart.Size = New-Object System.Drawing.Size(200, 20)
$chkRestart.Checked = $config.doRestart
$grpSec.Controls.Add($chkRestart)

$lblRestart = New-Object System.Windows.Forms.Label
$lblRestart.Text = "Minutes:"
$lblRestart.Location = New-Object System.Drawing.Point(235, 116)
$lblRestart.Size = New-Object System.Drawing.Size(60, 20)
$grpSec.Controls.Add($lblRestart)

$numRestart = New-Object System.Windows.Forms.NumericUpDown
$numRestart.Location = New-Object System.Drawing.Point(295, 114)
$numRestart.Size = New-Object System.Drawing.Size(50, 23)
$numRestart.Maximum = 1440
$numRestart.Value = [Math]::Max(1, $config.restartTimeout)
$grpSec.Controls.Add($numRestart)

$lblExitKey = New-Object System.Windows.Forms.Label
$lblExitKey.Text = "Exit Key Shortcut:    Ctrl + Shift +"
$lblExitKey.Location = New-Object System.Drawing.Point(15, 150)
$lblExitKey.Size = New-Object System.Drawing.Size(180, 20)
$grpSec.Controls.Add($lblExitKey)

$cmbExitKey = New-Object System.Windows.Forms.ComboBox
$cmbExitKey.Location = New-Object System.Drawing.Point(200, 147)
$cmbExitKey.Size = New-Object System.Drawing.Size(60, 23)
$cmbExitKey.Items.AddRange(@("Q", "W", "E", "X", "Z", "ESC"))
$cmbExitKey.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
if ($config.exitKey) { $cmbExitKey.Text = $config.exitKey } else { $cmbExitKey.Text = "Q" }
$grpSec.Controls.Add($cmbExitKey)

$radSecEvent = {
    $txtPin.Enabled = $radPin.Checked
    $chkRestart.Enabled = $radNoPin.Checked
    $lblRestart.Enabled = ($radNoPin.Checked -and $chkRestart.Checked)
    $numRestart.Enabled = ($radNoPin.Checked -and $chkRestart.Checked)
}
$radPin.add_CheckedChanged($radSecEvent)
$radNoPin.add_CheckedChanged($radSecEvent)
$chkRestart.add_CheckedChanged($radSecEvent)
& $radSecEvent

# Group: Inactivity
$grpIdle = New-Object System.Windows.Forms.GroupBox
$grpIdle.Text = "Inactivity"
$grpIdle.Location = New-Object System.Drawing.Point(15, 425)
$grpIdle.Size = New-Object System.Drawing.Size(385, 70)
$form.Controls.Add($grpIdle)
$chkIdle = New-Object System.Windows.Forms.CheckBox
$chkIdle.Text = "Enable Inactivity Reset"
$chkIdle.Location = New-Object System.Drawing.Point(15, 30)
$chkIdle.Size = New-Object System.Drawing.Size(160, 20)
$chkIdle.Checked = $config.enableIdle
$grpIdle.Controls.Add($chkIdle)

$lblIdle = New-Object System.Windows.Forms.Label
$lblIdle.Text = "Minutes:"
$lblIdle.Location = New-Object System.Drawing.Point(180, 31)
$lblIdle.Size = New-Object System.Drawing.Size(60, 20)
$grpIdle.Controls.Add($lblIdle)

$numIdle = New-Object System.Windows.Forms.NumericUpDown
$numIdle.Location = New-Object System.Drawing.Point(240, 28)
$numIdle.Size = New-Object System.Drawing.Size(60, 23)
$numIdle.Maximum = 1440
$numIdle.Value = [Math]::Max(1, [Math]::Round($config.idleTimeout / 60))
$grpIdle.Controls.Add($numIdle)

$chkIdleEvent = { $numIdle.Enabled = $chkIdle.Checked }
$chkIdle.add_CheckedChanged($chkIdleEvent)
& $chkIdleEvent

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Configuration"
$btnSave.Location = New-Object System.Drawing.Point(115, 515)
$btnSave.Size = New-Object System.Drawing.Size(200, 35)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(60, 171, 100)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$btnSave.FlatAppearance.BorderSize = 0
$btnSave.add_Click({
    if ($radPin.Checked -and $txtPin.Text.Length -lt 4) {
        [System.Windows.Forms.MessageBox]::Show("PIN must be at least 4 characters.", "Error", 0, 16)
        return
    }
    if ($radEdge.Checked -and [string]::IsNullOrWhiteSpace($txtUrl.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a target URL.", "Error", 0, 16)
        return
    }
    if ($radCustom.Checked -and [string]::IsNullOrWhiteSpace($cmbExe.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please select an executable path.", "Error", 0, 16)
        return
    }
    if (-not (Test-Path $configDir)) { New-Item -ItemType Directory -Path $configDir -Force | Out-Null }
    
    $newConfig = @{
        requirePin = $radPin.Checked
        exitPin = $txtPin.Text
        exitKey = $cmbExitKey.Text
        doRestart = $chkRestart.Checked
        restartTimeout = $numRestart.Value
        enableIdle = $chkIdle.Checked
        idleTimeout = ($numIdle.Value * 60)
        idleWarningDuration = 30
    }
    if ($radEdge.Checked) {
        $newConfig.targetApp = "msedge"
        $newConfig.targetArgs = "--kiosk $($txtUrl.Text) --edge-kiosk-type=fullscreen --no-first-run"
    } else {
        $newConfig.targetApp = $cmbExe.Text
        $newConfig.targetArgs = $txtArgs.Text
    }
    $newConfig | ConvertTo-Json -Depth 4 | Set-Content -Path $configPath -Encoding UTF8
    [System.Windows.Forms.MessageBox]::Show("Configuration saved successfully.", "Success", 0, 64)
    $form.Close()
})
$form.Controls.Add($btnSave)
$form.ShowDialog() | Out-Null
