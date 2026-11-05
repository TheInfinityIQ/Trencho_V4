[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [ValidateRange(0.01, 16.666666666666668)][double]$FrameLimitMs = (1000.0 / 60.0),
    [ValidateRange(0.01, 16.666666666666668)][double]$ActionLimitMs = (1000.0 / 60.0),
    [ValidateRange(0, 1000)][int]$FrameCap = 0,
    [ValidateRange(0, 100000000)][int]$InspectCallBudget = 30000,
    [ValidateRange(3, 300)][int]$UnresponsiveSeconds = 10,
    [ValidateRange(0, 100000)][int]$StepLimit = 0,
    [ValidateRange(0.1, 60)][double]$ObservationSeconds = 2,
    [switch]$Headless,
    [switch]$Foreground,
    [switch]$ListOnly,
    [switch]$WithoutCallStacks,
    [switch]$ExitOnPause
)
$ErrorActionPreference = 'Stop'
if ($Headless -and $Foreground) { throw 'Headless and Foreground cannot be combined.' }
$Headless = !$Foreground
if ($Headless) { $ExitOnPause = $true }
$runPlan = @{headless=[bool]$Headless; foreground=[bool]$Foreground; exit_on_pause=[bool]$ExitOnPause; visible_fps_certified=$false; scope=$(if ($Headless) {'Background handler sweep; no native mouse/popup or visible FPS certification.'} else {'Explicit foreground handler sweep; visible test window; not a physical OS-input coverage claim.'})}
if ($ListOnly) { $runPlan | ConvertTo-Json; exit 0 }
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (!(Test-Path -LiteralPath $GodotPath -PathType Leaf)) { throw "Godot not found: $GodotPath" }
$logRoot = Join-Path $projectRoot 'logs'
$runName = 'menu-performance-' + [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss') + '-' + $PID
$runDirectory = Join-Path $logRoot $runName
New-Item -ItemType Directory -Path $runDirectory -Force | Out-Null
$runPlan | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'launcher.json')
Write-Output $runPlan.scope
[System.IO.File]::WriteAllText((Join-Path $logRoot '.gdignore'), '')
$engineLog = Join-Path $runDirectory 'engine.log'
$heartbeatPath = Join-Path $runDirectory 'heartbeat.json'
$argumentList = @(
    '--path', ('"' + $projectRoot + '"'),
    '--rendering-method', 'gl_compatibility', '--disable-vsync', '--max-fps', ([string]$FrameCap),
    '--log-file', ('"' + $engineLog + '"'),
    'res://game/diagnostics/menu_performance_suite.tscn', '--',
    '--menu-perf-autostart', ('"--menu-perf-run-dir=' + $runDirectory + '"'),
    ('"--menu-perf-engine-log=' + $engineLog + '"'),
    ('--menu-perf-frame-ms=' + $FrameLimitMs.ToString([Globalization.CultureInfo]::InvariantCulture)),
    ('--menu-perf-action-ms=' + $ActionLimitMs.ToString([Globalization.CultureInfo]::InvariantCulture)),
    ('--menu-perf-call-budget=' + $InspectCallBudget), ('--menu-perf-step-limit=' + $StepLimit)
)
$argumentList += '--menu-perf-observe-seconds=' + $ObservationSeconds.ToString([Globalization.CultureInfo]::InvariantCulture)
if ($Headless) { $argumentList = @('--headless') + $argumentList }
if ($ExitOnPause) { $argumentList += '--menu-perf-exit-on-pause' }
$startArguments = @{
    FilePath = $GodotPath; ArgumentList = $argumentList; PassThru = $true
    WorkingDirectory = $projectRoot
    RedirectStandardOutput = (Join-Path $runDirectory 'stdout.log')
    RedirectStandardError = (Join-Path $runDirectory 'stderr.log')
    WindowStyle = $(if ($Headless) { 'Hidden' } else { 'Normal' })
}
$previousStackMode = [Environment]::GetEnvironmentVariable('TRENCHO_CALL_STACKS', 'Process')
try {
    [Environment]::SetEnvironmentVariable('TRENCHO_CALL_STACKS', $(if ($WithoutCallStacks) {'0'} else {'1'}), 'Process')
    $testProcess = Start-Process @startArguments
} finally {
    [Environment]::SetEnvironmentVariable('TRENCHO_CALL_STACKS', $previousStackMode, 'Process')
}
$launchTime = [DateTime]::UtcNow
$lastStatus = 'starting'
Write-Output "Performance suite process $($testProcess.Id). Logs: $runDirectory"
try {
    while (!$testProcess.HasExited) {
        Start-Sleep -Milliseconds 500
        $testProcess.Refresh()
        if ($testProcess.HasExited) { break }
        $elapsed = ([DateTime]::UtcNow - $launchTime).TotalSeconds
        $stale = $elapsed -gt 30
        if (Test-Path -LiteralPath $heartbeatPath) {
            try { $lastStatus = (Get-Content -LiteralPath $heartbeatPath -Raw | ConvertFrom-Json).status } catch { }
            $stale = ([DateTime]::UtcNow - (Get-Item -LiteralPath $heartbeatPath).LastWriteTimeUtc).TotalSeconds -gt $UnresponsiveSeconds
        }
        # A deliberate performance pause leaves the test window open for review.
        if ($lastStatus -notin @('starting', 'running')) { continue }
        if (!$stale) { continue }
        $lastEvent = ''
        $eventsPath = Join-Path $runDirectory 'actions.jsonl'
        if (Test-Path -LiteralPath $eventsPath) { $lastEvent = Get-Content -LiteralPath $eventsPath -Tail 1 }
        $failure = @{
            reason = 'watchdog_unresponsive'; status = 'owned_test_process_stopped'
            process_id = $testProcess.Id; unresponsive_seconds = $UnresponsiveSeconds
            last_event = $lastEvent
            note = 'The main thread did not return. Only the process launched by this script was stopped; other editors and apps were not touched.'
        }
        $failure | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $runDirectory 'failure.json')
        $testProcess.Kill()
        $testProcess.WaitForExit()
        Write-Output "Stopped unresponsive test process. Last action and engine output: $runDirectory"
        exit 2
    }
    $testProcess.WaitForExit()
    if ($testProcess.ExitCode -ne 0 -and !(Test-Path -LiteralPath (Join-Path $runDirectory 'failure.json'))) {
        @{reason='engine_exit'; exit_code=$testProcess.ExitCode; note='Inspect engine.log and stderr.log.'} |
            ConvertTo-Json | Set-Content -LiteralPath (Join-Path $runDirectory 'failure.json')
    }
    Write-Output "Suite exited with code $($testProcess.ExitCode). Logs: $runDirectory"
    exit $testProcess.ExitCode
} finally {
    $testProcess.Dispose()
}
