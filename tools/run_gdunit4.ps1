[CmdletBinding()]
param(
    [string]$GodotPath = 'godot',
    [ValidateSet('Domain', 'Input')][string]$Suite = 'Domain',
    [string]$ReportName = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = (Get-Command $GodotPath -CommandType Application -ErrorAction Stop).Source
if ($Suite -eq 'Input' -and $IsLinux -and -not $env:DISPLAY) {
    throw 'Scene input requires a display. Use: xvfb-run -a pwsh -File ./tools/check.ps1 -SceneInput -GodotPath <godot>'
}
if (-not (Test-Path -LiteralPath (Join-Path $projectRoot 'addons/gdUnit4/bin/GdUnitCmdTool.gd'))) {
    throw 'Run tools/check.ps1 first to acquire, verify and import the pinned framework.'
}
if (-not $ReportName) { $ReportName = $Suite.ToLowerInvariant() }
if ($ReportName -notmatch '^[a-z0-9-]+$') { throw 'ReportName must use lowercase letters, digits and hyphens.' }
$reportRoot = Join-Path $projectRoot ".artifacts/gdunit4/$ReportName"
New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
$xmlPath = Join-Path $reportRoot 'report_1/results.xml'
if (Test-Path -LiteralPath $xmlPath) { Remove-Item -LiteralPath $xmlPath }
$test = if ($Suite -eq 'Input') { 'receiving_input_test.gd' } else { 'receiving_domain_test.gd' }
$engineArguments = @('--path', $projectRoot, '--log-file', (Join-Path $reportRoot 'engine.log'))
if ($Suite -eq 'Domain') { $engineArguments += '--headless' }
else { $engineArguments += @('--rendering-method', 'gl_compatibility', '--resolution', '1280x720') }
$engineArguments += @('--script', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-a', "res://game/procurement/tests/gdunit/$test", '-rd', $reportRoot, '-rc', '1')
if ($Suite -eq 'Domain') { $engineArguments += '--ignoreHeadlessMode' }
& $engine @engineArguments | Out-Host
$engineExit = $LASTEXITCODE
if ($engineExit -ne 0) { throw "GdUnit4 $Suite failed (engine exit $engineExit). Reports: $reportRoot" }
if (-not (Test-Path -LiteralPath $xmlPath)) { throw "Missing GdUnit4 JUnit report: $xmlPath" }
[xml]$report = Get-Content -LiteralPath $xmlPath -Raw
$cases = @($report.SelectNodes('//testcase'))
$problems = @($report.SelectNodes('//failure|//error|//skipped'))
if ($cases.Count -ne 1 -or $problems.Count -ne 0) { throw "GdUnit4 $Suite did not execute its one passing, unskipped pilot. See $xmlPath" }
if (Select-String -LiteralPath (Join-Path $reportRoot 'engine.log') -Pattern '^\s*(SCRIPT ERROR:|ERROR:)') {
    throw "GdUnit4 $Suite reported engine/script errors. See $reportRoot/engine.log"
}
Write-Host "GdUnit4 ${Suite}: one test passed; JUnit/HTML reports at $reportRoot/report_1"
