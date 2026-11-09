# Development delivery convoys and RTS construction — pre-code contract

Baseline d96ef41534dd93c1fa521652586080aeacd2b1fe. Dawson's 9 November request
and Designer handoff explicitly override the old zero-worker/60–90s offscreen
opening for development. Lead alone programs; Designer approves game meaning.
UI/UX provides the requested menu handoff. No other developer is activated.

## Player outcome and acceptance

The normal development opening keeps 2500 requisition/500 actual M11 and the
same manager, and adds four real untrained workers present/assigned at a
prebuilt unloading apron. They count in the normal shared population and may
be reassigned; no hidden labour, production facility or owned truck is granted.
Road runs west to east outside the south edge of the 240x180 buildable area.
Apron/Table/storage/personnel are physical places outside that build boundary,
connected through the open south boundary. Walking/hauling access includes
this service strip; building placement remains inside its existing bounds.

E on an actual current Table/building/site opens its existing appropriate
management context. Draft selection alone does not spend. At Purchase, select
raw whole kilograms and optionally one eight-person batch, inspect total
prices/transport fees, then Confirm once. Validate affordability, payload,
admission and rear places for the entire combined request before any debit,
reservation or carrier creation. Failed/repeated confirmation cannot partially
purchase. Existing specialised instructor recovery remains explicitly priced.

One development convoy gate owns the committed member IDs, including any
passenger vehicle. Actual supplier carriers/drivers/goods/passenger identities
are created at the road entry immediately, even while paused; movement and
handling freeze on Pause. Remove only offscreen dispatch/travel waits for this
opening, not physical motion, storage reservations, carrying or disembarkation.
Same-lane convoy vehicles use common speed and spaced origins/queue endpoints.
One shared unloading berth serialises freight/personnel; departing empty
vehicles continue east while subsequent trucks approach. Supplier service crew
remain external and are excluded from ordered-passenger emptiness.

Receiving owns the active member set. Each real departure-start removes its
member only after actual goods deposit/passenger arrival. Last member removal
emits the ordering-ready event exactly once. A new order can begin during old
empty-vehicle egress. No countdown, frame scan of history or empty-first-truck
shortcut. A blocked unload stays blocked. Existing capacity/custody/paid prices
remain authoritative. Existing debug exceptions remain visibly separate.

Build acquisition opens a dedicated orthographic top-down rear camera with
visible one-metre grid. WASD/middle drag pans, wheel zooms, R rotates, left click
confirms once and Escape/right click cancels. Snap footprint edges, including
half-cell centres for odd dimensions. Draft/rotation/camera changes invalidate
the old command token. Existing command path revalidates current footprint,
entrance/access, manager occupation, resources and service identity. Cancel or
rejection spends nothing; camera switch never moves the manager. Returning to
character view restores first/third preference; hidden services keep progressing.

## Ownership and Godot design

Receiving remains the sole purchase, physical incoming transport and unloading
owner. Add a small atomic combined command and mode flag rather than duplicate
inventory or introduce a general bus/scheduler. Scene-owned supplier visuals
consume state events for membership/labels and keyed ledger movement events
for poses; they never drive trucks or poll accounts. Reuse licensed local T01/
T02 exteriors, preserving explicit supplier labels and existing query-only
contact policy. New script sidecars come from the allowed remote import.

Preview retains its existing E/unhandled-input and physics-query safeguards.
General current-site mapping replaces Workshop-only admission; production
activities open Work, other real sites open current Build controls. No invented
recipe/training/combat controls. Build camera/grid live in World; no GridMap or
plugin is required for a flat footprint grid. One static line mesh avoids one
node per cell. Existing simulation settlement is not rewritten in this feature.

Official evidence: Godot Camera3D orthographic size/project-ray APIs support
the overhead view; signals implement the observer pattern; direct-space queries
belong in physics processing. These justify implementation choices, not FPS.
https://docs.godotengine.org/en/4.7/classes/class_camera3d.html
https://docs.godotengine.org/en/stable/getting_started/step_by_step/signals.html
https://docs.godotengine.org/en/stable/tutorials/physics/ray-casting.html

## Bounded verification and limits

Before merge: changed-script parse and one brief explicitly supplied remote
demonstration of this increment, with fixed45s wrapper/35s rendered child.
Normal new opening/four real assigned workers; explicit combined UI confirmation
creates correct paid carriers/cargo/people immediately and blocks another order;
actual service boundaries move/unload/arrive/depart and reopen ordering; overhead
grid preview/rotation/one commit/current-site E and cancellation preserve pose
and resources as applicable. Capture readable current Purchase/convoy and grid
views in that one episode. No debug grant or backend constructor replacement.
Short explicit simulated increments may demonstrate physical deadlines; this
is not native wall-time gameplay/FPS/full-loop acceptance. No local engine,
regression suite, lifecycle matrix, old Workshop replay or benchmark. Do not
weaken gates to obtain PASS. Maintain purpose/map/atlas/evidence after source
review; preserve all existing fixtures and unrelated local work.
