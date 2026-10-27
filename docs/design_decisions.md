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

The Game Designer confirmed [GDD section 23.3](game_design_document.md#233-procurement-admission-clarification---26-october-2026): G02 uses one F02 berth plus ten shared off-map waiting places, for eleven accepted unfinished freight vehicles inclusive of transit/queue/berth commitments. Personnel has two accepted unfinished vehicles inclusive of transit and disembarking. Reserve admission before debit; release it once on valid pre-dispatch cancellation or physical vehicle clearance, never merely on emptying cargo. Incoming rear population places and per-unload Receiving storage reservations remain separate. A58 verifies the blocked berth plus ten waiting trucks, zero workers and independent manpower recovery. Further F02 integration belongs to G05; the separately accepted D03 definition does not supply its downstream implementation evidence.

During G02 draft review the Game Designer confirmed that section 10.2's existing one-person-per-second handling rate also applies to external manpower: one completed exit per second per stopped vehicle, with seated supplier crew excluded. Passengers remain aboard until their own exit completes, then walk independently; each incoming place converts only at actual F08 arrival. Two vehicles handle concurrently on their own schedules. Admission remains occupied through the last arrival and physical vehicle clearance. This corrects simultaneous exit evidence; it introduces no new rate or general staffing scope.

## Design gates and status

| Gate | Closure evidence | Consequence until resolved |
| --- | --- | --- |
| D01 Presentation, platform and full-map performance | [Measured options and bounded full-size data/query evidence](d01_measured_options.md) are an engineering proposal; the gate remains open. Game Designer confirms presentation and target platform/hardware and records measurable readability, interaction, generation/loading and operating expectations using measured prototype results where useful. | Measured prototypes allowed. Production world presentation is not ready. Do not assume existing renderer/window defaults settle this decision. |
| D02 Exact cover-capacity fairness metric — definition resolved | Game Designer accepted the [decision v0.1 and explicit reference fixtures](d02_cover_fairness.md) in merged PR #52 on 26 October 2026; issue #43 is closed for the definition gate. | G10 retains actual final-world validation and A17/A18. Mathematical fixtures alone do not pass gameplay. |
| D03 People and capacity across lifecycles — definition resolved | The Game Designer accepted the [decision v0.1, lifecycle matrix and exact reference fixtures](d03_people_capacity.md), dated 26 October 2026, in merged PR #53; issue #44 is closed for the definition gate. They govern earlier ambiguous GDD membership/admission wording: all living non-exempt military members plus incoming, independent rear/local/roster/hull/service capacities, physical blockage and once-only handoffs. | G12/G15/G16/G23/G26/G27/G29/G32 retain implementation and complete downstream gameplay evidence; the definition does not pass G02 native acceptance or A01/A04/A20/A25/A41/A45. |

These gates describe design outcomes, not software architecture. Raise concrete contradictions and measured constraints to the Game Designer. Do not introduce new gameplay rules to make a gate disappear.

## Baseline status

User-established scope and proposed numerical defaults remain distinct under GDD sections 1.1 and 1.2. v0.2.1 corrects project sequencing and records unresolved gates; it does not validate balance, change combat eligibility or claim any acceptance scenario has run. Further numerical or gameplay revisions must identify the changed rule, reason, affected scenarios and required revalidation.

## Production-boundary decision — 26 October 2026

The [Game Designer decision on G04 issue 12](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6432972072) is recorded as governing [GDD23.6](game_design_document.md#236-production-targets-output-promises-and-heavy-output-staging---26-october-2026). This replaces the three open questions in the [G04 plan](g04_production_plan.md#resolved-production-boundaries-and-linked-continuations); it is a contract decision, not implementation evidence or runtime release.

- Stock targets use eligible deposited, uncommitted rear stock A separately from otherwise uncommitted active-batch and valid internal-relocation coverage C. Internal source reservation/pickup/deposit changes A→C→A once. A+C admits complete batches with overshoot, never supplies remote ingredients or makes promises/carries usable goods.
- Capacity/filter edits cannot invalidate an active output promise; refuse the whole edit with its claim owner. Access loss pauses work without losing consumed inputs/progress/promise. Invalid physical completion waits with no goods; legal completion creates once.
- G04 proves actual heavy manufacture/admission/blocked occupied bays; G07 clears those same manufactured hulls using real people/fuel/parking; G12 completes real heavy collection/manifests and G13 route/fuel travel. Complete later cases remain required. Accepted D03 rear 8 admission always applies to rear-owned manufactured hulls; planned military destination is no bypass, and accepted Fleet Transfer adds military admission while retaining rear admission until actual HQ handoff/destruction.

The GDD6.1 sentence allowing a rear-or-planned-military slot was reconciled to D03. The [equipment-wording correction](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6432988178) confirms catalogue equipment remains unchanged: hulls include listed integral gun/mount mechanisms, without loose spare weapons, crew, passengers, fuel or ammunition. The section 23.6 table and G04 plan retain observable counterexamples and linked later acceptance owners. G03 foundation is accepted in PR #54; G04 production, full A05/M0, G08 and outstanding D01/Windows verification are not passed by this document.
