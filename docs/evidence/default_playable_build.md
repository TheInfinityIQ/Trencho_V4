# Default playable build integration

The default `game/main/main.tscn` now presents the command shell and empty-field
opening from local build `TrenchoDemo-5426583`, revision
`542658309c15f80759906a5ea09076def2502515`. Its `START_HERE.txt` and revision
identify the intended UI and starting package. The scene path was already the
default; the checkout contained older code at that path.

The build's production source and dependencies were integrated together: 65
files including UID sidecars, excluding test folders. Existing test files,
unrelated local deletions, diagram addon and project display settings remain.
Pre-integration copies of edited files are in the ignored
`.tools/playable-build-integration-backup/` directory.

## Opening

Press F5 from this project's Godot editor. The command rail contains Rear base,
Build, Workers / Jobs, Supplies and Production. The game starts paused on the
empty rear field, with 2500 requisition, 500 Building Materials at the Supply
Table, no hired rear workers, and the blue player at `(16, 90)` metres. WASD
moves the player while time runs. The authored battlefield and rear share one
session. The shell's New game command retains its confirmation dialog.

## Integration with the local session refactor

`game/main/game_session.gd` still owns the clock independently of the screens.
It now calls the build's `tick_live()` from `_physics_process`, preserving its
bounded route preparation and wall-clock handling. Route preparation may run
while paused; simulation time does not advance while paused.

Session state and advancement notifications update the shell and visible views.
The screens skip deferred updates while hidden, and the 0.2-second polling loops
from the build were removed. Existing list rows still update in place.

The newer Supplies and Workers panels use the build's narrow purchasing and
workforce queries. Other management panels retain the build's non-diagnostic
management snapshot path; this integration does not claim that every panel now
reads only its own data. Audits remain opt-in through diagnostics.

## Verification

- gdtoolkit 4.5.0 parsed all 47 changed/new production GDScript files.
- All 126 literal `preload`/`load` resource references in those scripts resolve.
- New scripts have UID sidecars; no merge conflict markers remain.
- `git diff --check` passed.
- Source tracing confirms the unchanged default scene loads the command shell
  and calls `start_empty_field_session`, and that replacement sessions rebind
  the shared session owner and battlefield.

Godot type checking and runtime behavior have not been verified. No local engine
or regression suite ran. The earlier automatic approval rejection of source
upload/remote CI still applies; no upload was retried. A brief ignored direct
demonstration is prepared for this opening and navigation change. Existing EXE
and PCK downloads have not been rebuilt.
