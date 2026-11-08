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

## Automatic starter staffing — accepted 7 November 2026

Dawson requested that every newly completed workplace have a default staffing request so the player need not configure its first worker count manually. This is an accepted requirement, not a claim of implementation. The lead owns its increment after the current Construction Office truck work.

Designer starting defaults are one worker for each Receiving Bay, Workshop, Munitions Workshop, Materials Plant, Support Workshop and Logistics Centre; one eligible instructor for each School; two workers for each Vehicle Works and Construction Office. Storage Depots and Vehicle Parks request zero resident workers because their current functions have no resident staffing duty. These are starting requests, not maximum capacities or grants of people or qualifications.

Requests use the existing shared workforce, eligibility, priorities and physical reporting rules. Requested, incoming and present staff remain distinct. The player may change the count or priority, including setting it to zero. Apply the default once on new facility completion; do not restore it after player edits, recipe changes, pause/resume or enabling a facility, and do not overwrite existing facilities' settings. Haulers, students and vehicle crews retain their separate duties; no person may fill two jobs at once. Explain unmet requests and qualification shortages clearly.

Source: Dawson's direct Game Designer chat instruction on 7 November: “every building should have a default number of people request to work it once it's build so the player doesn't automatically need to do that.” Exact initial counts above are the Designer's implementation baseline, conveyed to the lead in the same discussion; engineering interfaces and assignment remain lead-owned.

## Full 3D direction — 7 November 2026

Dawson requested a “full3D game overhaul”: a third-person game with a toggleable first-person view for the user, and an RTS-style battlefield camera with zoom. The lead relayed this direct instruction to the Game Designer on 7 November. This supersedes the earlier 2D overhead presentation direction; it does not establish an implemented or accepted 3D build. Preserve the existing main revision `5b3e3aac1a01e16e8f1b4295c00742515efae8fd` as the pre-migration reference. The lead prepares the migration plan before code and owns engineering choices.

First and third person are views of the same rear-base manager character. Toggle without moving, replacing or duplicating that character, changing duties or resetting progress. Walking, looking, selecting facilities and using management controls must remain understandable. Menus and construction mode must provide a usable pointer without unintended walking, looking or placement. Placement previews show actual footprint, entrance and validity in the 3D world before commitment. Camera position is not the character's physical location.

The battlefield uses a separate RTS observation camera with pan and zoom, readable terrain, units, objectives and supply stages. It retains existing inspection and information restrictions. A camera change does not grant direct military orders, player combat, vehicle driving or additional intelligence. Switching areas or perspectives preserves time, identities, selection where valid, cargo, work and orders; inactive areas retain their intended progression, and global pause/speed controls retain their meaning.

The first slice should show the actual normal empty-field opening in 3D: one manager character, 2,500 requisition, 500 actual Building Materials, Supply Table/arrival point and no free workers, workshops or vehicles. Demonstrate first/third-person movement and toggle, an existing management interaction and an uncommitted construction preview, plus the separate 3D battlefield observation camera. Use coherent visible 3D assets for the claimed slice; previous 2D screenshots or asset sheets do not prove this result. Current-build screenshots and a brief scoped camera/control observation must distinguish normal opening from any arranged demonstration. Do not require a broad gameplay or performance campaign for this increment.

The full overhaul must carry existing construction, staffing, acquisition, manufacture, training, vehicles, physical supply and autonomous battlefield behaviour into the 3D presentation with real scale, footprints, custody and ownership intact. Preserve the 4,000 by 6,000 metre battlefield, automatic Army-request fulfilment, finite fuel, exclusive workers and explicit debug exceptions. Existing gameplay and performance acceptance gaps remain open. Full 3D readiness requires evidence from the integrated build, not completion of the first camera slice.

Two costly scope choices remain unrequested: physically entering the battlefield as the manager, and multi-level gameplay such as climbing, jumping, interiors or new elevation-based combat rules. Designer recommendation for the initial migration is rear-only character access and existing ground-level movement/terrain rules rendered in 3D. Treat those as bounded migration defaults, not a permanent exclusion; bring any required expansion to Dawson as a concrete gameplay decision before implementing it. No camera request alone authorizes new content, multiplayer or destructible-world systems.

### Accepted 3D art direction — 7 November 2026

Dawson selected “Cohesive stylized3D, with readable detail and a lower asset/performance cost” in the lead chat. Stylized 3D is now the accepted direction, replacing the pending style choice in the initial migration plan. Keep people, facilities, vehicles and terrain visually consistent and readable in the first-person, third-person and RTS views. This choice does not guarantee performance or approve individual provisional models, poses, animations or licences; those still require actual asset inspection and current-build visual evidence. It does not expand gameplay scope.
