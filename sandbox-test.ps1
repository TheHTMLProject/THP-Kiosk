$ErrorActionPreference = "Stop"

$local = "C:\kiosk"
New-Item -ItemType Directory -Path $local -Force | Out-Null
Copy-Item "C:\THP\src\*" $local -Recurse -Force

$cfgDir = "$env:LOCALAPPDATA\THPKiosk"
New-Item -ItemType Directory -Path $cfgDir -Force | Out-Null

$config = @{
    targetApp = "msedge"
    targetArgs = "--kiosk https://example.com --edge-kiosk-type=fullscreen --no-first-run"
    requirePin = $true
    exitPinHash = "03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4"
    exitKey = "Q"
    doRestart = $false
    restartTimeout = 5
    enableIdle = $false
    idleTimeout = 150
    idleWarningDuration = 30
}
$config | ConvertTo-Json -Depth 4 | Set-Content -Path "$cfgDir\config.json" -Encoding UTF8

Start-Process powershell.exe -ArgumentList '-ExecutionPolicy Bypass -File C:\kiosk\kiosk.ps1'
