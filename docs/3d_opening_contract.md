# 3D-01 opening and cameras

Owner: Developer C; Lead owns publication, remote imports/checks and integration. This is a separate `game/preview_3d/preview.tscn` entry. Normal F5 and `project.godot` stay unchanged.

## Contract before implementation

Reuse Main's actual empty-field GameSession and persistent management panels. Extract the rear manager's ground pose into that session; the old map and new character controller reference that one pose. The preview disables the old map's input and movement. The manager is not a ledger worker. The CharacterBody3D publishes its collision-resolved position, with no second worker simulation. Ground adapters map legacy `(x,y)` to scene `(x,height,y)`; terrain probe `(x,y,height)` is a different explicit convention. Ledger, routes, custody, fuel and clocks remain owned by existing services.

First/third-person cameras share that body. A separate RTS camera observes only BattlefieldPresentation's permitted markers, including stale contact metadata. View changes retain session, player, camera and selection. Management and modals own input before world controls; transitions/focus loss clear held input and release capture. A new world click captures without another action. Pause and speed use the existing session. UI drafts survive camera toggles.

Construction is **preview only**. Both the old map and every BaseDemo confirmation path are blocked in this opt-in entry. Ground picking occurs in physics, on changed aim/camera/draft/geometry. Existing construction preview supplies footprint, door and validity. No click spends or creates a site, including the numeric UI's Place button. Placement parity belongs to a later phase.

The art consultation is complete. Provisional flat-shaded Kenney CC0 candidates include Animated Characters, Furniture Kit (table), Nature Kit, Building Kit and Car Kit. Creator-page claims alone do not clear files: inspect the actual original archive license, model and rig before inclusion. Quaternius is not cleared because archive/version redistribution terms remain unresolved. Carry/retarget and first-person clipping need engineering work. Dawson has now accepted cohesive stylized 3D with readable detail and lower asset performance cost. The selected models remain provisional; no extra facility/cargo gameplay is accepted. A graybox alone cannot establish the assets-ready outcome.

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

Static source inventory/purpose review and current UI links are delivery checks, not engine or gameplay evidence. Preserve the existing regression button fixture unchanged; the coupled UI fixture check may therefore remain stale under the current no-regression policy. No local engine, gameplay, regression or performance run was made. The Lead-authored workflow imports exactly the declared existing PNGs and five new data assets in an isolated temporary project, using built-in ufbx; it excludes game scripts/plugins and retains actual import sidecars. No large/LFS assets were added.

Next owner: Lead publishes/reviews the frozen source, retains actual remote-generated `.uid`/`.import` sidecars, runs changed-script parsing and one bounded proposed current-change demonstration, and supplies first/third/RTS current-build captures. The ignored proposal `logs/3d-01-assets/opening_demo.gd` loads this actual entry once, observes the 2500/500/no-rear-workers opening, same-pose camera toggle, three collision-body movement steps, management pointer, preview no-spend/no-site and same-session RTS return. Rendered execution captures three views; headless execution skips images. Programmatic intent does not establish native mouse/keyboard/focus, visual quality, ordinary full-loop or FPS acceptance. Actual imported scale/orientation/clipping and screenshot readback remain required before claiming the 3D opening is ready.


## Concrete remote correction

At `b739067`, required run `42431861192` passed actual isolated asset import and changed-script engine parsing. Direct run `42431874777` failed. Its preserved log and third/first/RTS images were inspected: first person showed the normal 2500/500 paused table/materials, but third person had no manager and RTS had no terrain surface. Source inspection confirmed the selected idle FBX contained skeleton/animation only, no mesh. The corrected asset selection includes the original character model plus separate idle animation, explicitly binding matching bone tracks. Normalization now uses an external parent, so imported animation targets cannot overwrite scale/centering.

The terrain triangle order is reversed to the engine's [clockwise front-face convention](https://docs.godotengine.org/en/stable/classes/class_surfacetool.html), retaining normal culling rather than drawing both sides. The ignored demonstration still checks the initial 2500 opening, but compares actual balance immediately before/after the paused preview; its prior post-movement comparison ignored legitimate objective income. No production money or clock rule changed. Lead owns the fifth declared import dependency and repeat bounded rendered observation. These source corrections are not yet a successful visual/gameplay result; the failed evidence stays intact.


## Initial neutral pose correction

Required run `42432650743` and direct run `42432652286` passed at `4e9931c`; new actual images showed the manager and RTS ground. Third-person image readback nevertheless showed arms held in a T-pose. Inspection of the original idle FBX found two animation stacks: `Root|0.Targeting Pose` (0.033333 seconds) and `Root|Idle` (1.066667 seconds). The prior first-non-RESET selection could choose the targeting pose. Binding now selects the known pack's Idle clip explicitly and advances it by zero immediately to apply its initial pose before a paused opening renders. The same proposed brief demonstration records actual imported clip name, track count, animation time and left-arm pose/rest rotation before the first capture. A fresh rendered pose remains required; prior zero errors/mesh presence alone did not establish neutral-idle readiness.

Style direction is now accepted: cohesive stylized 3D, readable detail and lower asset performance cost. This is a direction, not a performance measurement or final approval of these provisional character/table/material models. First-person arms/body and the full unit roster remain deferred. The Designer owns the design-brief wording; this branch does not edit that section independently.


The same focused delivery corrects unhandled Escape ownership: a visible decision modal keeps GUI priority; otherwise one Escape closes management, cancels an uncommitted draft, or opens the existing world management menu, then marks the event handled and returns. It cannot cascade through multiple layers. Tab/text consumption stays unchanged. Native OS input acceptance remains unverified.


Permitted RTS rows are retained across the full 4x6km map, including the westmost 240m. The legacy rear-boundary visibility condition applies only to carriers, matching the existing carrier rendering distinction. Hidden rear-carrier proxies remain in cached permitted membership; actual motion updates show/hide them at the boundary without a full ledger or membership scan. Contacts continue to use reported positions, never true enemy poses. This is a presentation correction, not a new observation authority or scenario.

## Current rendered receipt

At `78fcb2a`, required run `42434202516` and one brief rendered direct run `42434204247` passed. Lead viewed all three actual fresh captures: the real manager now has relaxed arms, first-person table/materials render without a body clipping into view, and RTS terrain plus permitted inspection are visible. The imported clip is `Root|Idle` with 40 tracks and its live left-arm pose matches the Idle key. Management Escape, same-manager toggle/movement, preview no-spend and same-session return passed programmatic observations. Actual engine-generated sidecars are retained. See [scoped evidence](evidence/3d_opening.json) and its stored captures. Earlier failed and visually rejected runs remain recorded; they are not rewritten as passes.

This completes the bounded rendered observation, not native input, full-game, final asset coverage or 60 FPS acceptance. Default F5 remains the existing main. To inspect this separate preview, open `game/preview_3d/preview.tscn` and use Run Current Scene (F6); Tab manages, V switches perspective, and the HUD documents RTS controls. Building placement is deliberately preview only.
