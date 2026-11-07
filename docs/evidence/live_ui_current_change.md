# Live session and interface update change

This records the first local UI refactor. The subsequent integration of build
`5426583` changes the session to the build's fixed engine callback and replaces
the old panel implementation. See [default playable build](default_playable_build.md)
for the current implementation and verification status.

## Result

`game/main/game_session.gd` owns the live simulation and its `_process(delta)`.
Main supplies that session to both screens. Running the rear-base scene alone
creates a session child. Pause disables session processing; speed and reset
commands go through the session. Reset notifies both views and reconnects the new
simulation's state signal.

The rear simulation emits `state_changed` after immediate state transitions
settle and after advancing across scheduled boundaries. UI commands also notify
the session, including while paused. Views coalesce those notifications into a
deferred update and skip updates while hidden. Showing a view or selecting a tab
requests its current state.

The live screens no longer contain 0.2-second refresh loops. The rear screen
updates discrete lists from change notifications and refreshes continuous
progress only in the open panel. Clock and visible map updates follow actual
simulation advancement. Existing list rows update in place when IDs match,
preserving selection and scrolling.

UI reads use narrow entity, people, storage, job, order and balance methods.
Neither live screen calls the full simulation snapshot, which also runs audits.
The original diagnostic snapshot methods remain available. The shared deadline
scheduler and its gameplay ordering are retained.

## Verification

- Parsed the eight changed/new production GDScript files with gdtoolkit 4.5.0.
  All parsed successfully. This checks grammar, not Godot types or runtime APIs.
- `git diff --check` passed.
- Reviewed initialization while paused, deferred/hidden updates, session reset
  signal connections, panel data dependencies and map entity filters in source.
- Prepared one ignored, brief Godot demonstration for the changed behavior:
  paused initialization/purchase, list selection, panel activation, clock speed
  and pause, hidden view updates, session replacement and standalone base scene.
  It has not run. No regression suites or local Godot processes ran.
- Automatic approval review rejected creating a separate verification branch and
  dispatching the existing GitHub workflow because source upload and remote
  changes were not explicitly authorized. No upload or remote change occurred.

Remaining: Godot parsing/type checks and the direct demonstration on GitHub,
plus human confirmation of layout and responsiveness. No performance improvement
has been measured.

## Godot references

- Signals: https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
- Processing: https://docs.godotengine.org/en/stable/tutorials/scripting/idle_and_physics_processing.html
- Custom drawing: https://docs.godotengine.org/en/stable/classes/class_canvasitem.html
- ItemList: https://docs.godotengine.org/en/stable/classes/class_itemlist.html
