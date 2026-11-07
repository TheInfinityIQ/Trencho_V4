# Trencho V4 — Game Design Document

Updated 5 November 2026. Owner: Game Designer. Human direction from Dawson governs. This document describes the intended player experience, gameplay rules and observable outcomes. It does not certify the current build.

The Developer owns creating the systems, technical specifications, testing, integration and publication. Current progress belongs in [implemented features](implemented_features.json), [prototype completion](prototype_completion.json) and [GitHub delivery #83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83). The [detailed v0.2 specification](reference/gameplay_specification_v0_2.md) is preserved as a historical catalogue/balance reference; its implementation prescriptions and superseded instructions do not govern new work.

## 1. The game we are making

Trencho is a base-building and worker-management game supplying an autonomous war. The player starts in a field as a character, builds an industrial base, hires people and decides how scarce workers and materials should be used. The army turns the resulting equipment, trained people and supplies into battlefield capability.

The pleasure comes from watching a base become productive, finding its bottlenecks and seeing the army benefit from the player's decisions. A lack of ammunition, fuel, trained crew or a safe supply route should have an understandable consequence. Building and workforce choices provide the complexity; operating menus should be straightforward.

## 2. Design pillars

- **Build the base.** Placement, access, storage, expansion and production capacity matter.
- **People are the limiting resource.** Builders, haulers, operators, students, instructors, drivers and military recruits compete for actual people.
- **Supply is physical.** Goods must be made, handled, carried and received. A reservation or a truck passing nearby is not a refill.
- **Delegate execution.** The player sets production and labour priorities; workers and military commanders carry out the work.
- **Explain cause and consequence.** Show what is missing, what is waiting and which player decision could help.

## 3. Core player loop

1. Move around the rear base with WASD and inspect the field.
2. Use the Supply Table to purchase workers and raw resources.
3. Place buildings through a clear build menu.
4. Assign workers from a shared pool and choose production targets and priorities.
5. Workers construct buildings, collect ingredients and manufacture goods.
6. The Logistics Centre automatically fulfils actual army supply requests through physical transport to HQ. Military logistics handles onward supply and issue.
7. Observe what the army can do, where it is blocked and how battlefield control affects income.
8. Change the base, workforce or production to meet later needs and sustain the same engagement.

The player should be able to complete this loop through ordinary controls. Diagnostics, fabricated shortages, inventory resets and forced combat are not substitutes.

## 4. Approved opening and controls

The rear starts with a controllable character, 2,500 requisition, 500 Building Materials, no hired workers or workshops, and a Supply Table/arrival point at the field's edge. Dawson explicitly approved this package on 1 November 2026. It replaces the older prebuilt rear package.

The first workers and first construction must be obtainable from this opening. Initial purchase access cannot require a Receiving Bay that has not been built. Purchased ordinary workers can build using the declared materials without first constructing an office or materials producer. The character is not a hidden source of free labour, qualifications or crew.

WASD controls the rear character. The build menu supports placement preview, rotation and cancellation, with readable cost and access reasons. The battlefield is observed through camera navigation and inspection; the player does not steer soldiers or choose their targets.

Pause, 1x and 2x remain accessible. Both rear and battlefield must continue their applicable activity while hidden. Waiting or planning in one area must not silently freeze the other. Pause stops timed gameplay while allowing inspection and management. The Developer chooses how to deliver these behaviours; the GDD does not prescribe a shared clock or scheduling mechanism.

## 5. Workers, jobs and training

The existing standard worker order brings eight untrained people for 120 requisition plus a 20 transport fee, with a 90-second arrival time. They join the pool through actual arrival and disembarkation. The supplier's driver and carrier leave. The existing rear capacity is 120, including relevant incoming and returning commitments.

The player requests worker counts and priorities for jobs and buildings. Routine assignment should not require selecting every person by name. Show available, assigned, present, arriving and requested people separately. An unmet target is a visible vacancy, not a worker who can already contribute.

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

The Logistics Centre automatically fulfils **army supply requests**, as Dawson selected on 1 November 2026. The player decides what to produce and how to allocate resources; normal supply delivery does not require composing and departing every manifest.

An army request names the needed item, quantity, destination, urgency and consequence of the shortage. Its display distinguishes stock already at the destination, remaining need, supply committed or in transit and supplies actually received. The same need must not generate duplicate shipments.

Actual staff and vehicles collect, load, travel and unload. Missing goods, handlers, qualified crew, fuel, transport, a safe route or receiving space produce an understandable waiting state. Logistics may send a useful capacity-valid shipment without waiting to fill a whole truck. It does not create goods or silently change the player's production choices.

HQ receipt is different from frontline receipt. The army arranges onward transport, rendezvous and local issue so supplies physically reach the people or vehicles that need them. A remote tank does not refill merely because shells arrived at HQ.

Ordinary supply vehicles and their returning crew remain distinct from a permanent military transfer. The player must understand when a commitment removes people or vehicles from the rear. A cancellation cannot erase already loaded or departed freight.

Later consumption or changed operations can create new demand. The same transport can return and make later useful trips. Forecasting should eventually consider the actual operation and delivery lead time, rather than waiting for every weapon to become empty.

## 8. Autonomous army and battlefield consequences

Commander, Company, Platoon, Squad, vehicle elements and individual roles retain distinct responsibilities. Orders travel down; observations, progress, shortages and inability reports travel up. Decisions use delivered information and actual capability, not hidden enemy inventory or knowledge supplied by the player's camera.

The army pursues feasible objectives, coordinates support, maintains supply and fallback routes, and holds or withdraws when it cannot continue safely. Supply can restore a lost capability; it does not guarantee a successful attack. Real leadership, strength, ammunition, morale, cohesion, terrain and enemy capability still matter.

Capturing and contesting resources requires actual eligible forces. Carried passengers do not capture through a vehicle. Uncontested ownership earns income; contested ground loses that economic benefit. These results should make the cost of a shortage or the value of a successful supply decision visible.

The opponent follows the same physical constraints. Its industry may be represented by paid off-map packages, but people and goods must arrive and be received. No free frontline waves, hidden combat bonuses or forced outcomes are authorized.

## 9. Vehicles, engineering and support

All five vehicle roles remain part of the intended game: resource transport, troop transport, technical, APC and tank. Vehicles need the appropriate actual crew, fuel, capacity, route and equipment. Ammunition and fuel resupply are general vehicle requirements, not an APC-only rule. A vehicle's loaded ammunition counts once, and its crew cannot simultaneously work elsewhere.

Engineers use real tools and supplies to build defences and forward services, prepare or restore crossings, clear mines and carry out authorized denial. Bridges have meaningful movement and load limits. A damaged route can interrupt supply and make repair, rerouting or withdrawal necessary. Engineers do not undertake a project merely because materials exist.

Vehicle damage, repair, towing and recovery preserve the same hull and its contents. Wounded soldiers need actual medics, supplies, transport and recovery capacity. Mortars, artillery, marksmen and drones provide their distinct support roles through real crew, equipment, observation and supply. A training course or manufactured item alone does not establish a functioning support system.

These are wider-game requirements. Their backend presence must not be presented as a connected player experience until the normal game uses them.

## 10. World, campaign and persistence

The battlefield target remains 4,000 by 6,000 metres, with opposing HQs, resource objectives, operational routes and meaningful travel. River Valley, Lake District, Highland Passes and Farmland and Towns remain the four intended procedural families. Terrain should read naturally and provide fair usable access, sight and cover. The authored Farmland scenario is the representative first demo, not completion of procedural generation.

The campaign remains a five-position tug-of-war. Engagement outcomes, experience, rewards and bundled capability access provide progression. Unlocking a recipe does not grant a vehicle, crew or ammunition. Saving and loading must preserve an engagement's actual progress, people and supplies, and resume paused without rerolling outcomes.

Aircraft, boats, neutral battlefield factions, multiplayer, food, fatigue, wages, weather and seasons are outside this edition. Other historical exclusions remain in the detailed reference unless Dawson explicitly changes them.

## 11. Interface and information

The base and character are the main play surface. Build, Workers/Jobs and Supplies must be easy to find. Selecting a building should bring its production, staffing, progress and current shortage together. Placing a building, hiring workers and changing a staffing target should not require navigating unrelated panels.

Use readable resource and building names. Show the reason work is blocked and a direct route to the relevant decision. Progress, arrivals and cancellations must describe actual events. Advanced ledgers and identifiers can remain available through optional inspection.

Useful feedback connects a request to its production, delivery, actual recipient and observed capability. Do not attribute an army's improvement to newly manufactured goods when it actually used existing HQ stock. Preserve uncertainty about unseen enemies and distinguish a known lack of capability from a lack of current target information.

The player should understand what their base is supporting, which bottleneck matters next and what changed after their intervention. Appearance, interaction design and menu flow are developed with the UI/UX developer; systems and state remain the Developer's responsibility.

## 12. Current delivery goals and responsibility

The next gameplay outcomes are: a self-sustaining factory through ordinary controls; a useful automatic army delivery with an explainable frontline consequence; and a later physical replenishment cycle while the engagement continues. [Playable delivery](playable_delivery.md) defines these outcomes. Campaign completion, every vehicle/support system and all map families are not prerequisites to that first connected demo.

The Game Designer defines vision, player decisions, rules and observable requisites. The Developer chooses and creates the systems, defines suitable checks, integrates the work and reports what actually works. The Designer does not prescribe architecture, scheduling algorithms, data structures or a testing framework in the GDD.

Implementation and experience acceptance remain distinct. Existing component evidence is valuable, but does not prove the ordinary full loop. Polishing, optimization and benchmark-driven work are paused under Dawson's 5 November direction; known defects and the eventual 60 FPS target remain visible. Defects that block the current feature or corrupt state still need fixing.

## 13. Decisions retained and questions still open

The approved rear opening, worker purchase/assignment rules and automatic request-driven shipping do not require reconfirmation. This revision does not change battlefield starting forces or the existing 6,000 HQ rifle rounds. If an earlier production dependency is desired, the Designer must propose that pacing change to Dawson explicitly rather than remove stock or invent a shortage.

Exact balance values remain provisional where previously described that way. A gameplay revision should state its player-facing reason and consequence. The Developer may resolve reversible implementation choices independently and raise only actual gameplay contradictions or costly experience tradeoffs.

Older GitHub issues use G01–G33, D01–D03 and A01–A60 identifiers and old GDD section numbers. Their historical detail is retained in [v0.2 / v0.2.1](reference/gameplay_specification_v0_2.md). Current scope comes from this GDD and later human decisions; historical test matrices, old team assignments and technical gates do not reactivate automatically.
