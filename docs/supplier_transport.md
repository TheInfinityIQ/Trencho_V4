# Materials and passenger supplier integration

Active feature work is isolated on `codex/supplier-transport-loop`, based on
`a2d182f`. This document describes the candidate, not a completed main-game
delivery. The original assets and approved concepts remain intact.

## Connected candidate behavior

- The Supply Table quotes actual supported packages, shelf space and vehicle
  fees before committing the complete paid order. Packing runs on cart changes.
- Each delivered packet has one actual stock identity. Workers enter the real
  rear ramp only after the shutter and ramp sequence completes, then carry the
  goods to a reserved finite warehouse position.
- An aisle waiter retains package space without holding the warehouse standing
  face. Actual clearance events wake blocked access; a duty change cannot take
  a worker away from an unfinished ramp exit.
- Materials and personnel have separate stops. A finished passenger carrier
  can take a checked passing route while the material truck continues unloading.
  Relevant physical changes wake traffic holds; stopped vehicles do not accrue
  travel distance. Ordering still requires actual handovers and departure.
- Purchased people have distinct actual retained-model seat positions; the
  supplier driver remains a separate supplier-owned identity.
- Dawson-approved passenger revision v02 now drives stopped preparation,
  rear-to-front standing/walking, supported leg extension, flight, landing and
  rear clearance. One real identity then walks independently to Personnel.
  The carrier may depart after the last rear clearance; workforce admission
  still waits for each actual arrival. Force Deliver includes people whose
  carrier has already finished departing.
- Actual movement events update passenger roots even offscreen. Visibility
  suppresses skeletal evaluation, never spatial following. Animation method
  tracks cannot transfer people or stock. Pause freezes the committed clock.

## Remaining before delivery

Two-person timber custody has a passed standalone pickup/movement/deposit
demonstration. Its physical supplier/warehouse route is not connected yet.
Measured contacts exposed obstructions in both the original lower truck pickup
and original warehouse timber fixture. Dawson has now resumed contacts and
animation work on2m planks/50kg maximum bundles with two workers roughly1.3m
apart. Artist is measuring reachable separate rack revisions and actual
withdrawal/put-down; originals remain preserved. Existing synchronized bend
motion is reused, with fitted arm/hand hauling fragments and no new bend clip.
Unvalidated provisional warehouse path helpers were withdrawn before use.

Actual retained vehicles, driver v02, passenger v02 and static S2/S3/S4 shelves
imported on GitHub. Current-change native run42959035573 at source `aec2dae`
observed approved push-off/flight/landing/clearance timing, the slower passing
route, exact48kg Components/21kg Fuel warehouse receipt and eight actual arrivals.
Its4.5second passenger recording and separate3second driving recording are
isolated production components: warehouse scenery and hauler avatars are omitted.
They do not establish F5 input, every material, human gameplay or60FPS acceptance.
Source `dbf2ea4` subsequently parents supported actors to the actual truck pivot,
detaches at takeoff and preloads the approved paths as an exportable Resource.
Dedicated check42960993401 observed real offscreen following and the first actual
supported exit/landing; it does not reattribute the earlier recording to new code.

Presentation contract before implementation: SupplierActorView receives an
actual person ID, an Artist-provided character scene and a committed activity.
It evaluates the named authored clip against Receiving time only while visible.
The activity supplies root transforms, contact timing and loop semantics; the
presenter cannot move an inventory/person record or advance the simulation.
Missing clips fail explicitly. The existing worker/soldier presenter remains
unchanged. Passenger roots use the exact approved30fps metre/yaw samples,
interpolated against the same activity time as the authored joint clips.
Supported roots follow the actual truck pivot; flight/landing use the stopped
level service frame. The reference deck is1.02m above flat ground. One artist
midpoint diagnostic records1.891mm sole deviation; perfect1mm contact is not
claimed. See the versioned approval and manifest under the supplier assets.

Godot's [manual AnimationMixer process mode](https://docs.godotengine.org/en/stable/classes/class_animationmixer.html)
and [AnimationPlayer seeking](https://docs.godotengine.org/en/stable/classes/class_animationplayer.html#class-animationplayer-method-seek)
support read-only evaluation. Update-only seeking omits method/audio/playback
tracks; activity deadlines, rather than animation-finished callbacks, decide
custody and arrival. This preserves progression while the view is hidden.

The existing Force Deliver action is an explicit travel/storage bypass. Its
integration must resolve cargo in every actual carry phase, release normal
warehouse promises, place active handlers at the safe rear exit, release their
access commitments and mark the debug-completed convoy gate consistently.
Normal deliveries retain their full physical handling and departure conditions.

The final feature needs current-head Lead/Designer reviews, required checks,
publication and safe main adoption. Human numbered-stage and60FPS acceptance
are separate. Existing regression suites remain untouched and unrun.
The consolidated candidate is [draft PR146](https://github.com/TheInfinityIQ/Trencho_V4/pull/146),
branch `codex/supplier-transport-loop`. It is not yet merged or adopted into the
human root checkout. Open the isolated worktree's `project.godot` for that
candidate; the existing configured entry remains3D at1x.

## Source and evidence

- [Prospective plan](feature_plans/supplier_transport_v1.json)
- [Whole feature diagram](diagrams/supplier_transport_loop.mmd)
- [Road ownership](supplier_road.md) and [passenger sequence](diagrams/supplier_passengers.mmd)
- [Two-person custody](joint_material_carry.md)
- [Paired supplier plan](feature_plans/paired_supplier_unloading.json) and
  [its operation diagram](diagrams/paired_supplier_unloading.mmd)
- [Single Artist contract](supplier_asset_contract.json)
- [Exact scoped receipts and retained failures](evidence/supplier_transport/current_change_receipts.json)
- [Clickable current source atlas](system_atlas.html)

Only brief current-change demonstrations run on GitHub. No local engine,
broader failure matrix, regression suite or new frame-rate claim is included.
