param(
    [string]$QuestaBin = "",
    [switch]$CompileOnly
)
$ErrorActionPreference = "Stop"
$projectRoot = $PSScriptRoot
if (-not $QuestaBin) {
    $compilerCommand = Get-Command vcom -ErrorAction SilentlyContinue
    if (-not $compilerCommand) { throw "Add Questa/ModelSim's bin directory to PATH or pass -QuestaBin." }
    $QuestaBin = Split-Path $compilerCommand.Source
}
foreach ($tool in @('vcom.exe', 'vmap.exe', 'vlib.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $QuestaBin $tool))) { throw "$tool not found in $QuestaBin" }
}
$build = Join-Path $projectRoot "build/sim"
New-Item -ItemType Directory -Path $build -Force | Out-Null
Push-Location $build
try {
    & (Join-Path $QuestaBin 'vmap.exe') -c
    if ($LASTEXITCODE -ne 0) { throw 'Could not create local modelsim.ini' }
    & (Join-Path $QuestaBin 'vlib.exe') work
    if ($LASTEXITCODE -ne 0) { throw 'Could not create work library' }
    & (Join-Path $QuestaBin 'vmap.exe') work work
    if ($LASTEXITCODE -ne 0) { throw 'Could not map work library' }
    $sources = Get-Content (Join-Path $projectRoot 'rtl/files.txt')
    foreach ($source in $sources) {
        $sourcePath = Join-Path $projectRoot "rtl/$source"
        if ($source -eq 'cond_compilation_package.vhd') {
            # Compile a generated simulation copy; the committed FPGA package stays at 0.
            $text = Get-Content -LiteralPath $sourcePath -Raw
            $pattern = '(?i)(constant\s+G_MODELSIM\s*:\s*integer\s*:=\s*)0'
            if ([regex]::Matches($text, $pattern).Count -ne 1) { throw 'Expected exactly one simulation mode constant' }
            $text = [regex]::Replace($text, $pattern, '${1}1')
            $sourcePath = Join-Path $build 'cond_compilation_package_sim.vhd'
            [System.IO.File]::WriteAllText($sourcePath, $text, [System.Text.UTF8Encoding]::new($false))
        }
        & (Join-Path $QuestaBin 'vcom.exe') -2008 -work work $sourcePath
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $source" }
    }
    foreach ($testbench in (Get-ChildItem (Join-Path $projectRoot 'tb') -Filter '*.vhd' -File)) {
        & (Join-Path $QuestaBin 'vcom.exe') -2008 -work work $testbench.FullName
        if ($LASTEXITCODE -ne 0) { throw "Compilation failed: $($testbench.Name)" }
    }
    Write-Host 'COMPILE PASS'
    if (-not $CompileOnly) {
        $doPath = (Join-Path $projectRoot 'sim/run.tcl').Replace('\','/')
        $logPath = Join-Path $build 'runner.log'
        & (Join-Path $QuestaBin 'vsim.exe') -c -l transcript.log -do "do {$doPath}" 2>&1 | Tee-Object -FilePath $logPath
        if ($LASTEXITCODE -ne 0) { throw "Simulation failed; see $logPath" }
        $log = Get-Content $logPath -Raw
        if ($log -match '\*\* (Error|Fatal|Failure):') { throw "Simulator reported an error; see $logPath" }
        foreach ($marker in @('PIPELINE SMOKE PASS')) {
            if (-not $log.Contains($marker)) { throw "Missing simulation result '$marker'; see $logPath" }
        }
    }
} finally { Pop-Location }
