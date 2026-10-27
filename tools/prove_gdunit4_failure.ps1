[CmdletBinding()]
param(
    [string]$GodotPath = 'godot',
    [ValidateSet('Domain', 'Input')][string]$Suite = 'Domain',
    [switch]$G03Driver,
    [switch]$G04Work,
    [switch]$G08Movement,
    [switch]$R02Yield
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$name = $Suite.ToLowerInvariant()
if (@(@($G03Driver, $G04Work, $G08Movement, $R02Yield) | Where-Object { $_ }).Count -gt 1) { throw 'Choose only one focused failure control.' }
$testPath = Join-Path $projectRoot "game/procurement/tests/gdunit/receiving_${name}_test.gd"
$original = [IO.File]::ReadAllBytes($testPath)
$text = [Text.Encoding]::UTF8.GetString($original)
$healthy = if ($Suite -eq 'Domain') { 'is_equal(1860.0)' } else { 'is_equal(100)' }
$broken = if ($Suite -eq 'Domain') { 'is_equal(1861.0)' } else { 'is_equal(101)' }
$wrongValue = if ($Suite -eq 'Domain') { '1861.0' } else { '101' }
if ($G03Driver) {
    if ($Suite -ne 'Input') { throw 'G03Driver requires the display-backed Input suite.' }
    $testPath = Join-Path $projectRoot 'game/staffing/tests/gdunit/staffing_input_test.gd'
    $original = [IO.File]::ReadAllBytes($testPath)
    $text = [Text.Encoding]::UTF8.GetString($original)
    $healthy = 'is_equal(40.0)'
    $broken = 'is_equal(39.0)'
    $wrongValue = '39.0'
}
if ($G04Work) {
    if ($Suite -ne 'Domain' -or $G03Driver) { throw 'G04Work requires only the Domain suite.' }
    $testPath = Join-Path $projectRoot 'game/production/tests/r01_domain_test.gd'
    $original = [IO.File]::ReadAllBytes($testPath)
    $text = [Text.Encoding]::UTF8.GetString($original)
    $healthy = 'assert_float(rear.production.history[0].work).is_equal(40.0)'
    $broken = 'assert_float(rear.production.history[0].work).is_equal(41.0)'
    $wrongValue = '41.0'
}
if ($G08Movement) {
    if ($Suite -ne 'Input' -or $G03Driver -or $G04Work) { throw 'G08Movement requires only the display-backed Input suite.' }
    $testPath = Join-Path $projectRoot 'game/terrain/tests/gdunit/terrain_input_test.gd'
    $original = [IO.File]::ReadAllBytes($testPath)
    $text = [Text.Encoding]::UTF8.GetString($original)
    $healthy = 'is_equal(6.0)'
    $broken = 'is_equal(7.0)'
    $wrongValue = '7.0'
}
if ($R02Yield) {
    if ($Suite -ne 'Domain') { throw 'R02Yield requires the Domain suite.' }
    $testPath = Join-Path $projectRoot 'game/production/tests/r02_domain_test.gd'
    $original = [IO.File]::ReadAllBytes($testPath)
    $text = [Text.Encoding]::UTF8.GetString($original)
    $healthy = 'assert_int(completed_yield).is_equal(100)'
    $broken = 'assert_int(completed_yield).is_equal(101)'
    $wrongValue = '101'
}
if ([regex]::Matches($text, [regex]::Escape($healthy)).Count -ne 1) { throw 'Failure probe assertion is no longer unique; update this probe.' }
$reportName = if ($G03Driver) { 'failure-control-g03-driver' } else { "failure-control-$name" }
if ($G04Work) { $reportName = 'failure-control-g04-work' }
if ($G08Movement) { $reportName = 'failure-control-g08-movement' }
if ($R02Yield) { $reportName = 'failure-control-r02-yield' }
$outputRoot = Join-Path $projectRoot ".artifacts/gdunit4/$reportName"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
try {
    [IO.File]::WriteAllText($testPath, $text.Replace($healthy, $broken), [Text.UTF8Encoding]::new($false))
    # A child PowerShell process tests the same nonzero boundary used by CI.
    & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $PSScriptRoot 'run_gdunit4.ps1') -GodotPath $GodotPath -Suite $Suite -ReportName $reportName *> (Join-Path $outputRoot 'command.log')
    $commandExit = $LASTEXITCODE
    if ($commandExit -eq 0) { throw 'Deliberately broken assertion incorrectly passed the command.' }
    $xmlPath = Join-Path $outputRoot 'report_1/results.xml'
    if (-not (Test-Path -LiteralPath $xmlPath)) { throw 'Failure control produced no fresh JUnit evidence.' }
    [xml]$report = Get-Content -LiteralPath $xmlPath -Raw
    $failures = @($report.SelectNodes('//testcase/failure'))
    if ($failures.Count -ne 1 -or -not $failures[0].InnerText.Contains($wrongValue)) {
        throw "Failure control did not fail at its deliberately altered expected value. See $xmlPath"
    }
    @{ suite=$Suite; command_exit=$commandExit; deliberately_changed=$healthy; wrong_expectation=$broken; assertion_failures=$failures.Count } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'proof.json')
    Write-Host "Deliberately failing $Suite assertion correctly failed with command exit $commandExit."
} finally {
    [IO.File]::WriteAllBytes($testPath, $original)
}
# Prove restoration using the same command, not a second version of the test.
& (Join-Path $PSScriptRoot 'run_gdunit4.ps1') -GodotPath $GodotPath -Suite $Suite -ReportName "restored-$name"
