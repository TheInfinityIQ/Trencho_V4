# Design brief

Updated 9 November 2026. Read the [current GDD](game_design_document.md) for the consolidated vision and player-facing rules, [playable delivery](playable_delivery.md) for the next outcomes and [team workflow](team_workflow.md) for ownership. This brief retains decision provenance and supporting detail; it is no longer necessary to combine it with the older 5 November GDD to discover the accepted 3D and staffing rules.

Trencho is a factory-building and logistics-management game supporting a war between two autonomous RTS commanders. Start as a WASD-controlled rear character, build the factory/logistics area, buy resources and workers, allocate labour and choose production. Workers perform physical work; the Logistics Centre automatically fulfils army supply requests through real transport to the friendly military base (HQ). The friendly commander arranges onward supply and operates its army against the opposing autonomous commander.

The challenge is building an effective base and allocating scarce people and resources. Ordinary UI actions should be easy to find and perform. The player does not manually command soldiers or compose every routine supply trip.

## Approved opening and core rules

- Development opening9November: character,2,500 requisition,500 actual Building Materials and four real assigned/present unloaders at the prebuilt south-road apron/Table. No free workshops or player trucks. This overrides the former zero-worker start.
- Buy eight untrained workers for140 including transport; development Confirm creates the physical supplier vehicle immediately, replacing the earlier90-second offscreen wait. Actual driving, disembarkation and arrival still occur. The shared pool supplies construction, hauling, production, training and crew duties.
- Workers and materials must actually reach their work. Goods at HQ do not instantly appear in a remote weapon. No duplicate people, hidden replenishment or forced battlefield result.
- Building Materials and Explosives are manufactured. Production inputs and onward shipments use actual available stock and physical handling.
- Both areas must continue their applicable work while hidden; waiting in one area must not silently stop the other. Pause and speed controls describe player-visible behaviour, not a prescribed scheduling implementation.

## Delivery and wider scope

Finish the ordinary self-sustaining factory, first useful automatic army delivery and repeat replenishment. Keep one representative full-size Farmland scenario for this demo. All five vehicle roles, engineering, medical/support systems, four procedural families, enemy logistics, campaign and persistence remain wider-game requirements.

Source-observed implementation and verification belong in [implemented features](implemented_features.json) and [prototype completion](prototype_completion.json). Closed foundation issues do not establish completed playable milestones.

## Design and engineering responsibility

The Game Designer owns vision, gameplay scope, meaningful choices and observable requisites. The Lead Developer owns logistics, shared state/interfaces, routine UI, technical integration, checks and publication. Under Dawson's12November authorization, the Battlefield Developer owns agreed battlefield3D presentation files in an isolated copy; Lead retains shared entry/session/UI adapters. This supersedes the sole-programmer rule only for these two developers; retired developers remain inactive. Earlier consultant or parallel-development assignments do not reactivate through this brief. Current ownership is recorded in [team workflow](team_workflow.md) and [team integration state](team_integration_state.json).

The old detailed [v0.2 specification](reference/gameplay_specification_v0_2.md) preserves catalogue values and historical rationale. It is not the current GDD or an instruction to retain old clocks, manual routine dispatch, prebuilt starting assets or archived assignments. No numerical rebalance is made by this documentation revision.

Gameplay features take priority over polishing and benchmarks under Dawson's 5 November instruction. Preserve known limits and the eventual 60 FPS target; fix defects that prevent the current gameplay task or corrupt state. Godot version, language, source ownership, maps and development workflows remain engineering documentation and AGENTS.md responsibilities.

## Automatic starter staffing — accepted 7 November 2026

Dawson requested that every newly completed workplace have a default staffing request so the player need not configure its first worker count manually. This section records the accepted requirement; current implementation and verification belong in the delivery records, not an old task-sequencing note.

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

### Manager occupation and 3D construction — accepted 7 November 2026

In the active 3D session, a proposed solid construction footprint must not overlap the manager's actual physical body. Use the current body and rotated footprint for preview, world placement and numeric placement, including commands made while the rear view is hidden. Camera position and visual model size do not define this occupied space. Reject with “Move away before placing here,” preserving the draft and orientation without spending materials, creating a site or moving the manager automatically. This is physical occupation protection, not a new reach or proximity restriction. The normal 2D entry has no hidden 3D body blocker. Existing construction validation and economic authority remain in force.

## Manager contact with vehicles — accepted expectation, 8 November 2026; implementation deferred

Source: Game Designer decision relayed by Lead Developer in Trencho V4 Developer chat (01a199a0-f08e-7f23-947f-62655a9ed233), 8 November 2026. This section records observable behavior; architecture, engine feasibility, full 3D02 and FPS acceptance remain engineering work.

While gameplay runs, actual contact may passively displace the same grounded canonical manager during management, modal decisions, battlefield view, focus loss, recapture wait and building placement. User movement/look remain suppressed. Contact must not capture controls, close UI, switch area, reset a view or replace the manager. Returning to the rear preserves the actual resolved pose.

Global Pause freezes manager pose/contact. Valid overlaps introduced by paused preparation resolve on resume under the selected grounded response. Placement preview and commit use the updated actual manager occupation; existing rejection without spending still applies, with no moved target or stale commit.

Apply the same policy to vehicle roles as physical integration arrives, with appropriate geometry. Do not introduce damage/crushing, riding/platform carry/climbing, general traffic priority/pathfinding, player driving or arbitrary safe-location teleportation. Grounded obstruction/displacement does not place the manager on a roof/deck.

Additional Designer compromise, 8 November 2026, relayed by the same Lead chat: only when proposed actual vehicle travel cannot leave a valid grounded manager position through local contact resolution, its EXISTING movement activity holds BEFORE committing that obstructing travel. Show a usable physical-obstruction reason. Keep the same ID, cargo, crew, destination and remaining work; user controls remain suppressed as applicable, with no UI/view/capture/global-pause change. Resume that same activity on an actual clearance event. Account for the waiting interval instead of jumping to its old schedule. Zero distance incurs no distance-fuel charge; preserve already-defined idle costs and invent none. Global Pause freezes movement, contact and hold progression. This narrow hold supersedes the earlier no-yield/no-route-mutation exclusion only to this extent; it is not a new traffic policy or rollback.

An already-committed initial/restore appearance overlap is separate: a movement hold cannot undo it. A genuinely irreducible appearance case still requires a concrete Lead/Designer decision. If a precommit guard is not boundedly feasible, retain query-only/partial integration and report that limitation instead of claiming resolution.

Subsequent Designer priority decision, 8 November: retain the current partial, camera/picking-only vehicle representation and defer physical manager contact rather than delay the playable factory loop with a joint traffic/restore solution. The proposed broader yield-before-any-contact and delayed commissioning policies were not adopted. Initial/commissioned/restored identity, goods, completed work and pose rules remain unchanged. Revisit a coherent feasible contact policy, including initial/restore overlap, before enabling solidity; the earlier isolated response does not establish that outcome.

## Original vision reaffirmed and GDD consolidated — 9 November 2026

Dawson requested review against the original vision: the player builds a factory/logistics area and sends materials to a military base for an autonomous RTS commander to battle another autonomous commander. The [GDD](game_design_document.md) now states that loop and division of responsibility explicitly, incorporating the accepted opening, automatic starter staffing, request-driven physical shipping, stylized first/third-person rear and RTS observation view. The player's meaningful work is industry and logistics; military organization, operations, tactics, onward supply and combat remain autonomous. No direct military-command controls, second simulated enemy factory, balance revision or claim of completed gameplay follows from this consolidation. The first demo still needs the connected ordinary factory, useful delivery and repeat-supply outcomes.

## Current prototype direction — 9 November 2026

Dawson requested combined explicit order confirmation, immediate visible
supplier convoys on the road south of the buildable rear, a prebuilt unloading
apron with four actual assigned workers, an event-owned order cooldown until
the last truck finishes handover and starts leaving, and top-down grid building.
The current [contract/diagram](development_convoys_grid.md) records engineering
scope. Prior60/90-second offscreen waits/zero-worker opening are historical for
this development flow; prices and physical custody remain real.

Dawson also directed that the GDD guide the game's idea/vibe rather than operate
as a rigid prototype rule book. Lead owns pragmatic reversible choices; Designer
reviews coherence and progress toward the factory/logistics/autonomous-war loop.
Do not invent a human approval gate for routine implementation details.
