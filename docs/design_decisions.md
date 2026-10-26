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

## Design gates and status

| Gate | Closure evidence | Consequence until resolved |
| --- | --- | --- |
| D01 Presentation, platform and full-map performance | Game Designer confirms presentation and target platform/hardware and records measurable readability, interaction, generation/loading and operating expectations using measured prototype results where useful. | Measured prototypes allowed. Production world presentation is not ready. Do not assume existing renderer/window defaults settle this decision. |
| D02 Exact cover-capacity fairness metric — definition resolved | Game Designer accepted the [decision v0.1 and explicit reference fixtures](d02_cover_fairness.md) in merged PR #52 on 26 October 2026; issue #43 is closed for the definition gate. | G10 retains actual final-world validation and A17/A18. Mathematical fixtures alone do not pass gameplay. |
| D03 People and capacity across lifecycles — documentation review | The adopted [decision v0.1, lifecycle matrix and exact reference fixtures](d03_people_capacity.md), dated 26 October 2026, govern earlier ambiguous GDD membership/admission wording: all living non-exempt military members plus incoming, independent rear/local/roster/hull/service capacities, physical blockage and once-only handoffs. D03 remains open until canonical documentation is accepted and merged. | G12/G15/G16/G23/G26/G27/G29/G32 retain implementation and complete downstream gameplay evidence; the definition does not pass G02 native acceptance or A01/A04/A20/A25/A41/A45. |

These gates describe design outcomes, not software architecture. Raise concrete contradictions and measured constraints to the Game Designer. Do not introduce new gameplay rules to make a gate disappear.

## Baseline status

User-established scope and proposed numerical defaults remain distinct under GDD sections 1.1 and 1.2. v0.2.1 corrects project sequencing and records unresolved gates; it does not validate balance, change combat eligibility or claim any acceptance scenario has run. Further numerical or gameplay revisions must identify the changed rule, reason, affected scenarios and required revalidation.
