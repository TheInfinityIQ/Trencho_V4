# Design brief

Updated 26 October 2026. Project: Trencho V4; repository: Trencho_V4. The Game Designer directs scope. The [Game Design Document](game_design_document.md) contains the v0.2 gameplay baseline plus the governing [v0.2.1 planning amendment](game_design_document.md#23-project-planning-amendment-v021---25-october-2026). Read [AGENTS.md](../AGENTS.md) and [foundation decisions](foundation.md) for repository and engineering guidance.

## Established design scope

Trencho V4 is a logistics management game supplying an autonomous battlefield. The player controls acquisition, rear facilities, staffing, production, training, shipment composition, dispatch and doctrine. The military AI controls organization, equipment issue, operations, tactical movement, engineering and combat. The player must be able to trace battlefield capability and failures back to physical people, supply and industrial decisions.

- Physical continuity: reservations do not move goods; production does not deliver them; HQ stock does not refill a distant unit. People have one identity, location and exclusive duty, competing between labour, training, crew duties and military service.
- Delegated execution: Commander, Company, Platoon, Squad and individual roles retain distinct responsibilities. Orders travel down, observations and inability reports travel up. Vehicle and service elements use real personnel.
- Core nodes: acquisition; manpower; production and training; internal logistics; dispatch and transport; HQ logistics; military organization; command and operations; objectives and economy; campaign and progression.
- Campaign: five-position tug-of-war, temporary engagement access and persistent experience/card unlocks.
- Current target includes troop transport, resource transport, technical, cannon-equipped APC carrying one squad plus crew, and tank.
- Engineers build infrastructure, defensive structures and bridges using Building Materials. Explosives supplies mines, demolition and shell manufacture through a simplified common chain.
- Procedural battlefields are 4,000 by 6,000 metres with one-metre tiles and one opposing HQ at each end. Natural terrain must also provide balanced, class-valid access. Rivers, lakes/ponds, forests, rocks, mountains, towns, farms, fields and swamp affect movement and observation.
- No neutral NPCs or third-party battlefield factions in this edition. The GDD also excludes multiplayer, aircraft, boats and other explicitly listed future systems.

## Proposed gameplay defaults

GDD section 1.2 identifies exact values, formulas, recipes, crew arrangements, caps, timings and generation thresholds as proposed defaults for review and playtesting. They give implementation a concrete baseline; they are not validated balance or evidence of a running game. Numerical changes require a recorded design revision rather than an undocumented substitute.

The GDD's overhead presentation, pause/1x/2x controls, operational travel distances and approximately 30-50 simulation-minute engagement target guide acceptance. Their details must be evaluated through observation. Do not compress the world or ranges to make an early demonstration appear complete.

## Delivery and open gates

Milestones progress from rear economy and people through full procedural world, operational transport, autonomous infantry, engineering, full vehicles, support capabilities and a persistent campaign. The entire requested vehicle/engineering/procedural scope remains the current target.

The v0.2.1 amendment corrects sequencing: M3 closes on sustained contested objectives, requisition, retreat and resupply; full HQ outcomes are tested from M5 onward without changing assault eligibility. Early foundation evidence is separated from later casualty, firing and card-unlock integration. All complete final acceptance cases remain required. Each of the four map families needs its own validated full-size fallback.

Gate status is recorded in [design decisions](design_decisions.md). D02's [cover-capacity definition](d02_cover_fairness.md) is accepted and merged; G10 retains actual final-world validation. D03's adopted [people/capacity contract and matrix](d03_people_capacity.md) are under canonical documentation review, with downstream gameplay evidence still required. D01 presentation/platform/full-map performance remains open. Measured prototypes and independent foundation work may proceed; production world presentation waits for its gate.

## Engineering context

Godot 4.7.2 standard edition is pinned; use GDScript by default. The entry scene now hosts the bounded [G01 accounting fixture](g01_identity.md). Its UI and canvas scaling do not settle production world presentation. Compatibility rendering and window dimensions remain reversible bootstrap decisions, and no gameplay architecture, storage format or export target is prescribed by this design. For substantive changes, state the intended behaviour and acceptance criteria, then choose implementation details within [AGENTS.md](../AGENTS.md). Begin with the scoped task in [developer onboarding](developer_onboarding.md).
