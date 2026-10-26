# Design decisions and readiness gates

Recorded 25 October 2026. Authority: Game Designer's project-planning update. Gameplay baseline: [GDD v0.2](game_design_document.md); governing planning amendment: [v0.2.1, section 23](game_design_document.md#23-project-planning-amendment-v021---25-october-2026). Engineering decisions remain in [foundation.md](foundation.md).

## Recorded sequencing decisions

| Decision | Rationale and acceptance ownership |
| --- | --- |
| M3 closes on sustained contested objectives, earned requisition, coordinated intent/reports, retreat and physical resupply at full world scale. | Its previous HQ-result exit depended on winning capabilities delivered later. Full autonomous HQ outcome evidence starts at M5 and remains part of M7 integration. No assault or damage rule changes. |
| Separate G04 recipe evidence from G31 card-unlock integration. | A09's complete tank-card bundle scenario remains required under G31; G04 need not wait for its own dependent issue. |
| Separate G01 accounting evidence from G16 casualty integration. | A03's complete incapacitation, dropped functional weapon and recovery scenario remains required under G16. |
| Separate G07 hull/crew evidence from G23 firing integration. | A13's complete main-fire/ammunition scenario remains required under G23. G07 retains legal transfer, real station assignment and combat-deployment crew requirements. |
| Separate G08 terrain fixtures from G19 destroyed-causeway integration, and G13 load fixtures from G20 engineer-built crossings. | A14 and A23 retain their complete later integration evidence. Early world and transport milestones need not depend cyclically on later engineering. |
| G11 supplies four full-size family fallbacks. | River Valley, Lake District, Highland Passes and Farmland and Towns each need a validated 4,000 by 6,000 metre fallback satisfying the same mandatory tests as candidates. |

An issue closing on foundation evidence does not waive later integration. Keep each deferred final scenario linked to the issues that establish its prerequisites and the issue that supplies its complete behaviour. Milestone evidence must demonstrate the relevant interactions.

## Procurement admission clarification — 26 October 2026

The Game Designer confirmed [GDD section 23.3](game_design_document.md#233-procurement-admission-clarification---26-october-2026): G02 uses one F02 berth plus ten shared off-map waiting places, for eleven accepted unfinished freight vehicles inclusive of transit/queue/berth commitments. Personnel has two accepted unfinished vehicles inclusive of transit and disembarking. Reserve admission before debit; release it once on valid pre-dispatch cancellation or physical vehicle clearance, never merely on emptying cargo. Incoming rear population places and per-unload Receiving storage reservations remain separate. A58 verifies the blocked berth plus ten waiting trucks, zero workers and independent manpower recovery. Further F02 integration belongs to G05; D03 remains open.

## Open decisions

| Gate | Closure evidence | Consequence until resolved |
| --- | --- | --- |
| D01 Presentation, platform and full-map performance | Game Designer confirms presentation and target platform/hardware and records measurable readability, interaction, generation/loading and operating expectations using measured prototype results where useful. | Measured prototypes allowed. Production world presentation is not ready. Do not assume existing renderer/window defaults settle this decision. |
| D02 Exact cover-capacity fairness metric | A repeatable fixture defines protected positions, spacing, approach direction, view of contest and minimum useful capacity; demonstrate the section 15.4 25-percent comparison. | Other map work can proceed; the cover-fairness validator cannot close using an invented interpretation. |
| D03 People and capacity across lifecycles | A reviewed matrix identifies rear-place and cap membership, reservation and release across departure, onboard waiting, disembarkation, forward replacement, wounds, recovery and loss; distinguish returning crews, incoming commitments, HQ reserve, active military and forward assigned transfers. | Identity/exclusive-duty work can proceed. G12/G15 commitment and capacity acceptance cannot close until the matrix is agreed and demonstrated. |

These gates describe design outcomes, not software architecture. Raise concrete contradictions and measured constraints to the Game Designer. Do not introduce new gameplay rules to make a gate disappear.

## Baseline status

User-established scope and proposed numerical defaults remain distinct under GDD sections 1.1 and 1.2. v0.2.1 corrects project sequencing and records unresolved gates; it does not validate balance, change combat eligibility or claim any acceptance scenario has run. Further numerical or gameplay revisions must identify the changed rule, reason, affected scenarios and required revalidation.
