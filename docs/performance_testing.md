# UI, construction and performance testing

## Run

Routine runs are **headless by default**. They have no game window, desktop
focus or OS cursor movement. Double-click **Run GdUnit4 Performance Tests.cmd**
for the 60-case background selection. `launcher.json` records the exact selected
suites, exclusions, expected case count and engine arguments. A background pass
does not certify native popups, physical mouse input, rendering or visible FPS.
The 16.67 ms frame/action ceilings remain unchanged.

Use `-Foreground` only for a reported testing issue, bug or regression that
needs native input or visible performance evidence. The full foreground
selection contains 76 cases. Sixteen desktop-dependent cases are omitted from
routine runs: the three full UI cases, six pointer cases, four training input
cases, ordinary menu observation, handler menu observation and one logistics
request/cancel button case. Native-only selectors such as `-PlacementOnly`,
`-UiOnly`, `-ButtonsOnly`, `-TrainingUiOnly` and `-OrdinaryMenusOnly` refuse to
launch without `-Foreground`; the corresponding shortcuts accept this flag.
`-Headless -Foreground` is rejected. Minimized native scene runners are not used:
the pinned GdUnit scene runner foregrounds its window and warps the desktop
cursor during initialization. Routine tests use Godot's headless display driver
instead, without altering the vendored framework or normal F5 window settings.

**Run Long Session Check.cmd** explicitly selects a separate 330-real-second
1x clock-endurance case, headless by default. It is excluded from both normal
selections. It rejects clock stalls, identity/speed changes and excess elapsed
debt; it retains `clock_endurance.json` and every raw `frame_intervals.json`
interval. This diagnoses the reported 308-second clock stop; its liveness pass
is explicitly not FPS certification. The clock regression includes a deliberately
slow initial settlement and an actual worker reporting boundary at the same
unchanged 4 ms cooperative allowance.

Double-click **Run GdUnit4 Performance Tests.cmd** for the formal tests and
JUnit/HTML reports. GdUnit4 6.2.2 is acquired using the repository's existing
commit/checksum pin. The launcher snapshots production code and this suite into
an ignored test project under `.tools/`, imports the framework there, and runs
the suites under `game/diagnostics/tests/gdunit/` plus two explicitly selected
retained training suites: domain behavior and the updated native Train input
tests. The full foreground selection has **76 declared GdUnit cases**: the original 14, nine
training read/result guards, nine retained training domain cases and four native
training cases, plus six default-game pointer-placement cases and six
provisional placement-query guards/benchmarks. Aggregate cases
contain many individual scenarios. Five formation/ammunition/mounted-read guards
and five live-frame/presentation guards complete the earlier selection.
Three additional acceptance guards verify that 17 ms frames/actions pause and
write failure logs, and that attempted 100 ms overrides cannot weaken the gate.
Five rear logistics components, six forward/planning components and one
diagnostic-report delivery check extend the earlier 61-case selection.
One ordinary full-world menu case observes twelve actual navigation phases at
1x with the same strict frame, action and simulation-progress limits.
One fixed-rear route guard compares all template entrance pairs and blocked
centres against the original uncached shortest-path implementation.
One supply-intent guard protects manual quantities, net outstanding promises,
cancellation holds and explicit reopening without creating physical goods.
One worker-panel lifecycle guard verifies finite frame-separated control
creation, correct capacities, idle completion and safe queued-work cancellation
when a different session binds, without changing either physical ledger.
This is a source inventory, not a claim that the default selection passed.

Double-click **Run Logistics Checks.cmd**, or use `-LogisticsOnly
-WithoutCallStacks`, to run eleven background logistics/report checks. Adding
`-Foreground` includes the twelfth native request/cancel button check. They
cover purchased workers, real workshop inputs and intact-weapon storage capacity, two returning-truck rear
deliveries, ordinary request/cancel controls, two physical forward issues,
interruption, fresh route/person/fuel admission and retained AI decisions.
Their explicit component stepping does not certify live FPS or the complete
ordinary autonomous game loop. Native placement/live-frame checks remain
separate; every measured gameplay frame/action retains the 16.67 ms ceiling.

Double-click **Run Prototype Menu Checks.cmd**, or use `-OrdinaryMenusOnly
-WithoutCallStacks -Foreground`, for the ordinary persistent full-world menu sweep. Its one
aggregate case must finish all twelve native-input/observation phases at 1x.
It uses the same 16.67 ms frame/action gates and progress/backlog checks.
This remains separate from construction and the complete production/supply loop.

No GdUnit4 editor plugin is enabled in the main project. Its new tests are also
excluded from the normal editor resource scan. Other retained suites are not
selected; their presence in the repository is not passing test evidence.

Run **Run Full UI Coverage.cmd** with `-Foreground` to attempt the complete UI/building
matrix, continuing after logged issues. Each failing fixture is paused before
continuation. The existing performance launcher stops at the first failing
case by default. Both modes exit unsuccessfully when issues are found.

The native button/menu tests require an explicit `-Foreground` run. Headless is
the default with no selector and with `-PlacementReadsOnly`, `-GuardsOnly`,
`-BuildingsOnly`, `-CohesionOnly`, `-LiveFrameOnly`, `-LogisticsOnly`,
`-LongSessionOnly` or `-TrainingOnly`. Headless
training runs only its 18 domain/read cases; the 22-case rendered training
selection also checks the native UI. Headless building tests exercise viewport
input but do not validate rendering or native popup windows.

Double-click **Run Training Tests.cmd** for the bounded training migration suite.
Its prepared fixtures are explicitly different from the normal empty opening.
The native tests cover instructor/student input, requests, access, withdrawal,
P01 then P08 on the same person, selection, focused drafts, hidden-panel catch-up
and session replacement at a smaller window size. Text selection is arranged by
the harness; characters, submission, list navigation and popup selection use
engine GUI input. This does not certify the platform's Ctrl+A shortcut.

Three separate warmed observations run at 1x (two seconds each by default).
Use `-TrainingObservationSeconds 30 -WithoutCallStacks` for longer measurements.
Functional course completion uses explicit domain stepping between inputs;
that synthetic work and raw-state/screenshot capture are journaled as excluded
test work, outside UI timing/count budgets. The live 1x observations contain no
such fast-forward. Failures/errors remain visible during excluded test work.

The read guards preserve nine frozen pre-change training states and display
projections, compare independent worlds, test nested detachment and selected
withdrawn/completed/injured/dead students, and preserve the current snapshot
normalization. They also require zero broad world exports and
no global reconciliation/session notification for explicitly read-only rejected
training requests. This is bounded coverage, not a claim to test every state.

Double-click **Run Menu Performance Suite.cmd** for a background handler sweep.
It saves the first issue and exits, rather than waiting in an invisible paused
window. Add `-Foreground` for the interactive version, which leaves its test
window paused at the first issue. **Continue after issue**
continues to the next action, including discovering controls in the menu where
the issue occurred. A new run always uses a separate disposable game session.

Both launchers write to `logs/`; the interactive launcher's `latest_run.txt`
points to its most recent run. Output is ignored by Git and Godot's importer.

## Current 60 FPS acceptance (E16)

The user requires a minimum of 60 FPS. The shared budget is
`game/diagnostics/performance_budget.gd`: 1000/60 ms per measured frame and
synchronous action. Launchers reject larger limits; direct scene/probe
settings cannot weaken the ceiling or disable it with zero/nonfinite values.
The old 100 ms results below are historical severe-stall checks, not current
acceptance passes.

Performance launchers now request disabled VSync and default to uncapped
rendering (`-FrameCap 0`) so deliberate 60 FPS pacing is not mistaken for work.
The cap/request and raw wall intervals are recorded. This creates a new baseline;
do not claim a speedup by comparing it with the old capped input stress.

[The E16 record](evidence/sixty_fps_acceptance.json) retains three passing
rejection/pause/log contracts and ten passing existing guards. The actual game
still fails: 22.572 ms without stage profiling, and 25.236 ms with it. A separate
service-attribution capture observes a 46.726 ms opening-policy scope and a
21.255 ms planning/admission scope. These are inclusive wall times, not additive
self CPU timings. The game has not met its 60 FPS requirement.

## Historical provisional pointer feedback regression (E15)

The [placement interaction record](evidence/placement_interaction_slice.json)
records a stronger actual-game test: six real sites, eight pointer motions per
frame, and a fresh placement at 1x. Before the fix, three separately restarted
runs stopped within a second at 103–106 ms frames. That run used the then-current 100 ms gate; E16 supersedes it. After the fix, all three 30-second hover observations and
their 30-second post-placement observations passed, with hover peaks of
72.5–74.8 ms. Those long-run p99 frame intervals remain about 50 ms; this is
not evidence of consistent 60 fps or completion of the scheduling overhaul.

Pointer events now read fresh provisional footprint geometry. An amber ghost
means access is checked when placing; explicit **Preview legal site** retains
full validation. The service and authoritative click share current footprint
rules, including cancelled sites holding loose stock. Full route/connectivity
checks do not run on hover. Live pointer-dispatch medians fell from about
9.7–10.1 ms to 0.024 ms in the prepared six-site scenario. Failed before runs
are truncated; their frame percentiles are not a matched 30-second baseline.
Raw samples and separate equivalent-fixture query timings are retained.

The wider construction matrix also exposed a viewport/window-coordinate bug
in its mouse helper; local-coordinate input is now explicit. All 22 placement/
rotation scenarios passed after that correction. The previously recorded
vehicle-works started-cancellation timing failure remains open; see E15.
The historical full 55-case sweep was not declared passing; the current selection has 58 cases.

## Earlier cohesion and live-frame fix (E13)

The [cohesion and placement fix record](evidence/cohesion_placement_fix.json)
retains three clean runs of all four actual-game 1x placement cases. Frame and
action limits stayed at **100 ms**, full inspections at **30,000 per second**,
and caller stacks stayed enabled. The final default run peaked at **93.931 ms**;
the longer three-second observations peaked at **99.585 ms**. All phases
completed. Progress guards require the real simulation to keep pace with 1x
wall time and prevent a passing frame budget from hiding growing time debt.

Fresh cohesion/member facts replace detailed per-person exports; initial squad
ammunition counts share one fresh scan. Mounted reloads inspect a hull only when
due, and rack queries stay local. The scene owner coalesces duplicate wall-clock
pumps within one engine process frame, preserving elapsed time for the next
pump and retaining every step for explicit-delta models. Cohesion timestamps,
physical safety, crew and reservation rules remain immediate.

The five read guards, two live-frame guards, 22 training cases and ten original
guards passed, including all 13 existing domain hashes and nine training states.
Six retained scripts also passed 1,630 checks. This is bounded regression
evidence; the full 47-case sweep was not rerun in this fix.

## Historical training slice evidence

The [training slice record](evidence/training_read_slice.json) retains the
2026-11-03 source/report hashes, frozen checkpoints, native inputs and matched
measurements. All 22 current training cases passed across the separate headless
and native selections. In the prepared 1x comparison, full inspections per direct
Train refresh fell from 153 to 55, median refresh time from 4.3515 to 0.9235 ms,
and process CPU per wall second by about 31.5%. Three observations per version
are descriptive; they do not establish a general game-wide speedup.

The broader 898-scenario UI/building audit recorded no functional-contract
failures but four timing failures. The legacy live-menu case also failed timing.
That last broad audit was not passing and was not rerun in this fix. Its other
timing issues remain open until revalidated. `advance_time` and global settlement
remain active pending later ownership/order migrations.

## GdUnit4 cases

The original fourteen-case selection contains the following ten focused
guards and one live-menu case, plus three UI matrix cases described below.

1. Cross-file caller chains must group A → B → C twice and D → B → C once in
   the same real second, preserve the completed report and reset next second.
2. Counters-only mode must retain function totals without recording stacks.
3. Explicit wall-time scope samples must retain call/total/maximum values
   across real-second reporting without becoming function-entry counts.
4. Build at 1x must read construction data, not the full simulation/ledger
   snapshot. The opening refresh may perform at most four full entity
   inspections. Map markers must match the existing inspection's positions,
   owners, IDs, quantities, holders and carrying IDs without full inspections.
5. Narrow staffing queries must preserve actual/present/pending/retained/
   committed counts for the real rear worker pool while doing no full entity
   inspections. The fixture requests three haulers among twelve rear workers.
6. Thirteen frozen checkpoints must preserve canonical ledger, military, HQ
   job and receiving state for the empty-field opening, incapacitated leader
   and a physically admitted HQ hull/person issue fixture. Coarse and
   partitioned HQ advances must match, with clean audits and actual delivered
   shells, fuel and rifle ownership.
7. Narrow predicates must read current authoritative fields, reject isolated
   ineligible record variations and count both loose and loaded personal
   ammunition without subtracting reservations. Synthetic field variations
   test predicates; they do not prove the corresponding gameplay transitions.
8. One hundred repeated commander/vehicle/HQ checks must stay within focused
   full-inspection limits in the opening and HQ fixture. Wall timings are
   reported for comparison, without a fragile microsecond assertion.
9. Narrow sight candidates must preserve actual squad/APC contact output
   compared with full snapshot inputs, including a positive enemy contact,
   friendly rejection and differing assignment filters.
10. Nearby patient selection must match canonical scans in insertion order,
    including the exact 60 metre boundary, while inspecting only matches.
11. The live-menu/action exerciser runs at 1x, discovers available controls,
   observes their callbacks and pauses on the first budget violation. GdUnit4
   checks that the clock and session physics are paused and reports a failure
   with the triggering action/log directory. It then frees the test scene and
   exits; use the interactive launcher to leave the paused scene open.

## UI input and construction matrix

`a_full_ui_test.gd` adds three aggregate GdUnit cases with individual records
in `ui-contracts/group-*/cases.jsonl`:

- All **11 buildable facilities in both orientations**: actual button input,
  preview without mutation, coordinate placement, field-click placement,
  overlapping/out-of-bounds rejection, preview cancellation through the button,
  Escape and right-click, R rotation, selected-site cancellation, repeated
  cancellation, reusable cleared footprints and material conservation. Fixed
  Terminal/Personnel placement is rejected. The catalogue supplies the list;
  adding another buildable kind automatically adds its cases.
- All **11 started-work cancellations and 11 completed-building rejections**: legal setup commands deliver materials
  and physically report builders; the measured cancellation press occurs at 1x.
  The test requires positive progress, exactly the starting half of that
  facility's M11 consumed, cancellation and no refund of consumed material.
  Completed fixtures must consume the full recipe and reject the same cancel
  input while preserving the completed facility and remaining stock.
  Explicit-time fixture preparation is excluded from the performance window;
  it is not presented as hundreds of real seconds at live 1x.
- Runtime Button, CheckBox/CheckButton, OptionButton and MenuButton instances
  in the main game, standalone rear, optional HQ diagnostics and every scene
  listed by `Main.REVIEWS`. Each action records actual input receipts. Native
  menu choices verify the selected item ID; dropdowns try an available choice.
  New-game acceptance/cancellation and consumed-recipe confirmation/decline
  use actual dialog buttons and check the resulting session/recipe/batch.
  Navigation/help have specific postconditions. Main/standalone/HQ fixtures
  reset between actions. Supplemental review scenes run their own sequences,
  restoring the recorded recipe or movement mode before a contextual action.

Focusable controls receive engine GUI key press/release events; native menus
and dropdowns use GdUnit's mouse input and global key routing. The suite never
calls a button's `pressed.emit()` to satisfy its input receipt. Special keys
carry Unicode zero to avoid GdUnit 6.2.2's invalid Unicode value for Enter on
Godot 4.7. Engine-owned internal subcontrols are not separate project actions;
confirmation buttons are included explicitly. Regenerated widgets use stable
routes and duty identities rather than changing generated node names.
Native mouse coordinates follow Godot's viewport/canvas/window transform so
resizing the rendered test window does not target the wrong control. See the
[custom-input coordinate guide](https://docs.godotengine.org/en/4.7/tutorials/2d/2d_transforms.html#feeding-custom-input-events).

`fixtures/ui_button_contracts.json` is generated from the core UI source by
the UI diagram updater. Source fingerprints reject a stale inventory before
the button sweep starts. The complete unfiltered run fails if a declared
button/toggle/menu definition has no enabled input receipt. A dynamic factory
match is not proof of every possible argument or game state. Runtime discovery
continues after actions so newly exposed project controls enter the queue.
Hidden/missing targets are coverage failures. Disabled controls receive a
negative input test with an expected zero `pressed` signals; that is reported
as `disabled_input_rejected`, and does not satisfy enabled source coverage.

Every measured case checks structured engine/script/shader errors and available
simulation audits, and records feedback plus function counts/stacks. A completed
button press is `handler_input_exercised`: it does **not** imply a successful
dispatch, completed training, delivery or every gameplay outcome. Rejected and
idempotent actions can exercise a handler; the action-specific contracts above
and the read guards provide the additional correctness checks. Review scenes
without an audit method are labelled `audit_checked: false`.

Normal game observations use the shared 1x clock. Pause/2x controls are tested
for their intended transition and 1x is restored before observation. Retained
review controls can intentionally jump their independent fixture clocks; those
are labelled supplemental profiles rather than normal-game 1x timing evidence.

`fixtures/read_path_baseline.json` was captured twice before the first read
changes, with identical checkpoint hashes. The opt-in capture script requires
`--out=<new path>` and refuses to overwrite a baseline. Its hashes remain
frozen; non-finite values in explanatory tank/rifle details were normalized to
strings for strict JSON without changing any expected checkpoint hash.

The earlier run at `logs/gdunit4-performance-2026-11-02T23-54-24-43416/`,
before the native-input matrix was added,
passed all ten focused guards and stopped the live case on a **118.642 ms**
frame during Build placement. Later actions remain untested. Runtime stderr
was empty; isolated import stderr contains editor-settings write errors in
this restricted environment. See
[read-slice evidence](evidence/overhaul_read_slice.json) for measurements and
remaining work. Current matrix measurements and their exact tested scope are
recorded in [UI acceptance evidence](evidence/ui_acceptance_matrix.json).
The full performance suite is not green.

## Coverage and limits

The plan covers Build, Supplies, Workers/Jobs, Production, Battlefield, Hauling,
Inspection, Training, Vehicles, Army Supply, Dispatch, Diagnostics and Rear.
It discovers buttons, toggles, numeric fields, selector choices, list entries,
nested tabs and popup choices in reachable panels. Additional controls revealed
by actions are discovered again, with stable routes to avoid repeated discovery
of the same dynamically rebuilt controls. Build also exercises preview,
rotation, placement and cancellation; Session exercises new-game confirmation
and cancellation. Getting-started help and the More systems popup are included.

The older live-menu exerciser is **not proof of every gameplay state or every action's successful
outcome**. Disabled controls, empty lists and unavailable targets are logged as
untested. Generic destructive confirmations are cancelled and logged. The
retained diagnostic fixtures that jump time, and Pause/2x controls, are excluded
from the 1x sweep. The sweep calls production handlers/signals; it does not prove
physical mouse input, visual layout, drag-and-drop or GPU performance. Headless
runs have additional rendering/input limitations. A completed performance sweep
only means its observed actions stayed within the selected budgets.

The full run stops early when an issue is found. The pending-action list and
coverage entries in `summary.json` identify what has not yet been reached.

## Default budgets

- Minimum accepted rate: **60 FPS**; **every measured frame must fit 1000/60 ms** (about 16.67 ms). Average FPS or good percentiles cannot excuse a slow frame.
- One synchronous action dispatch/handler receipt: **1000/60 ms**. Native queued input includes
  event-queue latency; the older live-menu case measures synchronous callbacks.
- `inspect_entity`: **30,000 entries per real second**. This is a call-volume
  warning budget, not proof of execution cost.
- Each action is observed for **two real seconds**, at normal game speed.

Frame intervals include OS scheduling and render pacing; they do not attribute
a stall to the last clicked function. Function counters and stack capture add
overhead. Stacks are captured by default; compare `-WithoutCallStacks` to obtain
a counters-only baseline. The stack grouping guard still deliberately captures
its three fixture calls in that mode.

Example adjustments from PowerShell:

```powershell
# Limits above 1000/60 ms are rejected, including the historical 100 ms setting.
./tools/run_gdunit4_performance.ps1 -GuardsOnly -Headless
./tools/run_gdunit4_performance.ps1 -CohesionOnly -Headless -WithoutCallStacks
./tools/run_gdunit4_performance.ps1 -LiveFrameOnly -Headless -WithoutCallStacks
./tools/run_gdunit4_performance.ps1 -PlacementOnly -ContinueAfterIssues -Foreground
./tools/run_gdunit4_performance.ps1 -TrainingOnly -WithoutCallStacks
./tools/run_gdunit4_performance.ps1 -TrainingOnly -Headless -WithoutCallStacks
./tools/run_gdunit4_performance.ps1 -TrainingOnly -TrainingObservationSeconds 30 -WithoutCallStacks -Foreground
./tools/run_gdunit4_performance.ps1 -TrainingUiOnly -TrainingObservationSeconds 30 -WithoutCallStacks -Foreground
./tools/run_gdunit4_performance.ps1 -WithoutCallStacks
./tools/run_gdunit4_performance.ps1 -UiOnly -ContinueAfterIssues -WithoutCallStacks -Foreground
./tools/run_gdunit4_performance.ps1 -BuildingsOnly -WithoutCallStacks
./tools/run_gdunit4_performance.ps1 -ButtonsOnly -ButtonProfile 'Main game' -ButtonText 'Session' -WithoutCallStacks -Foreground
./tools/run_menu_performance.ps1 -ObservationSeconds 3
```

`-UiOnly` selects the three matrix cases plus six pointer-placement cases,
`-BuildingsOnly` the two building matrix cases plus the six pointer cases
(headless keeps only the two matrix cases), and `-ButtonsOnly` the runtime button
case. `-ContinueAfterIssues` also
disables GdUnit's fail-fast behavior. Profile/text filters are debugging subsets;
they do not certify full coverage and skip the complete-source coverage gate.
Profile filters accept an exact label or a wildcard such as `'G04*'`.
For a faster functional sweep, `-ObservationSeconds 0.1` shortens observation;
windows shorter than one second do not certify the per-action one-second call
budget. Keep the default two seconds for performance investigations.

`-TrainingUiOnly` selects just the four native training cases, for a directly
matched UI/performance comparison without running other suites first.

Double-click **Run Building Placement Tests.cmd**, or use
`./tools/run_gdunit4_performance.ps1 -PlacementOnly -Foreground`, for six native pointer
regressions and six placement-query guards. The native cases run the actual
default connected game at 1x;
they do not substitute the simplified rear-only matrix fixture. Real GUI events
select the facility popup, move a ghost through fractional world coordinates,
click to place, repeat with another facility, zoom/pan, rotate, recover from an
overlapping click and cancel. Sustained eight-motion bursts per frame explicitly
stress unaccumulated viewport input; they do not claim to emulate OS polling.
A separate no-building control observes at least twelve seconds of the running
game. Each phase logs counts, caller stacks, pointer/click dispatch costs,
logical time and outstanding simulation time. A budget violation pauses that
test world and leaves subsequent phases listed as pending; continuing runs the
next isolated test. These cases are also included in the default and rendered
full UI/building selections.

Use `-PlacementReadsOnly -Headless` for the six isolated query/commit guards,
or `-PlacementBenchmarkOnly -ObservationSeconds 30 -WithoutCallStacks` for
the populated-field native performance case alone. Benchmark mode selects one
case; it does not certify the full placement or UI suite. The query benchmark
alternates full preview and footprint hints on separate equivalent six-site
fixtures with counters disabled during the timed calls. Live benchmarks keep
counters on; full caller-stack validation is run separately. Each measured UI
action now retains raw frame intervals, and pointer sweeps retain raw dispatch
intervals for reproducible quantiles.

The [pointer regression evidence](evidence/building_pointer_regression.json)
preserves the original failing revision and test gap; its resolution points to
the subsequent fix above. That historical diagnostic run with relaxed stops is
not a performance pass. The historical clean runs used the original 100 ms
frame/action and 30,000-inspection limits, plus actual 1x progress/debt guards.

`-CohesionOnly` runs five focused read/transition guards, including an independent
legacy cohesion/membership oracle, public movement/injury transitions, scalar
versus batched ammunition after loading/firing, and local reserved rack reads.
`-LiveFrameOnly` runs five guards for same-frame catch-up, wall-time conservation,
Pause/2x, replacement, presentation time, unchanged explicit-delta stepping and
positive clock progress when initial settlement exhausts its work allowance.

The launcher stores the exact source-file hashes and selected suite paths in
each log directory. `process_cpu.jsonl` samples cumulative CPU seconds and
working set for the owned test process. Native training reports retain raw
per-frame intervals, engine monitor values, direct refresh durations and
logical-time/work progress for each run. CPU samples cover the whole process;
engine monitors can lag, and neither provides script CPU self/total attribution.
Keep separate runs and identical diagnostic modes when comparing results.

Set `TRENCHO_PROFILE_STAGES=1` for opt-in inclusive service and squad-decision
wall scopes in the existing per-second duration reports. Leave it unset for
ordinary comparisons. These durations include nested work and instrumentation;
they are not script CPU self times. The final placement passes used this extra
stage profiling off and the existing complete caller-stack capture on.

The launchers support a separate Godot executable with `-GodotPath`. The formal
launcher uses PowerShell 7, with the installed Codex runtime as a fallback when
started from Windows PowerShell.

## Logs and hangs

- `failure.json`: first triggering action, budget, measurement, 1x clock state
  and cumulative call-count differences for that action.
- `actions.jsonl`: flushed action start/end markers and coverage exclusions.
- `function_calls.jsonl`: actual per-window counts and inspection rate.
- `function_stacks.jsonl`: per-second unique script caller chains and counts,
  with an explicitly partial final window on pause/stop. The current partial
  window is also embedded in `failure.json`. See
  [function call logging](function_call_logging.md) for grouping and limits.
- `summary.json`: outcomes, discovered controls and actions still pending.
- `engine.log`, `stdout.log`, `stderr.log`: this test process's output.
- `gdunit-report/`: JUnit XML and HTML reports for formal runs.
- `build_refresh.json`, `staffing_queries.json`, `call_stack_grouping.json`:
  guard measurements and the verified two-origin stack window.
- `read_path_characterization.json`, `read_path_costs.json`,
  `sight_candidate_parity.json`: read-slice state checks, inspection costs and
  compared observation fixture output.
- `ui-contracts/group-*/cases.jsonl`, `summary.json`: each native-input case,
  assertions, input receipts, wall timing, audit results and pending cases.
- `ui-contracts/group-*/failure-live.json`, `failure-NNNN.json`: immediate
  pause evidence and the completed failure record, including the current
  caller-stack window and a ledger snapshot when available.
- `ui-contracts/group-*/current_case.json`: action and pending plan flushed
  before input, including when the test cannot finish its coroutine.
- `ui-contracts/group-*/failure-NNNN.png`: rendered viewport at a failed case,
  captured after measurement; input receipts include target/viewport bounds.
- `ui-contracts/group-*/engine_errors.jsonl`: flushed structured errors and
  script backtraces, protected by a mutex even for errors on engine threads.
- `ui-contracts/group-*/function_stacks.jsonl`, `metadata.json`: completed and
  partial real-second windows plus instrumentation and timing limits.
  Real-second stack windows can overlap setup and adjacent actions; the action
  label identifies collection context. Per-action counter deltas use the
  separate measured boundaries and exclude subsequent audit work.
- `button_coverage.json`, `source_button_coverage.json` in the button group's
  folder: attempted runtime controls, remaining work and unmatched source
  declarations. Missing coverage fails; filters explicitly identify subsets.
- `launcher.json`: the owned test process ID, isolated project and run mode.

An unresponsive game thread cannot pause itself or flush new counters. The
external launcher monitors a heartbeat and stops only the process it launched
after the configured deadline, retaining the last flushed action and engine
output. It never terminates the human editor or unrelated applications.

Action/sample/stack JSONL streams use ordinary buffering during observation.
They flush before returning a failure, completed action, stopped run or scene
teardown. Heartbeats, current-case records and first-failure snapshots remain
immediate. A forced process kill can lose the buffered tail; this is a deliberate
limit, not permission to omit an observed outlier. Frequent forced disk flushes
previously created diagnostic stalls inside measured frames.

See [Godot's profiler](https://docs.godotengine.org/en/4.7/tutorials/scripting/debug/the_profiler.html)
for attributing remaining CPU costs, and the pinned GdUnit4 source for the
framework's assertions, scene runner and fail-fast command-line behavior.
Engine error interception follows the
[Logger reference](https://docs.godotengine.org/en/4.7/classes/class_logger.html);
button input expectations follow
[BaseButton signals](https://docs.godotengine.org/en/4.7/classes/class_basebutton.html#signals).
