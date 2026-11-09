# Play the 3D opening

[Construction follow-up](construction_delivery_completion.md): builders can fetch
actual materials for their own starved site. The site menu shows actual delivery,
carry and pickup blockers. Startup prepares construction/truck rendering behind
a loading cover, then begins normal1x play. Completion smoke emerges1.5s,
scissors cut2s, then tape falls and pylons clear. Exact reported no-pickup cause,
manual stage acceptance and60FPS remain open.

Workers now default to [Hauling](hauling_priorities.md). Open **Workers / Jobs â†’ Hauling**, drag the six-dot handles (or use Move up/down), then **Confirm hauling priorities**. Top is highest for the next feasible task; existing carries finish safely. Four free workers can each claim25kg from a100kg+ truck.

The [character integration](character_animation.md) replaces provisional worker
and soldier visuals with the Artist's models/clips. Four unloaders have distinct
actual work positions and short numbered labels. Order100kg to give all four a
25kg carry; a smaller order can correctly leave some workers idle.

Open this project's root `project.godot` in Godot 4.7.2 and press **F5 / Run
Project**. The configured entry remains `game/main/main.tscn`; it instances the
existing 3D scene. F6 on that main scene also opens 3D. This is the same game and
shared session, with no separate game project or experimental MCP plugin.

The normal opening runs at **1x**. Press **Tab** to use Pause / 1x / 2x, then
close management with Tab. Click the world to capture the pointer. **WASD** moves, **V** switches first
and third person, **E** interacts with the Supply Table or a site under the
crosshair. Tab opens management and releases the pointer.

## Stage 1: people and raw materials â€” awaiting your playtest

At the Supply Table, press E, choose a small raw-material order and workers, then
confirm once. At 1x, watch the actual trucks arrive and unload at the prebuilt
apron, where four workers already exist. Check that the order is charged once,
the goods/people reach the base, and ordering becomes available after the final
handover. Share whether the interaction and arrival make sense before we count
this stage as accepted.

## Stage 2: place and manage buildings â€” awaiting your playtest

Choose a building in management. This opens the overhead grid; move the pointer
and click to select a location, **R** rotates, and **Confirm placement** commits
the selected site. **Esc / right-click** cancels an uncommitted draft. Return to
the character view, aim at the new site and press E to set its builders with
the existing explicit command. Watch the cyan hologram fill from the ground as real builders use arriving
materials. Shortages stop work; later material resumes it. On completion, watch
four scissors cut the tape and the pylons disappear. Try cancelling a second
unfinished site: the warning explains actual used-material loss while builders
continue. Cancelling an uncommitted draft still leaves the committed site intact. This checkpoint does not claim a complete
staffed production/replenishment loop.

The source and earlier scoped convoy/grid check are implementation evidence.
The current startup observation checks normal configured launch only. Neither
establishes native input comfort, a complete loop, performance or 60 FPS. Stages
1/2 remain pending Dawson's acceptance. His feedback precedes the dependent
factory stage; independent development need not stop.

The [precode plan](feature_plans/default_3d_entry_v1.json) and
[integration diagram](diagrams/default_3d_entry.mmd) record ownership and limits.
The [configured-entry receipt](evidence/default_3d_entry/startup_result.json)
passed at source `db61a78`; its [actual opening image](evidence/default_3d_entry/opening.png)
was inspected. Both required run42649450688 and focused run42649451270 passed.
The required job had no changed production scripts; the focused run loaded the
real main/3D dependency graph. No old scenario was replayed.
The root scene reuses Godot's [scene instancing](https://docs.godotengine.org/en/stable/getting_started/step_by_step/instancing.html)
and [TSCN resource format](https://docs.godotengine.org/en/latest/engine_details/file_formats/tscn.html)
rather than creating another gameplay controller or clock.
