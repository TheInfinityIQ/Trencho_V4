# Living system map

The user requires `docs/system_map.json` to stay current whenever project code
changes. The maintenance requirement applies to workflow tools too.

- Before editing, query the relevant entries with
  `python tools/system_map.py --query PATH_OR_FUNCTION`. Read the actual source
  before changing behavior. A map or call count does not establish test coverage.
- After adding, editing, moving or deleting project files, run
  `python tools/system_map.py --update`. The Windows launcher is
  `Update System Map.cmd`. Do not hide first-party source in ignored directories.
- Review every changed/new function's purpose against its implementation. Use
  `--purpose FUNCTION_ID "Purpose"`, or `--review-file PATH` with a JSON object
  mapping exact function IDs to reviewed purpose text. These commands record the
  current implementation hash. Preserve useful existing descriptions.
- Run `python tools/system_map.py --check` before reporting completion. It must
  pass with no pending purpose reviews. Do not reinitialize the map, accept stale
  hashes, disable the check or mark unexamined prose as reviewed to make it pass.
- Keep graph uncertainty explicit: candidate targets are not proven calls,
  static resource reachability is not execution, and initial implementation-
  derived descriptions are distinguished from reviewed descriptions.
- The inventory includes retained tests, fixtures, demos, scenes, tools and
  project configuration. Its documented exclusions are generated caches/logs,
  exports, Git internals, secrets and ignored third-party downloads. No editor
  plugin is required for map maintenance.
- Consult `docs/system_overhaul_plan.json` and `docs/overhaul_inventory.json`
  when changing an affected game system. They distinguish source observations,
  historical measurements, proposed migrations and planned tests. Recheck source
  anchors before implementing a slice; a proposed phase is not an instruction to
  expand the user's requested scope or evidence that its tests have passed.
- Keep the clickable UI flowchart current too. `Update System Map.cmd` updates
  the map, regenerates `docs/ui_function_map.html`, then fingerprints the result.
  For direct Python use, run `tools/system_map.py --update`,
  `tools/ui_function_map.py --update`, then `tools/system_map.py --update` again.
  Check both tools with `--check`; the diagram must not retain stale source
  lines. Review any hand-maintained cross-file workflow anchors when their
  underlying UI or signal logic changes. Static branches are not runtime traces.
  The same updater regenerates
  `game/diagnostics/tests/gdunit/fixtures/ui_button_contracts.json`; keep this
  source-button inventory current so new declared controls enter the acceptance
  coverage gate.

# Objective workflow

For a bounded objective with durable progress, follow `docs/agent_workflow.md`.
The manual controller is the sole retry owner; do not combine it with native
goal continuation or a scheduled retry loop. Freeze task-specific acceptance
before editing, preserve unrelated changes, and report actual checks and limits.

# Test desktop behavior

Routine tests must run headless, or minimized only when they cannot take desktop
focus or move the OS cursor. The launchers default to headless. Use explicit
`-Foreground` only when needed to investigate a user-reported issue, bug or
regression. Record omitted native-input checks; a background pass does not
certify visible-window rendering or 60 FPS. Keep normal F5 behavior unchanged.

# Current delivery priorities and team

Dawson paused polishing, optimization and benchmark-driven work on 5 November
2026 to prioritize gameplay features and the connected demo. Keep known defects
and performance results visible; preserve the eventual 60 FPS target. Use brief
direct checks of changed behavior when needed, without routine full-suite runs
or new coverage infrastructure. Fix defects that block the current gameplay
increment or corrupt state. Required living-map maintenance still applies.

The current developer owns integration. Consult the designated Game Designer
for gameplay, UI/UX developer for interaction/menus and 2D Artist for sourced
assets. Current recipients and ownership are in `docs/team_integration_state.json`;
historical team assignments do not reactivate automatically. Preserve asset
origin, license, attribution and modification records at integration.

Keep authorized changes pushed to the dedicated review branch. Give reviewers
the exact branch and commit; an uncommitted local state is not a published
build. Do not force-push, discard unrelated work or equate publication with
gameplay acceptance.

Use a task briefing in progress and completion messages: Objective, Outcome and
Next task. Say Completed only for the specific result actually verified.

# Design before implementation

Before building or materially changing a system, save its planned flow diagram
and ownership/event contract under `docs/diagrams/`. Identify authoritative
state, commands, signals, timed work, cancellation, replacement and failure
paths. Read `docs/engineering_lessons.json` and explain applicable safeguards.
Update the diagram when the implementation changes its contract. A diagram is
a design record, not evidence of execution. Keep implementation increments
bounded and the remaining gameplay backlog explicit; do not call the whole
game finished after completing one slice.
