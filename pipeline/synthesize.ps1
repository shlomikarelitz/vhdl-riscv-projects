param([string]$QuartusBin = "")
$ErrorActionPreference = "Stop"
if (-not $QuartusBin) {
    $quartusCommand = Get-Command quartus_map -ErrorAction SilentlyContinue
    if (-not $quartusCommand) { throw "Add Quartus bin64 to PATH or pass -QuartusBin." }
    $QuartusBin = Split-Path $quartusCommand.Source
}
Push-Location (Join-Path $PSScriptRoot "quartus")
try {
    & (Join-Path $QuartusBin "quartus_map.exe") pipeline --read_settings_files=on --write_settings_files=off
    if ($LASTEXITCODE -ne 0) { throw "Quartus Analysis & Synthesis failed" }
} finally { Pop-Location }
