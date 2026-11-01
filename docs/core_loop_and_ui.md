# Core game loop and player interface

## Human direction — 1 November 2026

Dawson clarified the intended game in the Game Designer chat: start in an empty field with a character controlled using WASD; place workshops through a RimWorld-like build menu; purchase workers and assign jobs from a worker pool; turn raw supplies into manufactured goods; let logistics carry supplies onward to HQ and the autonomous battlefield. He then explicitly requested an enjoyable UI overhaul: complexity should come from building the base and managing workers, not interacting with menus.

This direction supersedes treating the prebuilt, menu-operated delivery prototype as the intended player experience, and supersedes requiring the player to compose and depart every routine supply shipment. The existing physical services remain useful implementation work. The current demo does not establish this corrected core loop.

The Designer owns these observable gameplay requirements. The Lead and Principle Engineer own implementation, architecture, assignments and integration. This document adds no engineering approval or testing gate.

## Intended player loop

1. Move the rear character with WASD and survey the buildable field.
2. Obtain raw resources and purchase workers through an understandable Supply Table/purchasing experience.
3. Open the build menu, preview a building on the field, and place it with a visible cost and access requirement.
4. Assign workers from the shared pool to construction, hauling and workshop jobs; choose production targets and priorities.
5. Watch actual workers build, collect ingredients and manufacture goods. Routine input collection and output movement follow the requested work without manual carry orders for every load.
6. Finished supplies enter the Logistics Centre's onward supply process. Actual workers and vehicles load, travel and unload automatically; the player can see demand, delivery progress and blockers.
7. Battlefield capability and resource income reflect the supplies and people actually received. The player responds by changing the base, workforce and production.

Player decisions concern what to build, what to purchase and produce, and how to allocate scarce labour and resources. Routine transport execution is automated. Dawson approved the opening package and army-request shipping policy below in direct answers on 1 November 2026.

## Approved empty-field opening

- One controllable rear character, using WASD.
- 2,500 requisition.
- 500 actual Building Materials (M11) at the accessible starter supply point.
- No hired workers and no workshops. The player purchases the first workers; the old prebuilt sixty-worker/facility package is not applied.
- A Supply Table and arrival point at the field's edge, giving access to resource and worker purchases.
- The first eight workers cost 140 requisition and arrive after 90 seconds, then physically disembark into the available worker pool.

The fixed purchase/arrival access must function without constructing a Receiving Bay first. Purchased ordinary workers can take initial construction jobs and use the declared materials without first needing a Construction Office or a working Materials Plant. This removes a circular opening requirement; it does not provide invisible builders or free construction. Later resource freight still needs actual unloading/handling and accessible physical storage. The character's presence does not implicitly provide a hired worker, trained instructor, qualified crew or hidden labour.

No extra rear inventory, trained staff or transport fleet is implied by this package. Real purchases, training and manufacture retain their applicable requirements. Preserve legitimate recovery access, including the existing instructor offer when no trained instructor remains. Existing battlefield forces/stocks are not changed by this rear-opening decision.

## Approved automatic onward shipping

Dawson selected **fulfil army supply requests automatically**, with actual physical loading, transport and unloading. The Logistics Centre is the player's understandable point for viewing and satisfying those requests; ordinary goods shipments do not require manual manifest composition or a Depart action.

- A request identifies the needed item, quantity, destination, priority and consequence of the shortage. Existing GDD military priorities apply; this is not permission to invent demand to make the factory appear useful.
- Distinguish outstanding need from stock already available at its destination and supply already committed or in transit to that same need. Do not dispatch the same quantity repeatedly merely because unloading has not finished.
- When actual requested stock and an eligible staffed/fuelled transport are available, logistics arranges a useful valid shipment automatically. A large request can be served through separate capacity-valid shipments; it does not require a full truck before useful supply can leave. Each actual shipment still stages and loads its declared quantity before departing.
- Workers collect and load real goods, the actual vehicle travels, and HQ staff physically unload. Arrival alone does not count as issue to a rifle or remote vehicle. Existing route, fuel/reserve, capacity and exclusive-person requirements remain.
- Missing stock, workers, transport, crew, fuel, safe access or receiving space produces an actionable waiting state. Automation creates neither goods nor transport capacity and does not silently change the player's production recipe or staffing choices.
- After receipt or changed military need, the displayed outstanding request updates. Genuine later demand can produce a later shipment in the same session. Finished goods without an applicable request remain stored rather than being shipped indiscriminately.
- Goods-shipping automation does not silently enlist industrial workers or permanently transfer ownership/control of rear vehicles. Ordinary returning supply transport and an explicit permanent military commitment remain distinct.

The default display shows the requested amount, available goods, committed/on-the-way quantity, actual received amount and current blocker or delivery progress, with direct access to the relevant workshop or job allocation. Backend shipment detail remains optional inspection.

## Existing worker rules retained

The following are the existing GDD baseline, not new balance changes:

- A standard purchase brings eight untrained people for 120 requisition plus a 20 transport fee: 140 total, with a 90-second arrival time.
- The arriving carrier and its service driver leave; they are not free members of the worker pool. Workers become available after actual disembarkation, not when purchased.
- Rear capacity is 120 people, including trainees, crews and committed incoming places. Purchases show their total cost, arriving count and capacity effect before commitment.
- The player sets requested job/staff counts and priorities. Allocation uses eligible idle workers before safe reassignment. Inspection of individual workers is useful but naming each person is not required for routine staffing.
- Workers must physically report to the workplace. A requested worker, an arriving worker and a present worker are distinct counts.
- Reassignment finishes an existing carry or deposits goods safely. One person cannot simultaneously build, haul, operate a workshop, train or crew a vehicle.
- Training and qualifications persist; specialist work still needs the actual required qualification. Ordinary rear construction does not require military engineer training.

The UI should preserve these rules while removing unnecessary interaction steps. They govern new purchases and assignments in the approved empty-field opening above; the old prebuilt worker/facility package does not bypass that opening.

## Interface requirements

- The base and character are the main play surface. Persistent controls make Build, Workers/Jobs and Supplies easy to find; routine actions do not depend on hidden overflow tabs or Diagnostics.
- Build presents readable building names, purpose, cost and footprint. Placement previews show valid/invalid space and a plain reason. Rotation and cancellation are obvious. Starting placement does not spend resources until confirmed.
- Selecting a workshop opens a compact contextual panel with its recipe, production target, assigned/present/requested workers, local inputs and current blocker. Staffing and priority can be changed there without a trip through unrelated panels.
- The worker/jobs board shows available, assigned, arriving and requested people, plus vacancies and priorities. It should be easy to move labour between useful jobs and understand the resulting shortage.
- Purchases clearly show resource names, quantities, total price and arrival state. Hiring has a direct action showing eight workers and the full 140 price; no hidden fee or instant pool increase.
- Resource displays distinguish physical stock, reservations and goods in transit. Ordinary views use readable names; internal identifiers and detailed ledgers belong in optional inspection.
- Routine hauling and shipping show useful progress and reasons for waiting. The player should be able to understand "Needs two workers" or "Waiting for Metal" and reach the relevant decision directly.
- Pause, speed and navigation remain reachable. Camera and character controls must be explained without confusing character movement with tactical control of soldiers.
- Advanced detail stays available on demand. The default interface concentrates on the current building, workforce and supply decision.

## Observable outcome

A player can purchase workers, see them arrive, place a workshop, allocate labour, obtain its ingredients, observe actual manufacture and understand automatic onward delivery using ordinary controls. Staffing changes visibly affect real work. Shortages explain what the player can change. The experience must deliver the empty-field/character/building loop, rather than presenting connected backend services as a completed game.

Existing physical identity, capacity, stock, qualification and safe-handling rules remain. Verification follows the latest human instructions; this brief requests no engine run, regression suite or additional demonstration.

## Sources and reconciliation

- Dawson's two direct messages in the Game Designer chat, 1 November 2026: core-loop correction and worker/UI clarification.
- Dawson's direct answers, 1 November 2026: "Use the proposed opening" (character, 2,500 requisition, 500 Building Materials, no hired workers/workshops, edge Supply Table/arrival access; purchase first eight for 140/90 seconds) and "Fulfil army supply requests automatically".
- [GDD sections 5.2, 7.2 and 8.2](game_design_document.md): worker purchases, assignment, staffing and physical work.
- GDD sections 10.1, 18 and 20 contain the older manual-dispatch/menu/prebuilt premises; the human direction above governs where they conflict. Preserve unchanged physical delivery rules while reconciling the player experience.
