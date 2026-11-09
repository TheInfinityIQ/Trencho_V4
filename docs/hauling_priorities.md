# Default Hauling and task priorities

Open **Workers / Jobs → Hauling** in the normal F5 game. The four opening workers
and physically joined ordinary arrivals fill the default Hauling pool. Existing workplace staffing requests and qualified crew commitments take precedence; each person still has
one actual assignment and one active task.

The shared pool starts with this order:

1. Unload incoming supplies.
2. Load outbound supplies.
3. Supply construction sites.
4. Supply production.
5. Other hauling, including storage relocation.

Drag a row by its six-dot handle, or select it and use **Move up / Move down**.
The top row has the highest preference. Changes remain a draft until **Confirm
hauling priorities**. **Revert changes** restores the committed order. Collapse
preserves the open menu's draft; closing management discards unconfirmed edits.
Live status updates preserve edited order. Priority edits also work while paused
or before more workers arrive; they do not create workers or work.

Preference selects the **next feasible task**. A blocked category permits useful
work below it. Existing within-category urgency/distance/order still chooses
between local hauls. Reordering does not cancel claims, discard stock or restart
an active carry. Dedicated facility staff continue their own jobs independently
of the common pool's category preferences.

## Incoming truck workers

There is no intended two-worker cap. Receiving permits up to four simultaneous
handling jobs per berth, combining common and dedicated workers. A worker takes
up to 25 kg, so a small shipment may need fewer people. People walking to the
truck, picking up, carrying and depositing are different real phases; standing
beside the truck is not a reliable concurrency count.

The normal configured main and unchanged GameSession clock ran headlessly at 1x
in GitHub run42681222461, source `a6c49d6`. At simulation time11s, four actual
workers each held a separate25kg claim on the naturally arrived100kg carrier.
This establishes that conditional allocation, not the cause of Dawson's earlier
two-worker observation or completed wall-time throughput/rendering/FPS.

The current rendered menu episode uses explicit model elapsed intervals for its
later portions. It observed actual grip drag through injected Godot GUI events,
unconfirmed order surviving refresh, fallback/revert/confirm, existing claims
surviving priority change, an actual construction haul winning before remaining
incoming freight, actual200kg deposited and eight real new arrivals joining
Hauling. Its overall raw receipt remains a failure because its later outbound
fixture supplied an unregistered reference truck; that does not turn the earlier
individual observations into a complete-run pass. The corrected finite outbound component passed run42685010971 at `5fdd556`: actual25kg was staged and loaded aboard the same canonical registeredT01, with a real qualified driver and bounded2L starting fuel. Its public initial-state setup follows the actually allocated fixture worker, rather than assuming an identity. The shared idle-default starter eligibility filter also passed. See the [scoped receipt](evidence/hauling_priorities/receipt.json).

## Actual owners and finite work

`Rear` owns assignments, actor phases, safe handoffs and its existing settle
transaction. A feature-local `HaulingPolicy` owns only category order and the next
eligible selection. `Receiving` still owns source/destination claims and timed
walking/pickup/carry/deposit. Its common worker returns to selection after actual
deposit, rather than automatically claiming another unloading job ahead of the
chosen order.

`Dispatch` retains manifests, goods, routes, handling and its finite per-manifest
task. Ordinary common workers approach real source/staging points before pickup
and load the same registered truck. A complete usable Logistics Centre, accepted
shipment, real transport, appropriate driver and actual fuel remain necessary.
Gun teams, passengers, specialist roles, HQ handling and driving retain their
existing authorities. A staffing target can wait for outbound handling to finish;
a direct person reassignment during that committed task returns an explicit busy
reason. Animation reads supplied task facts and never performs work.

No new game clock, autoload, per-frame eligibility watcher or generalized job
framework is introduced. Menu reads use the existing supplied workforce view;
native GUI callbacks update a local draft. The implementation uses Godot's
[Control drag/drop callbacks](https://docs.godotengine.org/en/4.7/classes/class_control.html#class-control-private-method-get-drag-data)
and [preview lifecycle](https://docs.godotengine.org/en/4.7/classes/class_control.html#class-control-method-set-drag-preview),
following the engine's [small composed scene guidance](https://docs.godotengine.org/en/stable/tutorials/best_practices/scene_organization.html).

## Found Table-access regression

The current episode caught a regression introduced by character integration
`4da57b7` / PR140: the Table became a solid pedestrian obstacle, while construction
access validation still began at its centre. That interior point had no legal
outgoing route. Repair `37a5c9c` keeps the obstacle and real inventory centre,
shares the existing3m north standing offset and validates from that access point.
Actual worker candidate coordinates stay unchanged. The repeated current episode
then placed the real site and selected its actual materials haul. No arbitrary
inside-obstacle exemption or weakened placement check was added.

Existing once-only workplace starter requests can use idle default haulers. Active handling waits for a safe boundary; explicit staffing edits, including zero, remain authoritative. The same candidate filter serves quota planning and actual selection, and reporting completion retries waiting intent without a new timer.

The frozen [plan](feature_plans/hauling_priorities_v1.json),
[observer prerequisite correction](feature_plans/hauling_priorities_v2.json),
[access finding](feature_plans/hauling_priorities_v3.json),
[starter compatibility](feature_plans/hauling_priorities_v4.json) and
[ownership diagram](diagrams/hauling_priorities.mmd) retain the chronology.
Raw scoped receipts, failed dispositions and the actual menu capture belong in
`docs/evidence/hauling_priorities/`. Current system atlas/function purposes and
UI flow are regenerated against final reviewed source.

No local engine, regression suite, broad scenario or performance campaign was
run. Native OS input comfort, all task/vehicle/specialist combinations, universal
crowd avoidance, normal complete factory/army supply and 60 FPS remain unverified.
Dawson's numbered stages1/2 still await his playtest acceptance.
