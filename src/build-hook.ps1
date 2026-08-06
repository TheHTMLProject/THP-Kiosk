$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$source = Join-Path $scriptDir "THPKioskHook.cs"
$output = Join-Path $scriptDir "THPKioskHook.dll"

$csc = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $csc)) {
    $csc = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (-not (Test-Path $csc)) {
    Write-Error "Could not locate the in-box C# compiler (csc.exe) under Microsoft.NET Framework v4.0.30319."
    exit 1
}

$refBase = Join-Path $env:WINDIR "Microsoft.NET\Framework64\v4.0.30319"
if (-not (Test-Path $refBase)) { $refBase = Join-Path $env:WINDIR "Microsoft.NET\Framework\v4.0.30319" }

$refForms = Join-Path $refBase "System.Windows.Forms.dll"

$args = @(
    "/target:library",
    "/optimize+",
    "/out:$output",
    "/reference:System.dll",
    "/reference:$refForms",
    $source
)

Write-Host "Compiling THPKioskHook.dll ..."
& $csc @args
if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}

Write-Host "Built: $output"
