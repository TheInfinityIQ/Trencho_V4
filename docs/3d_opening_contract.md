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

## Source delivery and next owner

The opt-in entry subclasses Main, retains its actual normal opening factory and leaves both default entry files untouched. Tab opens persistent management even from a focused text field. Placement uses a visible pointer and suppresses walking/look; its continuous hint is explicitly **provisional footprint/door validity**, using `placement_hint`, without expensive route validation. The existing explicit Preview legal site action can request full validation. Every numeric/world site confirmation is blocked by the opt-in guard. Camera and area changes clear held input without changing simulation speed or committing a draft.

The manager's session pose is the single ground authority; the legacy map binds to it in normal F5. In the preview that map is hidden and its processing/key input disabled. One CharacterBody3D uses static rear bounds, table and committed construction footprints, publishing only resolved position. Imported visual bounds normalize to 1.8m manager, 1m table and 0.65m representative bundles. Raw models/licenses and exact hashes are in [asset inspection](3d_opening_assets.json). Idle animation is provisional; walking/carry animation is unfinished.

RTS membership comes from the permitted presentation policy on committed changes/view entry. Subsequent elapsed-time updates traverse only those cached friendly holder chains or observed contact reports; no true enemy pose is read. Selection reuses the existing full inspection text, including supply stages. Selected detail updates on commits/whole simulation seconds, not pointer hover. Terrain is a bounded mesh split at authored region edges with explicit scene-height conversion; this slice does not migrate dynamic field structures, all terrain overlays or ledger spatial types.

Static source inventory/purpose review and current UI links are delivery checks, not engine or gameplay evidence. Preserve the existing regression button fixture unchanged; the coupled UI fixture check may therefore remain stale under the current no-regression policy. No local engine, gameplay, regression or performance run was made. The Lead-authored workflow imports exactly the declared existing PNGs and four new data assets in an isolated temporary project, using built-in ufbx; it excludes game scripts/plugins and retains actual import sidecars. No large/LFS assets were added.

Next owner: Lead publishes/reviews the frozen source, retains actual remote-generated `.uid`/`.import` sidecars, runs changed-script parsing and one bounded proposed current-change demonstration, and supplies first/third/RTS current-build captures. The ignored proposal `logs/3d-01-assets/opening_demo.gd` loads this actual entry once, observes the 2500/500/no-rear-workers opening, same-pose camera toggle, three collision-body movement steps, management pointer, preview no-spend/no-site and same-session RTS return. Rendered execution captures three views; headless execution skips images. Programmatic intent does not establish native mouse/keyboard/focus, visual quality, ordinary full-loop or FPS acceptance. Actual imported scale/orientation/clipping and screenshot readback remain required before claiming the 3D opening is ready.
