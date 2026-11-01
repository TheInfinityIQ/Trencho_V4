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

Player decisions concern what to build, what to purchase and produce, and how to allocate scarce labour and resources. Routine transport execution is automated. Specific shipping priorities, load thresholds and starting-state/bootstrap quantities still need a concrete design definition; this document does not invent those values or grant goods.

## Existing worker rules retained

The following are the existing GDD baseline, not new balance changes:

- A standard purchase brings eight untrained people for 120 requisition plus a 20 transport fee: 140 total, with a 90-second arrival time.
- The arriving carrier and its service driver leave; they are not free members of the worker pool. Workers become available after actual disembarkation, not when purchased.
- Rear capacity is 120 people, including trainees, crews and committed incoming places. Purchases show their total cost, arriving count and capacity effect before commitment.
- The player sets requested job/staff counts and priorities. Allocation uses eligible idle workers before safe reassignment. Inspection of individual workers is useful but naming each person is not required for routine staffing.
- Workers must physically report to the workplace. A requested worker, an arriving worker and a present worker are distinct counts.
- Reassignment finishes an existing carry or deposits goods safely. One person cannot simultaneously build, haul, operate a workshop, train or crew a vehicle.
- Training and qualifications persist; specialist work still needs the actual required qualification. Ordinary rear construction does not require military engineer training.

The UI should preserve these rules while removing unnecessary interaction steps. Exact starting worker and building/material packages must be reconciled with the empty-field opening; the old prebuilt package is not an instruction to bypass that opening. Resolve construction bootstrap without silently granting materials or creating an impossible first workshop.

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
- [GDD sections 5.2, 7.2 and 8.2](game_design_document.md): worker purchases, assignment, staffing and physical work.
- GDD sections 10.1, 18 and 20 contain the older manual-dispatch/menu/prebuilt premises; the human direction above governs where they conflict. Preserve unchanged physical delivery rules while reconciling the player experience.
