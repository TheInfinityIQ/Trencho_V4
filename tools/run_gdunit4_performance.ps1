[CmdletBinding()]
param(
    [string]$GodotPath = 'C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe',
    [ValidateRange(0.01, 16.666666666666668)][double]$FrameLimitMs = (1000.0 / 60.0),
    [ValidateRange(0.01, 16.666666666666668)][double]$ActionLimitMs = (1000.0 / 60.0),
    [ValidateRange(0, 1000)][int]$FrameCap = 0,
    [ValidateRange(0, 100000000)][int]$InspectCallBudget = 30000,
    [ValidateRange(0.05, 60)][double]$ObservationSeconds = 2,
    [ValidateRange(3, 300)][int]$UnresponsiveSeconds = 15,
    [switch]$GuardsOnly,
    [switch]$TrainingOnly,
    [switch]$TrainingUiOnly,
    [switch]$PlacementOnly,
    [switch]$PlacementBenchmarkOnly,
    [switch]$PlacementReadsOnly,
    [switch]$CohesionOnly,
    [switch]$LiveFrameOnly,
    [switch]$LogisticsOnly,
    [switch]$OrdinaryMenusOnly,
    [switch]$LongSessionOnly,
    [ValidateRange(2, 60)][double]$TrainingObservationSeconds = 2,
    [switch]$UiOnly,
    [switch]$BuildingsOnly,
    [switch]$ButtonsOnly,
    [switch]$ContinueAfterIssues,
    [string]$ButtonProfile = '',
    [string]$ButtonText = '',
    [switch]$WithoutCallStacks,
    [switch]$Headless,
    [switch]$Foreground,
    [switch]$ListOnly
)
$ErrorActionPreference = 'Stop'
if ($PSVersionTable.PSVersion.Major -lt 7) {
    $modernShell = Join-Path $env:USERPROFILE '.cache/codex-runtimes/codex-primary-runtime/dependencies/native/powershell/pwsh.exe'
    if (!(Test-Path -LiteralPath $modernShell)) { $modernShell = (Get-Command pwsh.exe -ErrorAction Stop).Source }
    & $modernShell -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @PSBoundParameters
    exit $LASTEXITCODE
}
$projectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (@($GuardsOnly,$TrainingOnly,$TrainingUiOnly,$PlacementOnly,$PlacementBenchmarkOnly,$PlacementReadsOnly,$CohesionOnly,$LiveFrameOnly,$LogisticsOnly,$OrdinaryMenusOnly,$LongSessionOnly,$UiOnly,$BuildingsOnly,$ButtonsOnly).Where({$_}).Count -gt 1) { throw 'Choose one test selection.' }
if ($Headless -and $Foreground) { throw 'Headless and Foreground cannot be combined.' }
# Native scene runners can focus windows and warp the OS cursor, even at setup.
# Routine checks therefore use the headless display driver, never a minimized native runner.
$Headless = !$Foreground
if ($Headless -and ($UiOnly -or $ButtonsOnly -or $OrdinaryMenusOnly -or $TrainingUiOnly -or $PlacementOnly -or $PlacementBenchmarkOnly)) {
    throw 'This native-input selection needs -Foreground and may use your mouse/focus. Run without a selection for routine headless checks, or choose -PlacementReadsOnly for background placement guards.'
}
$stamp = [DateTime]::UtcNow.ToString('yyyy-MM-ddTHH-mm-ss') + '-' + $PID
$logDirectory = Join-Path $projectRoot ('logs/gdunit4-performance-' + $stamp)
$testProject = Join-Path $projectRoot ('.tools/gdunit4-performance/' + $stamp)
$testPath = 'game/diagnostics/tests/gdunit/menu_performance_test.gd'
if ($UiOnly -or $BuildingsOnly -or $ButtonsOnly) { $testPath = 'game/diagnostics/tests/gdunit/a_full_ui_test.gd' }
$selection = if ($GuardsOnly -or $UiOnly -or $BuildingsOnly -or $ButtonsOnly) { $testPath } else { 'game/diagnostics/tests/gdunit' }
$trainingRead = 'game/diagnostics/tests/gdunit/training_read_test.gd'
$trainingDomain = 'game/training/tests/training_domain_test.gd'
$trainingInput = 'game/training/tests/training_input_test.gd'
$placement = 'game/diagnostics/tests/gdunit/building_pointer_test.gd'
$placementReads = 'game/diagnostics/tests/gdunit/placement_hint_test.gd'
$budgetGuards = 'game/diagnostics/tests/gdunit/performance_budget_test.gd'
$cohesion = 'game/diagnostics/tests/gdunit/cohesion_read_test.gd'
$liveFrames = 'game/diagnostics/tests/gdunit/live_frame_test.gd'
$logisticsTests = @('game/diagnostics/tests/gdunit/rear_logistics_test.gd','game/diagnostics/tests/gdunit/forward_planning_test.gd')
$reportDelivery = 'game/diagnostics/tests/gdunit/function_report_delivery_test.gd'
$ordinaryMenus = 'game/diagnostics/tests/gdunit/prototype_live_ui_test.gd'
$longSession = 'game/diagnostics/tests/gdunit/long_session_test.gd'
$rearLayout = 'game/diagnostics/tests/gdunit/rear_layout_test.gd'
$workforcePanel = 'game/diagnostics/tests/gdunit/workforce_panel_test.gd'
$retainedSuites = @($trainingDomain,$trainingInput) + $logisticsTests
$selections = @($selection)
if ($GuardsOnly) { $selections += $budgetGuards }
if ($LongSessionOnly) {
    $selections = @($longSession)
} elseif ($LogisticsOnly) {
    $selections = $logisticsTests + @($reportDelivery)
} elseif ($OrdinaryMenusOnly) {
    $selections = @($ordinaryMenus)
} elseif ($LiveFrameOnly) {
    $selections = @($liveFrames)
} elseif ($CohesionOnly) {
    $selections = @($cohesion)
} elseif ($PlacementReadsOnly) {
    $selections = @($placementReads)
} elseif ($PlacementOnly) {
    $selections = @($placement,$placementReads)
} elseif ($PlacementBenchmarkOnly) {
    $selections = @($placement)
} elseif ($TrainingUiOnly) {
    $selections = @($trainingInput)
} elseif ($TrainingOnly) {
    $selections = @($trainingRead,$trainingDomain)
    if (!$Headless) { $selections += $trainingInput }
} elseif ($UiOnly -or ($BuildingsOnly -and !$Headless)) {
    $selections += $placement
} elseif (!$GuardsOnly -and !$BuildingsOnly -and !$ButtonsOnly) {
    $selections += @($trainingDomain,$trainingInput)
}
$exclusions = @()
if (!$LongSessionOnly) { $exclusions += $longSession }
if ($Headless) {
    $exclusions += @($placement,$ordinaryMenus,$trainingInput,
        'game/diagnostics/tests/gdunit/menu_performance_test.gd:test_03_observe_live_menu_actions_at_one_x',
        ($logisticsTests[0] + ':test_ordinary_request_and_cancel_buttons_do_not_create_goods_or_vehicles'))
    if (!$BuildingsOnly) { $exclusions += 'game/diagnostics/tests/gdunit/a_full_ui_test.gd' }
}
$expected = if ($LongSessionOnly -or $OrdinaryMenusOnly) {1} elseif ($LogisticsOnly) {if ($Headless) {11} else {12}} elseif ($LiveFrameOnly) {5} elseif ($CohesionOnly) {5} elseif ($PlacementBenchmarkOnly) {1} elseif ($PlacementReadsOnly) {6} elseif ($PlacementOnly) {12} elseif ($TrainingUiOnly) {4} elseif ($TrainingOnly) {if ($Headless) {18} else {22}} elseif ($GuardsOnly) {13} elseif ($BuildingsOnly) {if ($Headless) {2} else {8}} elseif ($ButtonsOnly) {1} elseif ($UiOnly) {9} else {if ($Headless) {60} else {76}}
$runPlan = @{headless=[bool]$Headless; foreground=[bool]$Foreground; selection=$selections; exclusions=$exclusions; expected_cases=$expected; visible_fps_certified=$false; scope=$(if ($Headless) {'Background functional checks; listed native-input cases are excluded; no rendering/FPS certification.'} else {'Explicit foreground native run; may move the mouse and take focus; passing selected checks alone is not whole-game FPS certification.'})}
if ($ListOnly) { $runPlan | ConvertTo-Json -Depth 4; exit 0 }
Write-Output $runPlan.scope
New-Item -ItemType Directory -Path $logDirectory,$testProject -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $projectRoot 'logs/.gdignore'), '')
Copy-Item -LiteralPath (Join-Path $projectRoot 'project.godot') -Destination $testProject
$sourceHashes = @{ 'project.godot' = (Get-FileHash -LiteralPath (Join-Path $projectRoot 'project.godot') -Algorithm SHA256).Hash.ToLowerInvariant() }
# Keep retained training and logistics suites explicit. No editor addon is
# installed in the user's project, and unrelated archived suites stay excluded.
foreach ($file in Get-ChildItem -LiteralPath (Join-Path $projectRoot 'game') -Recurse -File) {
    $relative = [IO.Path]::GetRelativePath($projectRoot, $file.FullName).Replace('\','/')
    if ($relative.Contains('/tests/') -and !$relative.StartsWith('game/diagnostics/tests/gdunit/') -and $relative -notin ($retainedSuites + @($retainedSuites | ForEach-Object { $_ + '.uid' }))) { continue }
    $destination = Join-Path $testProject $relative
    New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $destination
    $sourceHashes[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
}
$sourceHashes | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $logDirectory 'source_manifest.json')
& (Join-Path $PSScriptRoot 'setup_gdunit4.ps1') -TargetProject $testProject
$importArgs = @('--headless','--editor','--path',('"'+$testProject+'"'),'--import')
$importProcess = Start-Process -FilePath $GodotPath -ArgumentList $importArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logDirectory 'import.log') -RedirectStandardError (Join-Path $logDirectory 'import-errors.log')
if (!$importProcess.WaitForExit(45000)) { $importProcess.Kill(); throw "Isolated test import timed out. Logs: $logDirectory" }
if ($importProcess.ExitCode -ne 0) { throw "Isolated test import failed. Logs: $logDirectory" }
$parsePaths = if ($GuardsOnly) { $selections } elseif ($LongSessionOnly -or $LogisticsOnly -or $OrdinaryMenusOnly -or $TrainingOnly -or $TrainingUiOnly -or $PlacementOnly -or $PlacementBenchmarkOnly -or $PlacementReadsOnly -or $CohesionOnly -or $LiveFrameOnly -or $UiOnly -or $BuildingsOnly) { $selections } elseif ($selection -eq 'game/diagnostics/tests/gdunit') { @('game/diagnostics/tests/gdunit/a_full_ui_test.gd','game/diagnostics/tests/gdunit/menu_performance_test.gd',$trainingRead,$trainingDomain,$trainingInput,$placement,$cohesion,$liveFrames,$placementReads,$budgetGuards,$reportDelivery,$ordinaryMenus,$rearLayout,$workforcePanel) + $logisticsTests } else { @($testPath) }
$parseIndex = 0
foreach ($parsePath in $parsePaths) {
    $parseOut = Join-Path $logDirectory ("compile-$parseIndex.log")
    $parseError = Join-Path $logDirectory ("compile-$parseIndex-errors.log")
    $parseArgs = @('--headless','--path',('"'+$testProject+'"'),'--check-only','--script',('res://'+$parsePath))
    $parseProcess = Start-Process -FilePath $GodotPath -ArgumentList $parseArgs -PassThru -WindowStyle Hidden -RedirectStandardOutput $parseOut -RedirectStandardError $parseError
    if (!$parseProcess.WaitForExit(45000)) { $parseProcess.Kill(); throw "Test compilation timed out. Logs: $logDirectory" }
    if ($parseProcess.ExitCode -ne 0 -or (Select-String -LiteralPath $parseError -Pattern 'SCRIPT ERROR:|ERROR:')) { throw "Test compilation failed: $parsePath. Read $parseError." }
    $parseIndex++
}
$engineLog = Join-Path $logDirectory 'engine.log'
$arguments = @('--path',('"'+$testProject+'"'),'--rendering-method','gl_compatibility','--disable-vsync','--max-fps',([string]$FrameCap),
    '--log-file',('"'+$engineLog+'"'),'--script','res://addons/gdUnit4/bin/GdUnitCmdTool.gd',
    '-rd','res://gdunit_reports','-rc','1')
foreach ($selectedPath in $selections) { $arguments += @('-a',('res://'+$selectedPath)) }
foreach ($excluded in $exclusions) { $arguments += @('-i',('res://'+$excluded)) }
if ($Headless) { $arguments = @('--headless') + $arguments + @('--ignoreHeadlessMode') }
if ($ContinueAfterIssues) { $arguments += '-c' }
if ($GuardsOnly) { $arguments += @('-i',($testPath+':test_03_observe_live_menu_actions_at_one_x')) }
if ($PlacementBenchmarkOnly) {
    foreach ($case in @('test_00_default_game_move_preview_place_and_repeat_at_one_x','test_01_transformed_map_rotation_rejected_click_recovery_and_cancel_at_one_x','test_02_sustained_pointer_motion_and_post_placement_workload_at_one_x','test_03_default_game_without_building_control_at_one_x','test_05_hover_is_provisional_and_click_uses_current_pose_and_geometry')) {
        $arguments += @('-i',($placement+':'+$case))
    }
}
if ($BuildingsOnly) { $arguments += @('-i',($testPath+':test_12_every_runtime_button_and_menu_choice_in_game_and_retained_reviews')) }
if ($ButtonsOnly) { $arguments += @('-i',($testPath+':test_10_every_buildable_facility_placement_rotation_rejection_and_cancellation'),'-i',($testPath+':test_11_every_started_building_cancellation_keeps_consumed_materials_consumed')) }
$environmentValues = @{
    TRENCHO_PERF_RUN_DIRECTORY = $logDirectory; TRENCHO_PERF_ENGINE_LOG = $engineLog
    TRENCHO_PERF_FRAME_MS = $FrameLimitMs.ToString([Globalization.CultureInfo]::InvariantCulture)
    TRENCHO_PERF_ACTION_MS = $ActionLimitMs.ToString([Globalization.CultureInfo]::InvariantCulture)
    TRENCHO_PERF_CALL_BUDGET = [string]$InspectCallBudget
    TRENCHO_CALL_STACKS = $(if ($WithoutCallStacks) {'0'} else {'1'})
    TRENCHO_PERF_OBSERVATION_SECONDS = $ObservationSeconds.ToString([Globalization.CultureInfo]::InvariantCulture)
    TRENCHO_UI_CONTINUE_AFTER_ISSUES = $(if ($ContinueAfterIssues) {'1'} else {'0'})
    TRENCHO_UI_PROFILE = $ButtonProfile
    TRENCHO_UI_BUTTON_TEXT = $ButtonText
    TRENCHO_TRAINING_OBSERVATION_SECONDS = $TrainingObservationSeconds.ToString([Globalization.CultureInfo]::InvariantCulture)
}
$previousEnvironment = @{}
try {
    foreach ($name in $environmentValues.Keys) {
        $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        [Environment]::SetEnvironmentVariable($name, $environmentValues[$name], 'Process')
    }
    $testProcess = Start-Process -FilePath $GodotPath -ArgumentList $arguments -WorkingDirectory $testProject -PassThru -WindowStyle $(if ($Headless) {'Hidden'} else {'Normal'}) -RedirectStandardOutput (Join-Path $logDirectory 'stdout.log') -RedirectStandardError (Join-Path $logDirectory 'stderr.log')
} finally {
    foreach ($name in $previousEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], 'Process') }
}
$started = [DateTime]::UtcNow
@{process_id=$testProcess.Id; project=$testProject; started_utc=$started.ToString('o'); selection=$selections; headless=[bool]$Headless; run_plan=$runPlan; engine_arguments=$arguments; continue_after_issues=[bool]$ContinueAfterIssues; observation_seconds=$ObservationSeconds; training_observation_seconds=$TrainingObservationSeconds; frame_limit_ms=$FrameLimitMs; action_limit_ms=$ActionLimitMs; frame_cap=$FrameCap; disable_vsync_requested=$true; inspect_call_budget=$InspectCallBudget; stacks_enabled=(!$WithoutCallStacks); placement_benchmark_only=[bool]$PlacementBenchmarkOnly; profile_filter=$ButtonProfile; text_filter=$ButtonText} | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $logDirectory 'launcher.json')
$heartbeat = Join-Path $logDirectory 'heartbeat.json'
Write-Output "GdUnit4 6.2.2 isolated run: $logDirectory"
while (!$testProcess.HasExited) {
    Start-Sleep -Milliseconds 500
    $testProcess.Refresh()
    if ($testProcess.HasExited) { break }
    $cpuSample = @{utc=[DateTime]::UtcNow.ToString('o'); unix_seconds=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()/1000.0; total_cpu_seconds=$testProcess.TotalProcessorTime.TotalSeconds; working_set_bytes=$testProcess.WorkingSet64}
    [IO.File]::AppendAllText((Join-Path $logDirectory 'process_cpu.jsonl'), ($cpuSample | ConvertTo-Json -Compress) + [Environment]::NewLine)
    $stalled = ([DateTime]::UtcNow - $started).TotalSeconds -gt 45
    if (Test-Path -LiteralPath $heartbeat) {
        $stalled = ([DateTime]::UtcNow - (Get-Item -LiteralPath $heartbeat).LastWriteTimeUtc).TotalSeconds -gt $UnresponsiveSeconds
    }
    if (!$stalled -and ([DateTime]::UtcNow - $started).TotalSeconds -lt 3600) { continue }
    @{reason='gdunit_watchdog'; note='Only this isolated test process was stopped.'; process_id=$testProcess.Id} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $logDirectory 'watchdog.json')
    $testProcess.Kill()
    $testProcess.WaitForExit()
    throw "GdUnit4 stopped responding. Logs: $logDirectory"
}
$testProcess.WaitForExit()
$report = Join-Path $testProject 'gdunit_reports/report_1'
if (Test-Path -LiteralPath $report) { Copy-Item -LiteralPath $report -Destination (Join-Path $logDirectory 'gdunit-report') -Recurse }
$xmlPath = Join-Path $logDirectory 'gdunit-report/results.xml'
if (!(Test-Path -LiteralPath $xmlPath)) { throw "GdUnit4 did not produce its JUnit report. Logs: $logDirectory" }
[xml]$xml = Get-Content -LiteralPath $xmlPath -Raw
$cases = @($xml.SelectNodes('//testcase'))
$problems = @($xml.SelectNodes('//failure|//error|//skipped'))
Write-Output "GdUnit4: $($cases.Count) cases reported; $($problems.Count) failures/errors/skips. Logs: $logDirectory"
if ($testProcess.ExitCode -ne 0 -or $problems.Count -gt 0) { throw "GdUnit4 found a failing check. See $xmlPath and the action logs under $logDirectory." }
if ($cases.Count -ne $expected) { throw "Expected $expected GdUnit4 cases, found $($cases.Count)." }
if (Select-String -LiteralPath (Join-Path $logDirectory 'stderr.log') -Pattern 'SCRIPT ERROR:|ERROR:') { throw "Engine error in GdUnit4 run. Logs: $logDirectory" }
Write-Output "PASS: selected GdUnit4 checks. Read the action summaries and UI coverage under $logDirectory."
if ($LogisticsOnly) { Write-Output 'Logistics component stepping and report delivery are not a native FPS certification. Run the placement/live-frame checks separately.' }

if ($LongSessionOnly) { Write-Output 'Clock-progress endurance is not FPS certification. Raw frame costs are retained in clock_endurance.json and frame_intervals.json.' }
