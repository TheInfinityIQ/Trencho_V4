# Characters in the playable 3D game

The normal main scene uses the 3D Artist's faceted worker and soldier exports.
The Lead integrates the models and authored clips in Godot; the Artist owns
their meshes, rigs, weights, bone animations and source/export checks. The
[asset manifest](../game/characters/asset_provenance.json) retains exact files,
hashes, clip timings, attachment matrices, provenance and the actual art checks.
Editable Blender sources are LFS tracked under `game/characters/source/`, which
Godot ignores. Opening the project does not need to launch Blender or a plugin.
The existing player manager remains a separate identity and model.

| Character | Authored action | Actual state that selects it |
| --- | --- | --- |
| Worker | idle / walk | Existing rear idle/reporting/approach activity |
| Worker | carry_idle / carry_walk | Actual carried freight and current motion |
| Worker | pickup / unload | Existing two-second Receiving/hauling handling phase |
| Worker | construct | Actual builder duty at a Building/Dismantling site |
| Soldier | idle / walk / run | Permitted person's actual infantry motion |
| Soldier | fire | Actual loaded-round release from a person-held weapon |
| Soldier | reload | Existing Combat reload start, duration and completion |
| Soldier | wounded_idle / death | Actual casualty/assignment facts |

The models retain one compatible 33-bone skeleton each. Clips animate local
bones, including legitimate Hips motion; they do not translate the unit through
the world. The existing services still own position, cargo claims/custody,
construction progress, ammunition and damage. There is no new game clock,
autoload or animation-owned work completion.

The separate 0.35m carried box uses the exported RightHand attachment matrix.
A claimed source parcel becomes visible at the pickup clip's one-second hand
contact; actual custody still changes only at the two-second service boundary.
Drop keeps the carried parcel until actual deposit. The rifle is a separate
Artist prop using its own hand matrix; it is visible only when the permitted
person actually holds a relevant weapon and is not wounded/dead/aboard.
The original six soldier clips are preserved in the reload increment.

`AnimationPlayer` handles this finite exclusive clip set with fixed cross-fades.
Session speed changes update playback, Pause freezes it, and native screen/view
events stop hidden or offscreen skeletal evaluation. Existing RTS projection
events enable detailed skeletal playback at close zoom (size<=240); model
activities continue while views are hidden. Cached scene references and keyed
movement/shot facts avoid a per-frame inventory/inspection loop. Armament uses
one batched supplied-ID query at the existing presentation reconciliation.
Vertex colors are explicitly enabled on new-model materials; the manager's
texture override is not applied to them.

## Physical work positions

Four initial unloaders previously occupied the Table's exact centre. Rear work
positions now reserve distinct actual standing/reporting/pickup/drop points,
outside the Table and active footprints, through the current route owner.
Source-selection previews and actual reservations use that same owner; previews
do not mutate reservations. Explicit per-person holder access points preserve
physical local handling without increasing a global interaction-distance rule.
Unregistered holders retain exact colocation. Safe handoff releases reservations;
arriving people retain the actual foot position they reached.

These are model positions, not visual offsets. Worker labels use short stable
display numbers and current phases, retaining full person IDs in metadata and
management. A 25 kg order can correctly need one 25 kg carry; the other unloaders
remain idle. A 100 kg order can exercise all four actual unloaders.

The focused changed-core check at `4da57b7` passed in GitHub run 42663818654:
all four actual workers carried the paid 100 kg shipment through Pickup/Carry/Drop,
sampled positions stayed outside the Table, minimum sampled separation was
1.0103279m, actual 100 kg arrived and ordering reopened. It used explicit 0.25 s
elapsed intervals in the focused rear model, not a wall-time/FPS scenario.
This does not establish universal crowd avoidance or every crowded crossing.

## Verification and playtest

Required import/script parsing passed at the character source revisions.
The first rendered run 42665973485 exposed a runtime initializer type error;
repair365ca2f passed the same bounded character integration observation in
run 42666772053. Its actual soldier image then exposed the missing vertex-palette
material binding; its first worker camera missed actors and is not worker
appearance evidence. Those raw receipts are retained, not converted into passes.
Final corrected palette/reload observation 42670461448 passed at source `db9edb5`.
The [actual receipt](evidence/character_animation/receipt.json),
[workers carrying](evidence/character_animation/workers_carry.png),
[workers unloading](evidence/character_animation/workers_unload.png) and
[soldier reloading](evidence/character_animation/soldier_reload.png) were inspected. A later observer failure on an optional
mesh color channel was a check-script error, not another production defect.

Only brief changed-code GitHub checks are used. No local engine or regression
suite was run. Explicit model elapsed intervals and clip advance/seek used for
captured poses do not establish native input, wall-time pacing or 60 FPS. Imported
clip/source coverage is not a claim that every medical/engineering/support
variant or the entire game is animated/accepted.

Open root `project.godot`, press **F5**, then **Tab → 1x**. Look for four distinct
workers, order enough goods to give them actual work and watch the loading area.
Use **Rear / Battlefield** and the wheel to observe soldiers closely. The player
does not gain direct army commands through this integration. The existing
[stage 1/2 playtest](default_3d_playtest.md) remains awaiting Dawson's acceptance.

The [original plan](feature_plans/character_animation_v1.json),
[source-boundary amendment](feature_plans/character_animation_v2.json),
[actual integration findings](feature_plans/character_animation_v3.json) and
[ownership diagram](diagrams/character_animation.mmd) retain decisions and scope.
The [system atlas](system_atlas.html) and [UI function flow](ui_function_map.html)
link current functions and source lines.

Godot documents [AnimationPlayer](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html),
[advanced AnimationTree blending](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html),
[screen visibility signals](https://docs.godotengine.org/en/4.7/classes/class_visibleonscreennotifier3d.html)
and [vertex-color material use](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html).
The chosen finite clip adapter and event boundaries apply those capabilities
to this game's existing ownership; they are not a new general movement framework.

The later [Hauling increment](hauling_priorities.md) caught a placement regression from this feature: the solid Table blocked construction routes still rooted at its centre. Repair37a5c9c uses its existing standing access for validation and retained actual worker coordinates/collision. This is a later discovered regression, not evidence that the original scoped character check exercised placement.
