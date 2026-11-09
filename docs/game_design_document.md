# Trencho V4 — Game Design Document

Updated 9 November 2026. Owner: Game Designer. Human direction from Dawson governs. This document consolidates the original factory-to-autonomous-war vision and accepted later gameplay decisions. It describes the intended player experience, gameplay rules and observable outcomes; it does not certify the current build.

The Developer owns creating the systems, technical specifications, testing, integration and publication. Current progress belongs in [implemented features](implemented_features.json), [prototype completion](prototype_completion.json) and [GitHub delivery #83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83). The [detailed v0.2 specification](reference/gameplay_specification_v0_2.md) is preserved as a historical catalogue/balance reference; its implementation prescriptions and superseded instructions do not govern new work.

## 1. The game we are making

Trencho is a factory-building and logistics-management game supporting a war between two autonomous RTS commanders. The player starts in an empty rear field as a controllable character, builds a factory and logistics area, hires workers, buys raw resources and turns them into materials, equipment and supplies. Physical deliveries carry that output to the friendly military base, referred to as HQ throughout this document.

The friendly commander organizes and operates its army against the opposing autonomous commander. Both commanders decide how their actual forces pursue objectives, move, fight, use transport and support, resupply, hold or withdraw. The player's central influence is the industrial capacity and supply they provide. Building a productive base and seeing its output make a difference to that autonomous conflict is the core experience.

| Player responsibility | Autonomous military responsibility |
| --- | --- |
| Rear layout, buildings, purchases, worker priorities, production targets and training commitments | Force organization, equipment issue and military assignments after arrival |
| Provide available goods, handlers and suitable rear transport for automatic army-request fulfilment | Report genuine needs, receive supplies at HQ and arrange onward supply |
| Observe shortages and outcomes, then adapt industrial capacity and priorities | Choose operational objectives and tactical actions against the opposing commander |

The battlefield's RTS camera is an observation and inspection view. It does not make the player the military commander or require direct soldier orders to keep the war progressing.

The pleasure comes from watching a base become productive, finding its bottlenecks and seeing the army benefit from the player's decisions. A lack of ammunition, fuel, trained crew or a safe supply route should have an understandable consequence. Building and workforce choices provide the complexity; operating menus should be straightforward.

## 2. Design pillars

- **Build the base.** Placement, access, storage, expansion and production capacity matter.
- **People are the limiting resource.** Builders, haulers, operators, students, instructors, drivers and military recruits compete for actual people.
- **Supply is physical.** Goods must be made, handled, carried and received. A reservation or a truck passing nearby is not a refill.
- **Delegate execution.** The player sets production and labour priorities; workers and military commanders carry out the work.
- **Connect industry to the war.** Factory output reaches the military base and actual recipients; the two commanders' decisions and the resulting combat determine its consequences.
- **Explain cause and consequence.** Show what is missing, what is waiting and which player decision could help.

## 3. Core player loop

1. Move around the rear base with WASD and inspect the field.
2. Use the Supply Table to purchase workers and raw resources.
3. Place buildings through a clear build menu.
4. Allocate construction labour from the shared worker pool, choose production targets and adjust priorities. Newly completed workplaces request their default staff automatically.
5. Workers construct buildings, collect ingredients and manufacture goods.
6. The Logistics Centre automatically fulfils actual army supply requests through physical transport to HQ. Military logistics handles onward supply and issue.
7. The friendly commander equips and operates its actual forces against the opposing commander, arranging military transport and further supply.
8. Observe what the armies do, where supply or capability limits them, and how battlefield control affects requisition income.
9. Reinvest income and adapt the factory, workforce and production to meet later needs in the same engagement.

The player should be able to complete this loop through ordinary controls. Diagnostics, fabricated shortages, inventory resets and forced combat are not substitutes.

For example, the player purchases ingredients and chooses rifle and ammunition production in the appropriate workshops. Workers manufacture the goods; the Logistics Centre fulfils genuine military requests with available output through physical delivery to HQ. Military logistics equips or resupplies actual recipients, and the commander decides how to use the resulting capability. The player manages the production bottleneck rather than directing each haul, shipment or attack.

## 4. Approved opening and controls

Development opening override — 9 November 2026: start with the same manager,
2,500 requisition and 500 actual Building Materials, plus four real untrained
workers already assigned and present at the prebuilt south unloading apron.
They belong to the shared workforce and can be reassigned. The Supply Table,
storage and arrival access sit beside the road outside the buildable area. No
workshops, production buildings or player-owned trucks are granted. This latest
prototype request replaces the prior no-hired-workers opening.

The first workers and first construction must be obtainable from this opening. Initial purchase access cannot require a Receiving Bay that has not been built. Purchased ordinary workers can build using the declared materials without first constructing an office or materials producer. The character is not a hidden source of free labour, qualifications or crew.

The game uses cohesive stylized 3D. WASD moves the rear manager, with toggleable first- and third-person views of the same character. Switching views preserves that character's actual position and the current session. Camera position is not character position, and the manager is separate from the hired workforce. The initial 3D scope keeps the character in the rear; battlefield character access, jumping, climbing and interiors are not implied by the camera choice.

The build menu uses a top-down RTS camera and visible one-metre grid, edge-snapped footprint preview, rotation, explicit Confirm placement and cancellation, with readable cost, footprint, entrance and access reasons. A solid building cannot be placed over the manager's actual body: reject without spending or moving the character or the requested building location. Opening management or construction controls must provide a usable pointer without unintended movement, looking or placement.

The battlefield has a separate RTS observation camera with pan, zoom and inspection. Close zoom should make represented people and vehicles readable; distant views should retain useful strategic cues. It does not grant direct military orders, target selection, player combat, vehicle driving or additional knowledge of unseen enemies. Both perspectives and areas preserve people, goods, work, orders and progress.

Pause, 1x and 2x remain accessible. Both rear and battlefield must continue their applicable activity while hidden. Waiting or planning in one area must not silently freeze the other. Pause stops timed gameplay while allowing inspection and management. The Developer chooses how to deliver these behaviours; the GDD does not prescribe a shared clock or scheduling mechanism.

### Prototype ordering and interactions — 9 November 2026

E on the current Supply Table/building opens its appropriate existing menu.
Raw quantities and an optional eight-person batch are draft selections until
one combined Confirm order validates and pays for the whole purchase. Prices,
per-vehicle transport charges and finite cargo/passenger capacity remain real.
Supplier trucks appear immediately at the south road entry and physically drive
to the prebuilt drop-off. Four starting unloaders handle freight; purchased
people disembark and arrive before joining the labour pool. Pause freezes that
progress. One receiving convoy is permitted at a time during development;
ordering reopens from the final truck's actual completed-handover/departure-start
event while empty trucks continue driving out. No extra countdown is added.

The GDD is a reference for the game's idea and feel, not an inflexible prototype
rule book (Dawson's 9 November direction). The priority is approachable factory
building, satisfying physical logistics and visible support for an autonomous
war. Lead may choose reversible prototype simplifications; raise only material
changes to that experience or player responsibilities. Latest human instructions
and real tool restrictions still govern. Implementation/verification records
state what actually works; these design paragraphs do not certify completion.

## 5. Workers, jobs and training

The existing standard worker order brings eight untrained people for 120 requisition plus a 20 transport fee, with immediate supplier-truck creation in the development opening instead of the earlier offscreen 90-second wait. The trucks physically drive, stop and unload; purchased people join the pool through actual arrival and disembarkation. The supplier's driver and carrier leave. The existing rear capacity is 120, including relevant incoming and returning commitments.

The player requests worker counts and priorities for jobs and buildings. Routine assignment should not require selecting every person by name. Show available, assigned, present, arriving and requested people separately. An unmet target is a visible vacancy, not a worker who can already contribute.

Every newly completed workplace applies a starting staffing request once, so the player does not have to configure its first worker count manually:

| Facility | Starting request |
| --- | --- |
| Receiving Bay, Workshop, Munitions Workshop, Materials Plant, Support Workshop, Logistics Centre | One worker each |
| Vehicle Works, Construction Office | Two workers each |
| School | One eligible instructor |
| Storage Depot, Vehicle Park | Zero resident workers; workers visit for the relevant tasks |

These are requests, not free people, qualifications or maximum capacities. Available eligible workers fill them through the existing shared pool and physical reporting rules; shortages remain visible. The player can change the count or priority, including setting it to zero. Opening a menu, changing a recipe, pausing or enabling a building must not restore the default or overwrite a deliberate edit. Haulers, students and vehicle crews retain their separate exclusive duties.

A person performs one role at a time. Reassignment must finish or safely put down an existing carry. Training, crew duty and military commitment remove that person from incompatible industrial work. Qualifications persist, but do not grant equipment or let one person fill several stations.

Training turns available people into useful capability. Basic infantry, engineers, medics, heavy-weapons specialists, artillery specialists, drone operators, marksmen and vehicle crew remain in scope. Courses need real students, instructors, facilities and time. An instructor-recovery route must prevent a rear with no trained people from becoming permanently stuck.

The meaningful choice is how much labour to retain in industry, invest in training or commit to the army. Routine goods shipping must not silently conscript the workforce.

## 6. Resources, construction and production

Raw inputs include Metal, Components, Gunpowder, Timber, Textiles, Electronics, Fuel, Medical Compound and Battery Cells. Purchases have a clear total price, transport fee, arrival state and receiving requirement. Resource objectives earn requisition; they do not create material stock at the base.

Building Materials and Explosives are manufactured. They are not directly purchasable substitutes for production. Exact existing recipes, costs, weights, capacities and work values remain in the detailed reference and implementation; this revision makes no numerical rebalance.

Placeable facilities cover receiving, storage, workshops, munitions, training, logistics, support equipment, vehicle manufacture, vehicle parking, construction management and building-material production. The Supply Table/arrival access is the minimal fixed opening provision, not a concealed working base.

Buildings need usable space and access. Materials must reach a construction site, workers must actually build it, and cancellation has a visible consequence. Construction and production cannot erase goods to solve congestion.

The player chooses a recipe, output target and staffing priority. Workers fetch eligible available ingredients automatically and perform real work. Missing inputs, labour, access or output space explain why a building is waiting. The player should not need to order every routine ingredient carry manually. Changing a recipe or cancelling consumed work must clearly explain any loss before commitment.

## 7. Logistics Centre, HQ and army requests

The Logistics Centre connects the player's factory and logistics area to the friendly military base. It automatically fulfils **army supply requests**, as Dawson selected on 1 November 2026. The player decides what to produce and how to allocate resources, staff and transport capacity; normal supply delivery does not require composing and departing every manifest. Military demand identifies the recipients; the commanders decide how to use the delivered capability.

An army request names the needed item, quantity, destination, urgency and consequence of the shortage. Its display distinguishes stock already at the destination, remaining need, supply committed or in transit and supplies actually received. The same need must not generate duplicate shipments.

Actual staff and vehicles collect, load, travel and unload. Missing goods, handlers, qualified crew, fuel, transport, a safe route or receiving space produce an understandable waiting state. Logistics may send a useful capacity-valid shipment without waiting to fill a whole truck. It does not create goods or silently change the player's production choices.

HQ receipt is different from frontline receipt. The army arranges onward transport, rendezvous and local issue so supplies physically reach the people or vehicles that need them. A remote tank does not refill merely because shells arrived at HQ.

Ordinary supply vehicles and their returning crew remain distinct from a permanent military transfer. The player must understand when a commitment removes people or vehicles from the rear. A cancellation cannot erase already loaded or departed freight.

Later consumption or changed operations can create new demand. The same transport can return and make later useful trips. Forecasting should eventually consider the actual operation and delivery lead time, rather than waiting for every weapon to become empty.

## 8. Autonomous army and battlefield consequences

There are two opposing autonomous commanders, each operating a military hierarchy. Commander, Company, Platoon, Squad, vehicle elements and individual roles retain distinct responsibilities. Orders travel down; observations, progress, shortages and inability reports travel up. Decisions use delivered information and actual capability, not hidden enemy inventory or knowledge supplied by the player's camera.

Each commander pursues feasible objectives, coordinates support, maintains supply and fallback routes, and holds or withdraws when it cannot continue safely. The friendly commander must act without the player issuing tactical orders. The opposing commander must operate and react through its own information, resources and actual forces. Supply can restore a lost capability; it does not guarantee a successful attack. Real leadership, strength, ammunition, morale, cohesion, terrain and enemy capability still matter.

Capturing and contesting resources requires actual eligible forces. Carried passengers do not capture through a vehicle. Uncontested ownership earns income; contested ground loses that economic benefit. These results should make the cost of a shortage or the value of a successful supply decision visible.

The opponent follows the same physical constraints. Its industry may be represented by paid off-map packages; a second fully simulated player-style factory is not required. Its people and goods must still arrive and be received. No free frontline waves, hidden combat bonuses, attacks triggered solely to reward a player shipment or forced outcomes are authorized.

## 9. Vehicles, engineering and support

All five vehicle roles remain part of the intended game: resource transport, troop transport, technical, APC and tank. Vehicles need the appropriate actual crew, fuel, capacity, route and equipment. Ammunition and fuel resupply are general vehicle requirements, not an APC-only rule. A vehicle's loaded ammunition counts once, and its crew cannot simultaneously work elsewhere.

Engineers use real tools and supplies to build defences and forward services, prepare or restore crossings, clear mines and carry out authorized denial. Bridges have meaningful movement and load limits. A damaged route can interrupt supply and make repair, rerouting or withdrawal necessary. Engineers do not undertake a project merely because materials exist.

Vehicle damage, repair, towing and recovery preserve the same hull and its contents. Wounded soldiers need actual medics, supplies, transport and recovery capacity. Mortars, artillery, marksmen and drones provide their distinct support roles through real crew, equipment, observation and supply. A training course or manufactured item alone does not establish a functioning support system.

These are wider-game requirements. Their backend presence must not be presented as a connected player experience until the normal game uses them.

Manager contact with vehicles remains a deferred physical-interaction requirement, not a prerequisite for the next factory interaction. The accepted target is consistent grounded contact while time runs, without damage, crushing, riding or arbitrary relocation; Pause freezes the character. If local contact cannot leave a valid grounded position, the vehicle's existing activity may wait before the obstructing movement, explain why and resume the same job when clear, preserving cargo, crew, remaining work and real waiting time without charging distance fuel for no movement. Menus or the battlefield view do not grant user movement or automatically close because of contact. Already overlapping initial or restored states still need a feasible agreed solution before this interaction is enabled. Current partial presentation must not be described as completed physical contact; the detailed decision record remains in the [design brief](design_brief.md).

## 10. World, campaign and persistence

The battlefield target remains 4,000 by 6,000 metres, with opposing HQs, resource objectives, operational routes and meaningful travel. River Valley, Lake District, Highland Passes and Farmland and Towns remain the four intended procedural families. Terrain should read naturally and provide fair usable access, sight and cover. The authored Farmland scenario is the representative first demo, not completion of procedural generation.

The campaign remains a five-position tug-of-war. Engagement outcomes, experience, rewards and bundled capability access provide progression. Unlocking a recipe does not grant a vehicle, crew or ammunition. Saving and loading must preserve an engagement's actual progress, people and supplies, and resume paused without rerolling outcomes.

Aircraft, boats, neutral battlefield factions, multiplayer, food, fatigue, wages, weather and seasons are outside this edition. Other historical exclusions remain in the detailed reference unless Dawson explicitly changes them.

## 11. Interface and information

The base and character are the main play surface. Build, Workers/Jobs and Supplies must be easy to find. Selecting a building should bring its production, staffing, progress and current shortage together. Placing a building, hiring workers and changing a staffing target should not require navigating unrelated panels.

Use readable resource and building names. Show the reason work is blocked and a direct route to the relevant decision. Progress, arrivals and cancellations must describe actual events. Advanced ledgers and identifiers can remain available through optional inspection.

Useful feedback connects a request to its production, delivery, actual recipient and observed capability. Do not attribute an army's improvement to newly manufactured goods when it actually used existing HQ stock. Preserve uncertainty about unseen enemies and distinguish a known lack of capability from a lack of current target information.

The player should understand what their base is supporting, which bottleneck matters next and what changed after their intervention. A useful supply view connects military demand, factory output, rear loading, transit, HQ receipt and actual onward issue without requiring the player to operate each stage. Military reports should explain intent, shortages and outcomes so the autonomous war is understandable without turning it into a player command interface.

Appearance, interaction design and menu flow serve those player decisions. The Lead Developer is currently the sole programmer and owns engineering and integration, including UI implementation; the Game Designer owns the intended experience and game-meaning review. Current consultant involvement follows [team workflow](team_workflow.md); this GDD does not assign implementation work.

## 12. Current delivery goals and responsibility

The next gameplay outcomes are: a self-sustaining factory through ordinary controls; a useful automatic army delivery with an explainable frontline consequence; and a later physical replenishment cycle while the two autonomous commanders continue the engagement. [Playable delivery](playable_delivery.md) defines these outcomes. Campaign completion, every vehicle/support system and all map families are not prerequisites to that first connected demo.

The first connected demo should make the central chain observable: start in the normal empty field, build and staff production, manufacture useful output, deliver it automatically to the friendly military base, and observe actual military issue and autonomous operations against the opponent. A later genuine shortage should feed back into another production and delivery decision. The army's behaviour and capability must account for actual supply, but the demonstration must not promise a particular attack or victory. A standalone combat demonstration or an isolated factory screen does not complete this combined outcome.

The Game Designer defines vision, player decisions, rules and observable requisites. The Developer chooses and creates the systems, defines suitable checks, integrates the work and reports what actually works. The Designer does not prescribe architecture, scheduling algorithms, data structures or a testing framework in the GDD.

Implementation and experience acceptance remain distinct. Existing component evidence is valuable, but does not prove the ordinary full loop. Polishing, optimization and benchmark-driven work are paused under Dawson's 5 November direction; known defects and the eventual 60 FPS target remain visible. Defects that block the current feature or corrupt state still need fixing.

## 13. Decisions retained and questions still open

The approved rear opening, worker purchase/assignment rules and automatic request-driven shipping do not require reconfirmation. This revision does not change battlefield starting forces or the existing 6,000 HQ rifle rounds. If an earlier production dependency is desired, the Designer must propose that pacing change to Dawson explicitly rather than remove stock or invent a shortage.

Exact balance values remain provisional where previously described that way. A gameplay revision should state its player-facing reason and consequence. The Developer may resolve reversible implementation choices independently and raise only actual gameplay contradictions or costly experience tradeoffs.

Older GitHub issues use G01–G33, D01–D03 and A01–A60 identifiers and old GDD section numbers. Their historical detail is retained in [v0.2 / v0.2.1](reference/gameplay_specification_v0_2.md). Current scope comes from this GDD and later human decisions; historical test matrices, old team assignments and technical gates do not reactivate automatically.

This revision consolidates Dawson's accepted opening and automatic army-request shipping, 7 November default staffing and stylized 3D direction, and the subsequent deferred contact decision. Dawson's 9 November request explicitly reaffirmed the central vision: the player builds the factory/logistics area and supplies a military base whose autonomous RTS commander battles another autonomous commander. Detailed decision provenance remains in the [design brief](design_brief.md); engineering structure belongs in [foundation](foundation.md) and the [implementation atlas](system_atlas.md). No recipe, capacity, price, starting military stock or combat balance change is made by this review.
