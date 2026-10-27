# Vehicle Works heavy manufacturing foundation

[Designer scope](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6455906108), accepted PR71/main `35f8ea70`. GDD6.1/6.3/8/10/[23.6](game_design_document.md#236-production-targets-output-promises-and-heavy-output-staging---26-october-2026) and [D03 hull admissions](d03_people_capacity.md#5-hull-and-external-service-domains-o8) govern. Related #12; no automatic issue closure.

F10 now owns one heavy-object/vehicle bay, using the existing eight real operator positions and 5000kg local input store. The six heavy recipes join the retained 23, for all29 catalogue rows. Exact inputs/work and physical outputs are canonical:

| Recipe | Output | Inputs | Operator-work | Empty mass kg |
| --- | --- | --- | --- | --- |
| R13 | 1 E13 field gun | 100 M01,60 M02 | 600 | 180 |
| R25 | 1 T01 resource transport | 120 M01,80 M02 | 800 | 4000 |
| R28 | 1 T02 troop transport | 100 M01,60 M02 | 700 | 3200 |
| R29 | 1 T03 technical | 80 M01,50 M02 | 900 | 2000 |
| R30 | 1 T04 APC | 500 M01,250 M02,20 M07 | 2200 | 14000 |
| R31 | 1 T05 tank | 1200 M01,500 M02,40 M07 | 4000 | 30000 |

Field gun is a packed heavy object, not ordinary haulable stock; its180kg mass and400health remain physical. Vehicles are real carrier identities with canonical hull mass/health/footprint, seats, payload, tank/station/rack capacities and integral gun/mount mechanisms. Each is created with zero fuel, crew, passengers and ammunition. No spare loose E05 or battlefield capability is granted. These records belong to the identity ledger; the production owner supplies canonical properties and cannot replace them with an inventory copy.

## Request, acceptance and actual output

Select Vehicle Works in Work, set its stock target/Continuous request, then **Accept heavy order**. Request settings alone do not reserve a hull. Acceptance secures this order's one-bay promise and, for hulls, its actual rear8 admission and a finite F11 parking destination before any material consumption, including while materials/labour are missing. A request rejected for full fleet/bay/destination stays unaccepted and consumes nothing. R13 uses the bay without a vehicle fleet place. The retained owned yard T01 counts as one rear hull, so a T01 minimum of2 requests one more hull; foreign suppliers and explicitly external leased hulls do not count as player fleet grants.

D03 fleet claims live in the identity ledger, shared by owners rather than inferred from storage kilograms. Completion checks the SAME own claim, live/reserved limit, physical empty bay and legal own parking/collection destination again, creates one actual object and converts reserved to live exactly once. Seven live plus one reserved remains7/1 while the destination is invalid, then becomes8/0 on legal creation. A military intention has no bypass. Parking or cancellation cannot release a real hull's rear membership. Incoming military24 and HQ handoff are not simulated.

F11's four finite places have explicit metre positions within its footprint. A heavy destination claim also checks canonical hull footprint against that area and other occupied/reserved places. Destination edits secure a legal replacement before releasing the old own claim; occupied/reserved/invalid edits fail without partial mutation. Existing G03 yard movement remains its retained two-place path.

Factory/input/bay access loss pauses work and retains the same consumed receipt/promise. Parking access can block physical completion after all work is earned; no extra work is charged upon recovery, even with staff subsequently removed. A lower stock target never cancels an accepted/consumed order. An accepted unconsumed order can be cancelled without material loss. A consumed recipe change retains the shared explicit confirmation and per-recipe history/targets/identity sequence. Cancelling releases only its unused bay/fleet/parking promises and never deletes a finished object or frees an occupied bay.

Completion occupies F10. Missing actual P08 or fuel reports **Awaiting Qualified Driver / Fuel Empty**, preserving the same hull and reserved parking. Field gun reports the real two-loader/20-second collection requirement. There is no Clear Bay, reset timer, stock transfer, free driver/refuel or implicit collection action. Starting an explicit new session is a different declared scenario, never evidence of physical clearance.

R25/R28 remain essential in the same normal12ordinary/2500/no-goods session. Expanded production access declares all29 recipes at creation; it is still controlled content access, not real cards. Nine-resource procurement, staffing, hauling and all non-heavy operation remain connected.

## Verification and owning continuations

Eight focused heavy domain cases parameterize all six exact rows and all five hull catalogues, accepted-before-input promises, exact work/empty output/retained bay,7/1-to-8/0 conversion, full-fleet atomic refusal, field-gun exemption, waiting/consumed cancellation and stale confirmation, real staff/access/parking recovery, each ingredient's ineligible/claimed/carried rejection, and default/expanded/service boundaries. Component evidence uses fresh independent setups, including declared existing travelling rear hulls whose freed parking does not release their fleet membership. It never resets an occupied live bay to pretend collection.

One actual-input normal-session flow purchases transport inputs, accepts the order before their delivery, assigns eight real operators plus receiving/haul workers, creates the same empty T01 in F10, refuses a next R28 order and retains that hull through cancellation. It also physically hauls remaining bought inputs into R01 and makes a rifle without resetting the base. Three normal/small representative captures are retained in `.artifacts/heavy-production/`. Full normal checks and all eight existing focused failure controls remain; no per-recipe controls or broad image packet is added.

[G07 issue15](https://github.com/TheInfinityIQ/Trencho_V4/issues/15) owns positive physical clearance of these SAME produced hulls through actual P08 reporting/boarding, local refuelling and legal parking for all types. The initial yard hull is not produced-hull evidence. [G12 issue20](https://github.com/TheInfinityIQ/Trencho_V4/issues/20) owns real two-loader/20-second field-gun collection and manifest/HQ admission integration. No public clear-bay shortcut is provided here; those continuations must supply an actual physical handoff. Actual Fleet Transfer/HQ incoming24, construction/training, world/AI, save/load, real cards, Windows-native and fullM0 remain separate. The Designer assesses fullG04 criteria from the delivered evidence.
