# Runtime function call counts and caller stacks

Run the main game with F5 and open Godot's Output panel. Debug builds print a
`[Calls/s]` report for each completed real-time second, busiest functions first.
Each entry is a count of function entries, including calls that return early.
With `TRENCHO_CALL_STACKS=1`, debug runs also print a `[Call stacks/s]` section
for the same second. Each
distinct chain of script files and functions appears once, with its call count:

```text
[Call stacks/s] engine second 12:
  [game/file_1.gd::function_a -> game/file_2.gd::function_b -> game/file_2.gd::function_c] x2
  [game/file_3.gd::function_d -> game/file_2.gd::function_b -> game/file_2.gd::function_c] x1
```

These are illustrative names. Real traces start at the oldest available script
caller and finish at the instrumented function. Intermediate callers do not need
counter hooks. The logger removes its own `record()` frame. Identity includes
the ordered script paths and function names, including repeated recursive
frames; different source lines inside the same function do not split a group.
Counts reset for each real second, and groups print busiest first.

A scene-owned Godot Timer collects completed windows once per real second,
ignoring engine time scaling. It emits the structured report on the main thread
and passes immutable formatted text to one low-priority console writer. The
writer sleeps on a semaphore when idle and holds its queue mutex only during
handoff, never during console I/O. Collection timestamps, report order and counts
retain their original monotonic seconds. The logger joins the writer and drains
remaining text on shutdown. A blocked console can accumulate pending text or
delay shutdown; no reports are discarded. Thread-creation failure retains text
for shutdown and leaves structured reports available during play.

This replaces the earlier 1 ms cooperative main-thread drain: a recorded native
console write took 28.879 ms, which cannot be preempted by checking a loop budget.
The worker touches no scene, game state, counters or renderer. The implementation
follows Godot's [thread-safe API guidance](https://docs.godotengine.org/en/stable/tutorials/performance/thread_safe_apis.html)
and [thread cleanup contract](https://docs.godotengine.org/en/stable/classes/class_thread.html).

```text
[Calls/s] engine second 12 [12, 13):
      60  main/game_session.gd::_physics_process
      60  rear_base/base_simulation.gd::tick_live
       4  rear_base/base_demo.gd::_refresh
```

This example illustrates the format; it is not a measured game result. Names
include script paths so similarly named methods remain distinct. Reports also
go to Godot's normal game log. Counts use `Time.get_ticks_msec()`, independently
of pause, game speed, rendering rate and the simulation clock. If the main thread
stalls, completed buckets are reported when it resumes; calls from different
seconds are not merged into an inflated single-second count.

## Scope

45 named first-party counter IDs are instrumented outside retained tests across these areas:

- Main navigation and shell clock display.
- Session physics callback and command notifications.
- Rear and battlefield refresh requests, refreshes, list updates and drawing.
- Live simulation pumping, command handling and purchasing/workforce/full views.
- Shared scheduler advancement, settling and snapshots.
- Identity snapshots and entity inspection.
- Narrow construction reads and rear-map markers.
- Living-person/duty/qualification and HQ eligibility checks, held weapons and
  ammunition counts, observation candidates and nearby wounded people.

The counter does not automatically intercept every function, anonymous callback,
engine/native method or background thread. Hooks currently run on the main
thread. Captures are the current synchronous GDScript stack: a deferred call,
timer, engine callback or resumed `await` can start a new stack. They do not
reconstruct an earlier asynchronous origin or capture function arguments/local
variables. Calls with no available stack remain in the function totals and are
reported as `unavailable_stack_calls`; the logger does not invent their origin.

Function entry counts measure frequency. Capturing every instrumented
stack adds CPU and allocation overhead, especially in a hot function. There is
no sampling or truncation: every captured call contributes to its group. Use
Godot's profiler for timing, and compare a counters-only run before attributing
a performance regression to gameplay.

Explicit scopes also record monotonic elapsed wall time: the session's live
tick, owner-specific planning/admission chunks, due squad decisions, live rear
advancement, settlement, UI refresh/drawing and diagnostic output. Their
`[Scope wall time/us]` line and `durations_usec`
JSON field contain `calls`, `total` and `maximum` microseconds per scope.
These times include nested work, diagnostic overhead and any OS preemption;
they are not exclusive CPU times. Do not add parent and child totals. A scope
belongs to the real second in which it finishes, even if it began earlier.
Only the named call sites are timed; this is not automatic timing of every
invocation of those functions. Disabled logging skips the added clock reads.

For targeted diagnosis, `TRENCHO_PROFILE_FRAMES=1` also retains completed
scope totals for the current and previous `Engine.get_process_frames()` values.
The UI probe writes them to `failure-live.json` as `frame_scopes`. This bounded
opt-in history helps distinguish previous drawing from current physics within
a probe interval. Nested scopes remain inclusive; engine rendering and OS
scheduling outside instrumented calls remain unmeasured by these scopes.
The failure also saves informational engine process/physics monitors. Their
update cadence differs from the failing interval, so the monotonic 16.67 ms
gate remains authoritative. See the [Performance reference](https://docs.godotengine.org/en/stable/classes/class_performance.html).

## Add another function

In its script, add the preload once:

```gdscript
const CallLog = preload("res://game/diagnostics/function_call_log.gd")
```

Then add a record at the start of the function:

```gdscript
func do_something() -> void:
	CallLog.record(&"feature/my_script.gd::do_something")
	# Existing function body follows.
```

The logger lives under the runtime GameSession node. It does not scan files,
register an editor plugin, run while opening the editor, or advance game time.
Logging defaults to `OS.is_debug_build()`; release builds skip the hooks' counter
updates. To silence it for a debugging run, set the static `enabled` initializer
in `game/diagnostics/function_call_log.gd` to `false` and restart the game.

Ordinary debug play keeps counters on and stack capture off. Enable exact
caller-chain capture with `TRENCHO_CALL_STACKS=1` before launching Godot; use
`TRENCHO_CALL_STACKS=0` for timing acceptance. Capturing a stack at every
instrumented call is an explicit diagnostic mode with additional cost.
Both performance launchers also accept `-WithoutCallStacks`. They enable stacks
by default and record that setting in the run's `metadata.json`.

## Files from performance runs

The existing Output/engine log includes the readable chains. The performance
suite also flushes `function_stacks.jsonl` under its `logs/` run folder. Each
entry contains a `window` with:

- `second`: monotonic engine second, corresponding to `[second, second + 1)`.
- `complete`: `true` for a completed second; `false` for an unfinished window
  saved when the suite pauses or stops.
- `counts`: the existing per-function totals for that window.
- `stacks`: groups containing `function_id`, ordered `chain` and `count`.
- `stack_capture_disabled_calls` and `unavailable_stack_calls`: entries without
  a captured stack, so missing traces are distinguishable from zero calls.
- `durations_usec`: the explicit wall-time scope aggregates described above,
  available with or without stack capture.

`action_at_report` labels the action active when the report was written. A real
second can overlap two actions, so it is not precise action attribution. Partial
windows are snapshots and may overlap a later completed window if you continue
the interactive suite; do not add them to completed-window totals. The failure
file also embeds the current partial window as `function_call_second`.

## Verification

A brief Godot 4.7.2 headless check made five explicit records and called the
instrumented `identity_ledger.inspect_entity` three times. After crossing a real
second boundary, the counter returned exactly five and three. A second window
printed two `direct.output` calls through the runtime reporter. The process
exited with code 0 and no stderr.

The GdUnit4 guards now also exercise real cross-file A → B → C and D → B → C
calls. Two A calls from different lines produce one group with count two; the
D group has count one. The test crosses the second boundary and checks that the
completed report preserves those groups and the next window starts empty for
that target. A second test checks counters-only mode. The four guards (these
two plus the Build/map and staffing checks) passed on Godot 4.7.2.
The verified fixture window is saved in
`logs/gdunit4-performance-2026-11-02T18-23-37-32536/call_stack_grouping.json`.

The duration guard records 10, 20 and 5 microseconds and rejects a negative
sample. It verifies three calls, total 35, maximum 20, completed-window
preservation and a fresh next window without creating function entry counts.
It passed with the other nine focused guards in the run at
`logs/gdunit4-performance-2026-11-02T23-54-24-43416/`. That run's live-menu case
still failed the 100 ms frame budget; logging verification is not a passing
whole-game performance result.

A bounded 1x Build run also verified the runtime output and JSONL connection:
four completed seconds contained 46–72 distinct chains each, with every
function entry accounted for and no unavailable stacks. A counters-only run
kept totals with no stack groups. A deliberately low inspection budget then
verified that the failure file contains a nonempty partial stack window before
the test exits. These are focused logging checks, not a completed menu sweep.

The implementation follows
[Godot 4.7's `get_stack()` reference](https://docs.godotengine.org/en/4.7/classes/class_@gdscript.html#class-gdscript-method-get-stack).
Godot supplies newest-first script frames; the logger reverses them for the
caller-to-target display. Backtraces are normally available in editor/debug
builds. Release logging remains disabled by default.

See [Godot's profiler documentation](https://docs.godotengine.org/en/latest/tutorials/scripting/debug/the_profiler.html)
for measuring execution duration separately from call counts.
