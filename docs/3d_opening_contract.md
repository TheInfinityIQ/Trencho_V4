# 3D-01 opening and cameras

Owner: Developer C; Lead owns publication, remote imports/checks and integration. This is a separate `game/preview_3d/preview.tscn` entry. Normal F5 and `project.godot` stay unchanged.

## Contract before implementation

Reuse Main's actual empty-field GameSession and persistent management panels. Extract the rear manager's ground pose into that session; the old map and new character controller reference that one pose. The preview disables the old map's input and movement. The manager is not a ledger worker. The CharacterBody3D publishes its collision-resolved position, with no second worker simulation. Ground adapters map legacy `(x,y)` to scene `(x,height,y)`; terrain probe `(x,y,height)` is a different explicit convention. Ledger, routes, custody, fuel and clocks remain owned by existing services.

First/third-person cameras share that body. A separate RTS camera observes only BattlefieldPresentation's permitted markers, including stale contact metadata. View changes retain session, player, camera and selection. Management and modals own input before world controls; transitions/focus loss clear held input and release capture. A new world click captures without another action. Pause and speed use the existing session. UI drafts survive camera toggles.

Construction is **preview only**. Both the old map and every BaseDemo confirmation path are blocked in this opt-in entry. Ground picking occurs in physics, on changed aim/camera/draft/geometry. Existing construction preview supplies footprint, door and validity. No click spends or creates a site, including the numeric UI's Place button. Placement parity belongs to a later phase.

The art consultation is complete. Provisional flat-shaded Kenney CC0 candidates include Animated Characters, Furniture Kit (table), Nature Kit, Building Kit and Car Kit. Creator-page claims alone do not clear files: inspect the actual original archive license, model and rig before inclusion. Quaternius is not cleared because archive/version redistribution terms remain unresolved. Carry/retarget and first-person clipping need engineering work. No final art style or extra facility/cargo gameplay is accepted. A graybox alone cannot establish the assets-ready outcome.

## Acceptance and limits

- Separate entry opens the actual paused 2500 requisition / 500 M11 / Supply Table session, without free workers, facilities or vehicles.
- A visible provisional 3D manager, ground, table and material representation; collision-resolved ground movement and first/third toggle preserve the same pose.
- Management cursor, modal/focus priority and speed semantics; an uncommitted footprint/door preview cannot spend/build.
- Independent RTS pan/zoom and permitted inspection; returning preserves state.
- Lead runs one bounded current-change demonstration and captures current-build first/third/RTS views remotely, with isolated imports agreed first. Source parsing is not gameplay or visual acceptance. No local engine, regression suite, broad scenario or FPS claim.

Diagram: [ownership and input](diagrams/3d_opening.mmd). Full spatial migration, placement commitment, worker/vehicle models and full terrain rendering remain later phases.
