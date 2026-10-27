[CmdletBinding()]
param(
    [string]$GodotPath = 'godot',
    [ValidateSet('Domain', 'Input')][string]$Suite = 'Domain',
    [switch]$G03Driver,
    [switch]$G04Work,
    [switch]$G08Movement,
    [switch]$R02Yield,
    [switch]$R26Work,
    [switch]$R27Yield,
    [switch]$ShellChain
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$name = $Suite.ToLowerInvariant()
if (@(@($G03Driver, $G04Work, $G08Movement, $R02Yield, $R26Work, $R27Yield, $ShellChain) | Where-Object { $_ }).Count -gt 1) { throw 'Choose only one focused failure control.' }
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
if ($R26Work) {
    if ($Suite -ne 'Domain') { throw 'R26Work requires the Domain suite.' }
    $testPath = Join-Path $projectRoot 'game/production/tests/r26_domain_test.gd'
    $original = [IO.File]::ReadAllBytes($testPath)
    $text = [Text.Encoding]::UTF8.GetString($original)
    $healthy = 'assert_float(completed_work).is_equal(100.0)'
    $broken = 'assert_float(completed_work).is_equal(101.0)'
    $wrongValue = '101.0'
}
if ($R27Yield) {
    if ($Suite -ne 'Domain') { throw 'R27Yield requires the Domain suite.' }
    $testPath = Join-Path $projectRoot 'game/production/tests/r27_domain_test.gd'
    $original = [IO.File]::ReadAllBytes($testPath)
    $text = [Text.Encoding]::UTF8.GetString($original)
    $healthy = 'assert_int(completed_yield).is_equal(1)'
    $broken = 'assert_int(completed_yield).is_equal(2)'
    $wrongValue = '2'
}
if ($ShellChain) {
    if ($Suite -ne 'Domain') { throw 'ShellChain requires the Domain suite.' }
    $testPath = Join-Path $projectRoot 'game/production/tests/shell_chain_domain_test.gd'
    $original = [IO.File]::ReadAllBytes($testPath)
    $text = [Text.Encoding]::UTF8.GetString($original)
    $healthy = 'assert_int(physical_shells).is_equal(10)'
    $broken = 'assert_int(physical_shells).is_equal(11)'
    $wrongValue = '11'
}
# The exact mutation belongs to one named regression. Keep the full default
# normal suites, but do not replay all suites for each deliberate failure.
$caseName = if ($Suite -eq 'Domain') { 'test_cancel_one_order_preserves_other_admission_and_physical_cargo' } else { 'test_purchase_routes_input_and_disabled_control_cannot_commit' }
if ($G03Driver) { $caseName = 'test_driver_cannot_leave_moving_hull_and_reenters_actual_parking' }
if ($G04Work) { $caseName = 'test_real_haul_and_reporting_never_earn_work_before_atomic_start' }
if ($G08Movement) { $caseName = 'test_blocked_wheel_then_real_road_travel_preserves_fuel_and_inspection' }
if ($R02Yield) { $caseName = 'test_exact_local_r02_consumption_work_yield_and_mass_complete_once' }
if ($R26Work) { $caseName = 'test_r26_exact_inputs_100work_mass_and_four_eight_ordinary_operators' }
if ($R27Yield) { $caseName = 'test_exact_r27_local_inputs_40work_one_physical_m06_and_two_four_operators' }
if ($ShellChain) { $caseName = 'test_raw_depot_twenty_r27_completions_actual_m06_handling_then_ten_r32_shells' }
$originalHash = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($original))
if ([regex]::Matches($text, [regex]::Escape($healthy)).Count -ne 1) { throw 'Failure probe assertion is no longer unique; update this probe.' }
$reportName = if ($G03Driver) { 'failure-control-g03-driver' } else { "failure-control-$name" }
if ($G04Work) { $reportName = 'failure-control-g04-work' }
if ($G08Movement) { $reportName = 'failure-control-g08-movement' }
if ($R02Yield) { $reportName = 'failure-control-r02-yield' }
if ($R26Work) { $reportName = 'failure-control-r26-work' }
if ($R27Yield) { $reportName = 'failure-control-r27-yield' }
if ($ShellChain) { $reportName = 'failure-control-shell-chain' }
$outputRoot = Join-Path $projectRoot ".artifacts/gdunit4/$reportName"
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
try {
    [IO.File]::WriteAllText($testPath, $text.Replace($healthy, $broken), [Text.UTF8Encoding]::new($false))
    # A child PowerShell process tests the same nonzero boundary used by CI.
    & (Join-Path $PSHOME 'pwsh') -NoProfile -File (Join-Path $PSScriptRoot 'run_gdunit4.ps1') -GodotPath $GodotPath -Suite $Suite -CaseName $caseName -ReportName $reportName *> (Join-Path $outputRoot 'command.log')
    $commandExit = $LASTEXITCODE
    if ($commandExit -eq 0) { throw 'Deliberately broken assertion incorrectly passed the command.' }
    $xmlPath = Join-Path $outputRoot 'report_1/results.xml'
    if (-not (Test-Path -LiteralPath $xmlPath)) { throw 'Failure control produced no fresh JUnit evidence.' }
    [xml]$report = Get-Content -LiteralPath $xmlPath -Raw
    $cases = @($report.SelectNodes('//testcase'))
    if ($cases.Count -ne 1 -or $cases[0].name -cne $caseName -or @($report.SelectNodes('//error|//skipped')).Count -ne 0) {
        throw 'Failure control did not run its one exact named case without unrelated errors/skips.'
    }
    $failures = @($report.SelectNodes('//testcase/failure'))
    if ($failures.Count -ne 1 -or -not $failures[0].InnerText.Contains($wrongValue)) {
        throw "Failure control did not fail at its deliberately altered expected value. See $xmlPath"
    }
    @{ case=$caseName; source_sha256=$originalHash; suite=$Suite; command_exit=$commandExit; deliberately_changed=$healthy; wrong_expectation=$broken; assertion_failures=$failures.Count } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $outputRoot 'proof.json')
    Write-Host "Deliberately failing $Suite assertion correctly failed with command exit $commandExit."
} finally {
    [IO.File]::WriteAllBytes($testPath, $original)
    $restoredHash = (Get-FileHash -LiteralPath $testPath -Algorithm SHA256).Hash
    if ($restoredHash -cne $originalHash) { throw 'Failure control did not restore the original source bytes.' }
}
# Prove restoration using the same command, not a second version of the test.
& (Join-Path $PSScriptRoot 'run_gdunit4.ps1') -GodotPath $GodotPath -Suite $Suite -CaseName $caseName -ReportName "restored-$reportName"
