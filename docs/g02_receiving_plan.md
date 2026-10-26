# G02 procurement and receiving plan

Assigned scope: [G02 #10](https://github.com/TheInfinityIQ/Trencho_V4/issues/10), M0. Base: merged G01 `c08cb3f`. Authority: GDD sections 3–5, receiving/personnel rules in 8.1–8.2, and governing section 23. This plan precedes substantive implementation.

## Implementation sequence

1. Add a small procurement service under `game/procurement/`, owning money, delivery orders, incoming reservations and timed receiving activities while using the G01 ledger for every physical person and stock holding. Keep source records and external services separate from player fleet/population.
2. Quote the nine purchasable materials at their exact listed prices, explicitly split orders into vehicles of at most 5,000 kg with a 20 fee each, and validate the complete quote before any debit. Reserve delivery places and incoming people atomically. Enforce the first-five-second refund window without duplicated money, records or people.
3. Advance supplier arrival and local handling with controllable simulation time. Goods stay aboard until an assigned real worker physically picks up, carries and deposits them into reserved Receiving storage. People disembark under their own movement through the independent personnel pull-off, then become player people and release incoming-place reservations.
4. Supply a Terminal/Receiving review UI and deterministic A04/A58 fixtures with visible purchase, incoming, onboard, disembarking, unloaded/available, money, people and queue counts, plus actionable blockers. Retain the G01 fixture and regressions.
5. Add focused regression coverage, run the repository checks with Steam Godot 4.7.2, verify native controls, record evidence and future restore obligations, and return an unmerged PR to the Game Designer.

## Observable acceptance

- M01/M02/M03/M04/M05/M07/M08/M09/M10 use unit prices 2/4/1/1/2/12/2/6/8, at one kg per unit. M06 and M11 purchases fail without side effects. Multi-vehicle quotes expose every vehicle and fee before commitment.
- Arrival cannot precede purchase +60 seconds for resources or +90 for the eight-P00 manpower order costing 120+20. Simulation time is explicit; baseline income remains 6 per second. A cancellation before dispatch refunds once and releases reservations; attempts after the five-second window or repeated cancellation leave state unchanged.
- A04: with no rear unloaders, arriving player-owned material stays physically on supplier transport and locally unavailable. Eight people can use their separate pull-off, physically disembark into reserved rear places, and supply actual Receiving labour.
- A58: a full blocked freight queue cannot consume the two personnel-vehicle places. Zero-worker recovery introduces exactly eight P00, preserves goods, and allows subsequent timed unloading without borrowing supplier drivers.
- Rear population has a 120-place baseline. All incoming orders reserve their places before debit; simultaneous orders cannot overbook them. Valid cancellation and disembarkation release the relevant incoming reservation consistently while physical rear people remain counted.
- Receiving permits at most four assigned real workers and 5,000 kg of stored/reserved output. Ordinary loads are one type and at most 25 kg; pickup/drop take two seconds each, movement uses the documented walking speeds, and destination capacity is reserved before pickup. Partial or blocked unloading preserves onboard/in-flight/deposited quantities.
- Supplier carriers/drivers retain external identities and never become player fleet or recruits. Interrupted worker reassignment respects G01's safe-deposit invariant. Failures report causes and do not change money, stock, orders, people or reservations.

## Scope boundaries and agreed admission contract

The Game Designer clarified the contract on 26 October 2026 (GDD section 23.3): one physical freight berth plus ten shared off-map waiting places gives eleven accepted unfinished freight vehicles total, inclusive of transit/queue/berth states. Personnel admits two unfinished vehicles total, inclusive of transit/disembarking. Reserve admission before debit and release exactly once on valid cancellation or physical vehicle clearance. Empty cargo alone does not release admission. Incoming population and per-unload output-storage reservations are independent. Regression and native evidence must include eleven-versus-twelve commitments and cancellation/reuse without duplicate release.

Predefined Receiving/Personnel locations and a bounded assignment of actual eligible G01 people are allowed here. General staffing/hauling automation remains G03; production G04; construction G05; training/instructor recovery G06; emergency strategic transport/dispatch G12; card choice/bundled capabilities G31; whole-game persistence G32. D03's forward/strategic lifecycle memberships are not inferred by this receiving-only model. No production battlefield presentation decision is made.

## Review correction plan — 26 October 2026

The Game Designer confirmed that GDD 10.2's one-person-per-second handling rate also governs external manpower under 5.2. Correct the simultaneous exit: after stopping, schedule one completed passenger exit each second per vehicle; retain each person aboard until their own handling completes, then start their existing 1.5 m/s walk. Keep incoming places reserved until individual F08 arrival, seated supplier crew aboard, and vehicle admission through last arrival and physical clearance. Each vehicle owns its cadence independently.

Acceptance: boundary regressions must distinguish first/eighth exits and arrivals, aboard/walking/available people, individual reservation conversion, two parallel vehicles and separate physical clearance. Update stale A04/A58 timing assumptions and inspection wording, rerun domain/interface and retained G01 checks, and publish the corrected draft head/CI. Native verification remains pending under the existing desktop access restriction; no G03 scope is added.
