[CmdletBinding()]
param(
    [string]$GodotPath = 'godot',
    [ValidateSet('Domain', 'Input')][string]$Suite = 'Domain',
    [string]$ReportName = '',
    [string]$CaseName = ''
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
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'gdunit4_tests.json') -Raw | ConvertFrom-Json
$suites = @($manifest.$Suite)
$expectedCases = @($suites | ForEach-Object { $_.cases })
$ignoredCases = @()
if ($CaseName) {
    $matches = @($suites | Where-Object { $_.cases -ccontains $CaseName })
    if ($matches.Count -ne 1) { throw 'CaseName must identify exactly one case in the selected manifest suite.' }
    $suites = $matches
    $ignoredCases = @($suites[0].cases | Where-Object { $_ -cne $CaseName })
    $expectedCases = @($CaseName)
}
$engineArguments = @('--path', $projectRoot, '--log-file', (Join-Path $reportRoot 'engine.log'))
if ($Suite -eq 'Domain') { $engineArguments += '--headless' }
else {
    # Input behavior needs a display, but this pilot does not exercise an audio device.
    $engineArguments += @('--rendering-method', 'gl_compatibility', '--resolution', '1280x720', '--audio-driver', 'Dummy')
}
# GdUnit4's report parser rebases POSIX absolute paths; use its supported resource URI.
$reportUri = "res://.artifacts/gdunit4/$ReportName"
$engineArguments += @('--script', 'res://addons/gdUnit4/bin/GdUnitCmdTool.gd', '-rd', $reportUri, '-rc', '1')
foreach ($suiteEntry in $suites) { $engineArguments += @('-a', ('res://' + $suiteEntry.path)) }
# Pinned GdUnit4 6.2.2 supports exact exclusions as path:test-name (-i).
# Scan only the selected suite, exclude its other manifest cases, and verify
# the resulting JUnit names. An unexpected discovered case still fails validation.
foreach ($ignored in $ignoredCases) { $engineArguments += @('-i', ($suites[0].path + ':' + $ignored)) }
if ($Suite -eq 'Domain') { $engineArguments += '--ignoreHeadlessMode' }
& $engine @engineArguments | Out-Host
$engineExit = $LASTEXITCODE
if ($engineExit -ne 0) { throw "GdUnit4 $Suite failed (engine exit $engineExit). Reports: $reportRoot" }
if (-not (Test-Path -LiteralPath $xmlPath)) { throw "Missing GdUnit4 JUnit report: $xmlPath" }
[xml]$report = Get-Content -LiteralPath $xmlPath -Raw
$cases = @($report.SelectNodes('//testcase'))
$problems = @($report.SelectNodes('//failure|//error|//skipped'))
$actualCases = @($cases | ForEach-Object { $_.name })
$statistics = @($report.SelectNodes('//testsuite'))
foreach ($statisticsEntry in $statistics) {
    foreach ($attribute in @('flaky', 'orphans', 'skipped', 'errors', 'failures')) {
        if ($statisticsEntry.HasAttribute($attribute) -and [int]$statisticsEntry.GetAttribute($attribute) -ne 0) {
            throw "GdUnit4 $Suite reported nonzero $attribute. See $xmlPath"
        }
    }
}
$caseMismatch = @(Compare-Object ($expectedCases | Sort-Object) ($actualCases | Sort-Object))
if ($caseMismatch.Count -ne 0 -or $problems.Count -ne 0) {
    throw "GdUnit4 $Suite did not execute exactly its named, passing, unskipped cases. See $xmlPath"
}
if (Select-String -LiteralPath (Join-Path $reportRoot 'engine.log') -Pattern '^\s*(SCRIPT ERROR:|ERROR:)') {
    throw "GdUnit4 $Suite reported engine/script errors. See $reportRoot/engine.log"
}
Write-Host "GdUnit4 ${Suite}: $($cases.Count) named tests passed; JUnit/HTML reports at $reportRoot/report_1"
