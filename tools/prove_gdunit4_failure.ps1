[CmdletBinding()]
param(
    [string]$GodotPath = 'godot',
    [ValidateSet('Domain', 'Input')][string]$Suite = 'Domain'
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$name = $Suite.ToLowerInvariant()
$testPath = Join-Path $projectRoot "game/procurement/tests/gdunit/receiving_${name}_test.gd"
$original = [IO.File]::ReadAllBytes($testPath)
$text = [Text.Encoding]::UTF8.GetString($original)
$healthy = if ($Suite -eq 'Domain') { 'is_equal(1860.0)' } else { 'is_equal(100)' }
$broken = if ($Suite -eq 'Domain') { 'is_equal(1861.0)' } else { 'is_equal(101)' }
if ([regex]::Matches($text, [regex]::Escape($healthy)).Count -ne 1) { throw 'Failure probe assertion is no longer unique; update this probe.' }
$reportName = "failure-control-$name"
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
    if ($failures.Count -ne 1 -or -not $failures[0].InnerText.Contains($broken.Substring(9).TrimEnd(')'))) {
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
