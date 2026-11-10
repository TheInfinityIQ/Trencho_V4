# Construction capacity and personal pickup

[Accepted rules](manager_pickup_and_construction_capacity.md),
[pre-code plan](feature_plans/builder_cap_player_pickup_v1.json) and
[integration diagram](diagrams/builder_cap_player_pickup.mmd) define this block.
The implementation checkpoint is provisional until its direct receipt, actual
export and final review are recorded below. Player animation acceptance stays
pending separately from code integration.

## Construction commitments

The opening supports two construction workers across all sites. Each actual
completed Construction Office adds four capacity places: 2 / 6 / 10 for 0 / 1 / 2 offices.
An unfinished office grants nothing. A site still supports at most four builders.
The same finite shared people fill these places; no new worker is created.
Office starter requests remain two real workers and count within the same limit.

ConstructionService computes capacity from its actual facility state. A command
projects distinct actual/pending construction people plus unfilled target places.
Moving between construction duties does not duplicate a person; a requested old
vacancy still reserves a replacement if the player has left that target active.
Outgoing carriers retain capacity until their existing safe handoff completes.
Office-to-site deployment frees the same resident request before admission and
restores it if transfer fails. Both target changes and direct person reassignment
use this owner, including Workers/Jobs commands. Reductions remain possible.

The Build menu shows shared commitments/total separately from actual present and
requested site builders. Its opening spin maximum is two, rising to four per
site after office completion. The owner still validates the fresh command.
Office dismantling refuses to remove needed capacity, including the eventual
dismantling crew, and retains existing checks on the office's own present staff.
No person or carried cargo is silently evicted.

## Personal pickup

One original faceted blue pickup stands beside the rear starting road. It is a
separate personal development vehicle, never an office/supplier/military truck.
Approach and aim at it, then press **E**. Use **W/S** forward/reverse, **A/D**
steer, **Space** brake, **V** first/chase view, and **E** to exit when stopped.
An exit needs clear adjacent ground; otherwise the same manager remains seated.

Opening management/build mode, changing areas or losing capture/focus removes
driving input and brakes while preserving occupancy. Returning requires fresh
input; held keys do not silently resume throttle. Pause freezes motion and sway.
The manager is the same canonical physical pose, not another workforce person.
Its standing collider is disabled only while seated, then restored at the actual
clear exit. Session replacement resets the personal transport once.

The pickup has **unmetered prototype fuel** and no freight/cargo operation. This
explicit exception creates no fuel inventory, driver qualification or fleet rule.
Actual office/logistics/military supply and finite fuel remain with their owners.
General AI traffic/contact, damage/crushing and a personal fuel economy remain
outside this slice. This is grounded arcade handling in the existing flat rear,
not realistic suspension or an off-road vehicle simulation.

## Engineering ownership

The existing Preview input owner steps one composed CharacterBody3D. Steering
checks actual angular clearance and move_and_slide resolves terrain/building
collision. Only active movement/settling uses physics work. Exit clearance is
queried on E, and changed actual vehicle bounds feed fresh construction preview
and commit, including numeric placement. This adds no supply/staffing polling.

Wheel rotation uses actual travel; body roll uses accepted yaw and speed, while
pitch uses acceleration/braking. These transforms affect the Artist visual only;
the collision body stays upright. Cameras and occupancy do not create another
simulation clock. The existing covered startup draw includes the actual pickup
material variants, retaining scene-owned resources before enabling interaction.

[Godot CharacterBody3D](https://docs.godotengine.org/en/4.7/classes/class_characterbody3d.html)
supports script-controlled collision motion. Using it here is a project-specific
choice for a bounded arcade controller; it does not claim to replace realistic
vehicle physics. [Physics space queries](https://docs.godotengine.org/en/4.7/classes/class_physicsdirectspacestate3d.html)
support the deliberate exit and angular-clearance operations.

## Full motion approval

[Animation review policy](animation_review.md) requires complete video playback.
The Artist owns original pickup/source/export QA and full current worker/soldier
asset reels. The Lead provides actual integrated driving and construction footage,
clearly labeled as an arranged current-change recording. Offline fixed-frame video
is not real-time performance evidence. Dawson's approval of the displayed versions
remains pending until explicitly given.

No local engine run or regression suite is authorized by this block. Brief changed
production checks and its one directly supplied remote demonstration retain the
existing 45 / 35 / 28 second bounds. Native controls, all vehicle/building/lifecycle
combinations, the connected factory/army loop and60FPS remain separate acceptance.
