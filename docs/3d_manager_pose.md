# 3D-02A: canonical manager position

Status: accepted pre-code contract. Developer C owns this bounded implementation; Lead owns publication, remote check, review and integration. No ledger migration or new gameplay.

Baseline: merged PR120 at 387e574646850b6905c932db968924e2c1f8caa9. Dedicated branch codex/3d-manager-pose in the existing assigned worktree; ignored logs preserved.

## Intended result

GameSession owns one manager pose whose canonical position is a Vector3 in metres: scene X/Z ground, Y up. Existing ground reads derive Vector2(position.x, position.z). A collision-resolved 3D publish retains the complete position, including Y. Perspective or observation changes never reset it. This changes manager spatial ownership only; the manager stays a rear-only player and never enters worker, cargo, holder or military accounting.

## Current boundary and proposed change

Current manager_pose.gd stores ground_position: Vector2 and heading, reconstructs scene_position(ground_height), and discards Y in publish_resolved. BaseMap.character_position proxies that mutable ground field. WorldPresenter initializes the body from scene_position and publishes move_and_slide results. GameSession.replace_simulation resets the pose, and BaseMap.enable_character also writes the opening position.

Propose a private canonical Vector3 with a read-only scene-position accessor, a derived read-only ground accessor, the existing heading, and explicit publishing methods. Do not keep an independently writable Vector2 cache. The legacy map's public character_position property may remain as a compatibility adapter, but its setter must route through the one canonical pose with a declared support height; it must not own state.

| Operation | Owner / rule |
| --- | --- |
| Initial/new-session spawn | GameSession initializes position once at legacy (16,90), authoritative support height from the new simulation, heading PI/2. Emit the replacement only after pose and model agree. |
| 3D movement | Active CharacterBody3D resolves collisions and publishes its full foot position and yaw once. Its transform is controller working state, not a second persistent pose. |
| 2D movement | Existing BaseMap axis/footprint checks resolve the candidate as before. On an accepted ground write, its adapter supplies TerrainWorld.ground(candidate) from the current simulation and publishes (x,height,y). No new slope, jump, vertical or reach rule. |
| 2D read/draw | Always Vector2(canonical.x,canonical.z), with no copy stored independently. |
| Camera toggle / RTS / management | Read or retain state only. Never call reset or write player height from camera position. |
| Entry/rebind | Construct the body from the exact canonical Vector3, including Y. Retire the optional scene_position(height) reconstruction argument so callers cannot silently replace stored height. |
| Enable/hide presentation | Does not reset an existing manager. Remove the duplicate reset from BaseMap.enable_character; actual new-session creation owns spawn. Preserve explicit standalone spawn setup where a source caller actually requires it. |

## Invariants

1. Position is the manager's world-space ground-support/foot origin. Eye offset, SpringArm, model normalizer, skin/animation and visual sockets never enter canonical position.
2. Legacy ground (u,v) converts to scene (u,h,v); scene ground projects to (x,z). Terrain probes use the different historical (u,v,h) convention and are NOT changed by this increment.
3. Body-resolved Y is retained exactly by the 3D publish; do not replace it with a terrain sample after collision resolution. A legacy 2D writer deliberately supplies authoritative ground height because that mode has no independent vertical simulation. Do not preserve stale height while changing ground coordinates or default height to zero merely because the reader is 2D.
4. Only the active input/controller mode publishes. The hidden legacy map remains disabled in the preview. No second physics body, copied mover, automatic world catch-up, new autoload or parallel authority.
5. Reject non-finite candidate position/yaw at the pose boundary without partial mutation. Preserve current rear bounds, collision ownership, pause/speed, focus/held-input priority and draft behavior.
6. Reset happens only for an actual session replacement or explicit standalone initialization, not enabling a camera/view. Returning from RTS preserves all three coordinates and heading.
7. Ledger positions, holder offsets, workers, routes, fuel distance, accepted paths, contacts, combat/probe geometry, inventories and clocks stay unchanged.
8. Do not turn a 2D compatibility setter into a per-frame terrain/inventory scan. Sample height only for an actual accepted legacy position write or initialization. Current accepted opening rear is flat; dynamic terrain/support migration remains a later increment.

## Narrow file scope

- game/preview_3d/manager_pose.gd: canonical Vector3, projection and explicit full/ground publishing, finite validation.
- game/main/game_session.gd: initialize/reset from the new simulation's actual support height before notification.
- game/rear_base/base_map.gd: derive legacy property reads, route accepted writes through support-height adapter, remove presentation-enable reset.
- game/rear_base/base_demo.gd only if its existing standalone/session-bind call sites require an explicit initialization handoff; preserve normal factory and guarded preview commands.
- game/preview_3d/world_presenter.gd: initialize body from canonical position; retain the same collision publish path.
- game/preview_3d/preview.gd: the two concrete body-yaw callers publish/read world-space yaw rather than parent-local rotation.
- Current ownership diagram, reviewed purposes and clickable links for affected functions. No new asset/import/workflow dependency expected.

## Acceptance and verification limit

A full collision-resolved Vector3 publish retains Y and yaw, derived legacy reads use X/Z, an actual accepted legacy write uses the declared support height, new-session spawn is consistent, and view/camera/enable changes preserve the pose. Existing 2D F5 and explicit 3D entry remain separate. No gameplay change follows from storing height.

During the assigned implementation: one ignored brief current-change demonstration can observe these changed owner boundaries and the existing camera/return path. Declare any isolated nonzero-height API sample as an API demonstration, not evidence of sloped-terrain gameplay or a diagnostic teleport in the normal opening. Lead chooses the exact bounded remote execution; no regression suite, broad scenario, local engine, animation campaign, FPS claim or new run now.

## Accepted Lead decisions

- Accepted explicit legacy setter policy: accepted planar movement publishes current authoritative support height, while 3D publishes exact collision height.
- Migrate only concrete callers relying on enable_character resetting as an explicit initialization caller rather than silently retaining duplicate resets. Resolve concrete callers during implementation, not a new audit campaign.
- Scene/ground/probe axis converters remain separate; this increment does not begin the global ledger rewrite.


## Godot transform boundary and rationale

Consulted the actual relevant official documentation before code:

- [Node3D](https://docs.godotengine.org/en/stable/classes/class_node3d.html): position is parent-relative; global_position/global_transform are world-relative and require tree membership. The canonical manager foot position is world-relative. Initialize the body after adding it to the tree, using global_position; publish global_position and world yaw. Parent/visual transforms must not be accidentally recorded as canonical world coordinates.
- [CharacterBody3D](https://docs.godotengine.org/en/stable/classes/class_characterbody3d.html): move_and_slide resolves scripted velocity in the physics step and can alter velocity after collisions. Retain that existing resolver and publish its resulting full world position; do not flatten Y or integrate velocity in a second owner.
- [Vector3](https://docs.godotengine.org/en/stable/classes/class_vector3.html): three floating components and is_finite for component validation. Store one Vector3, derive legacy Vector2 by X/Z and reject non-finite publication without partial mutation. This does not require a double-precision build or a generalized spatial framework.

These are project ownership decisions using those APIs, not claims that Godot defines the game's accounting or terrain rules. Initial session and replacement sample actual support height before notification. A legacy setter without a bound simulation cannot invent a support height and therefore does not publish; normal BaseDemo binds its actual session first. No current production caller requires enable_character to reset after session initialization.

Diagram: [manager ownership](diagrams/3d_manager_pose.mmd).


## Source delivery

The implemented pose stores one private Vector3 and derives its legacy ground read through `ground_position()`. `scene_position()` returns the stored position and no longer accepts a replacement height. Full and ground publishing return success only for finite values; direct heading updates likewise retain the prior yaw when non-finite. Session initial/replacement binding samples actual support before notifying consumers. The sole production `enable_character` caller follows session replacement, so removing its duplicate spawn write requires no BaseDemo behavior fork.

The legacy property setter uses the bound simulation's terrain height for an actual write, with no per-frame height polling and no write when a simulation/finite candidate is unavailable. Existing zero-axis movement steps are skipped. Body initialization and publication use global position after tree attachment; movement direction uses an orthonormal world basis and camera look retains world yaw. Foot/eye/normalizer offsets stay separate. No ledger, route, asset, import, gameplay, pause or default-entry change.

Proposed remote demonstration: ignored `logs/3d-02-manager-pose/direct_demo.gd`, one brief changed-owner process. It uses one actual session/factory, a clearly authored nonzero support sample (not normal-opening acceptance), observes height initialization before notification, full-position and derived ground publication, legacy support-aware movement, no reset on presentation enable, then one actual body and three physics steps publishing world position. A single translated parent distinguishes canonical world coordinates from parent-local coordinates; this is the actual conversion boundary, not a parent-transform validation campaign. No new rendered capture is proposed. Finite rejection is source-reviewed, not exercised by failure injection. Native input, new terrain gameplay, normal full-loop and FPS acceptance remain unverified.
