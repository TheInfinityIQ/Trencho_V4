# Design brief

Updated 5 November 2026. Read the [current GDD](game_design_document.md) for vision and player-facing rules, [playable delivery](playable_delivery.md) for the next outcomes and [team workflow](team_workflow.md) for ownership.

Trencho is a base-building and worker-management game supplying an autonomous battlefield. Start as a WASD-controlled rear character, place buildings, buy resources and workers, allocate labour and choose production. Workers perform physical work; the Logistics Centre automatically fulfils army supply requests through real transport to HQ. The army arranges onward supply and its own operations.

The challenge is building an effective base and allocating scarce people and resources. Ordinary UI actions should be easy to find and perform. The player does not manually command soldiers or compose every routine supply trip.

## Approved opening and core rules

- Character, 2,500 requisition, 500 Building Materials, no hired workers/workshops, and a Supply Table/arrival point at the field's edge.
- Buy eight untrained workers for 140 requisition including transport; arrival is 90 seconds, followed by actual disembarkation. The shared pool supplies construction, hauling, production, training and crew duties.
- Workers and materials must actually reach their work. Goods at HQ do not instantly appear in a remote weapon. No duplicate people, hidden replenishment or forced battlefield result.
- Building Materials and Explosives are manufactured. Production inputs and onward shipments use actual available stock and physical handling.
- Both areas must continue their applicable work while hidden; waiting in one area must not silently stop the other. Pause and speed controls describe player-visible behaviour, not a prescribed scheduling implementation.

## Delivery and wider scope

Finish the ordinary self-sustaining factory, first useful automatic army delivery and repeat replenishment. Keep one representative full-size Farmland scenario for this demo. All five vehicle roles, engineering, medical/support systems, four procedural families, enemy logistics, campaign and persistence remain wider-game requirements.

Source-observed implementation and verification belong in [implemented features](implemented_features.json) and [prototype completion](prototype_completion.json). Closed foundation issues do not establish completed playable milestones.

## Design and engineering responsibility

The Game Designer owns vision, gameplay scope, meaningful choices and observable requisites. The Developer owns systems, technical decisions, testing, integration and publication. UI/UX owns interaction/menu design in coordination with those roles. Current participants are recorded in [team integration state](team_integration_state.json).

The old detailed [v0.2 specification](reference/gameplay_specification_v0_2.md) preserves catalogue values and historical rationale. It is not the current GDD or an instruction to retain old clocks, manual routine dispatch, prebuilt starting assets or archived assignments. No numerical rebalance is made by this documentation revision.

Gameplay features take priority over polishing and benchmarks under Dawson's 5 November instruction. Preserve known limits and the eventual 60 FPS target; fix defects that prevent the current gameplay task or corrupt state. Godot version, language, source ownership, maps and development workflows remain engineering documentation and AGENTS.md responsibilities.
