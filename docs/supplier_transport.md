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

## Remaining before delivery

Two-person timber custody has a passed standalone pickup/movement/deposit
demonstration. Its physical supplier/warehouse route is not connected yet.
Measured contacts exposed obstructions in both the original lower truck pickup
and original warehouse timber fixture. The Artist is measuring a coupled
withdrawal and a separate revised timber rack; originals remain preserved.
Unvalidated provisional warehouse path helpers were withdrawn before use.

The new vehicle presenter is source-integrated. Actual model import, driver and
packet handling presentation, newly authored paired/passenger clips, complete
visible review videos and native appearance still need acceptance. The current
combined domain demonstration retains the earlier passenger exit cadence; it
does not establish the new seated-to-ground animation sequence.

Presentation contract before implementation: SupplierActorView receives an
actual person ID, an Artist-provided character scene and a committed activity.
It evaluates the named authored clip against Receiving time only while visible.
The activity supplies root transforms, contact timing and loop semantics; the
presenter cannot move an inventory/person record or advance the simulation.
Missing clips fail explicitly. The existing worker/soldier presenter remains
unchanged. Driver/occupant calls connect only after the exact Artist export and
root-to-marker contract are accepted; a compiling presenter is not an animation.

The existing Force Deliver action is an explicit travel/storage bypass. Its
integration must resolve cargo in every actual carry phase, release normal
warehouse promises, place active handlers at the safe rear exit, release their
access commitments and mark the debug-completed convoy gate consistently.
Normal deliveries retain their full physical handling and departure conditions.

The final feature needs current-head Lead/Designer reviews, required checks,
publication and safe main adoption. Human numbered-stage and60FPS acceptance
are separate. Existing regression suites remain untouched and unrun.

## Source and evidence

- [Prospective plan](feature_plans/supplier_transport_v1.json)
- [Whole feature diagram](diagrams/supplier_transport_loop.mmd)
- [Road ownership](supplier_road.md) and [passenger sequence](diagrams/supplier_passengers.mmd)
- [Two-person custody](joint_material_carry.md)
- [Single Artist contract](supplier_asset_contract.json)
- [Exact scoped receipts and retained failures](evidence/supplier_transport/current_change_receipts.json)
- [Clickable current source atlas](system_atlas.html)

Only brief current-change demonstrations run on GitHub. No local engine,
broader failure matrix, regression suite or new frame-rate claim is included.
