# Trencho v4 Game Design Document

Version 0.2 | 25 October 2026 | Vehicles engineering and procedural battlefields

Trencho v4 is a logistics management game in which the player supplies an autonomous military hierarchy. Industrial decisions become physical people, equipment, vehicles, and supplies; those assets determine what the army can actually do. The player should be able to trace a successful crossing or a failed attack back through that chain.

This edition specifies the current design target, including five vehicle types, engineer-built infrastructure and defences, manufactured Building Materials and Explosives, and procedurally generated 4 km by 6 km battlefields. It supersedes the gameplay defaults of version 0.1.1. The earlier document remains a historical reference. This is a gameplay specification; the software engineer chooses the implementation.

## 1 Design authority and scope

### 1.1 Established decisions

The player controls acquisition, rear construction, staffing, recipes, training, shipment composition, and dispatch timing. Military AI controls organization, equipment issue, operational movement, transport use, battlefield engineering, tactics, and combat. The hierarchy retains Commander, Company, Platoon, Squad, and individual people, with vehicle sections and service teams attached at appropriate levels.

Goods and people move between meaningful locations. Reserving an item does not move it. Producing it does not deliver it. Owning it at HQ does not put it in a distant soldier's hands. People compete between rear labour, training, crew duties, and frontline service. The player assigns capacity and priorities while autonomous workers and commanders execute individual tasks.

The campaign remains a five-position tug-of-war with temporary engagement recipe access and persistent experience and card unlocks. Vehicles, engineering, and procedural battlefields are now current scope. The battlefield has one HQ at each opposing end, a reference size of 4,000 by 6,000 metres, and one-metre tiles. Neutral NPCs and third-party battlefield factions are excluded from this edition. External procurement remains an off-map supply source, not a simulated third army.

### 1.2 Proposed defaults

The requested vehicle roles, engineering resources, procedural scale, terrain variety, bridge building and destruction, and two-army scope are adopted design requirements. Exact values, formulas, crew arrangements, recipes, caps, timing, and generation thresholds below are proposed defaults for review and playtesting. They are not claims of established balance or a running implementation.

All weights, recipes, and weapon statistics are gameplay balance values. The intended campaign engagement is approximately 30 to 50 simulation minutes, but no automatic time limit applies. Meeting that pacing is a playtest objective.

### 1.3 Boundaries

This roster contains 11 material resources, 22 equipment or ammunition types, 5 vehicle types, 29 recipes, basic training and seven specialist qualifications, thirteen rear facility types, twelve non-bridge engineering structures, three bridge classes, and four field explosive device actions. Procedural terrain and combined-arms command are required parts of the target.

Aircraft strikes, boats, amphibious vehicles, weather, seasons, flooding during play, food, fatigue, wages, personal worker skill levels, diplomacy, neutral NPCs, multiplayer, full civilian economies, and literal manufacturing mass conservation remain disabled. Ruined town buildings, farm fences, and trees are terrain props rather than resource extraction systems. Building a farm does not create food or timber income.

## 2 Core nodes and player experience

| Node | Responsibility | Current expansion |
| --- | --- | --- |
| N01 Acquisition | Convert requisition into arriving inputs and people | Nine purchased resources; manufactured explosives are not directly purchased |
| N02 Manpower | Allocate exclusive human capacity | Drivers, gunners, loaders, engineers, and infantry compete with labour |
| N03 Production and training | Convert local inputs, people, and time into capability | Vehicle assembly, Building Materials, Explosives, and crew training |
| N04 Internal logistics | Move and store physical goods in the rear | Heavy vehicle output bays, fuel handling, and large construction shipments |
| N05 Dispatch and transport | Prepare and physically dispatch loads or vehicle transfers | Resource and troop shuttles; self-propelled fleet transfers |
| N06 HQ logistics | Receive, unload, reserve, issue, and forward supplies | Fuel, shells, construction stock, and forward depots |
| N07 Military organization | Assemble capable formations from actual stock and people | Vehicle sections, boarding, crew stations, and replacements |
| N08 Command and operations | Turn delegated intent into battlefield action | Combined arms, crossing plans, mines, bridge denial, and resupply |
| N09 Objectives and economy | Turn control into acquisition opportunity | Six resource objectives and three operational objectives |
| N10 Campaign and progression | Connect engagement results and future options | Procedural encounters and bundled capability cards |

The material flow is acquisition, receiving, local storage, production, staging, loading, transit, HQ unloading, local issue or forward delivery, and consumption. The human flow is arrival, allocation, optional training, real transport, military assignment, and recovery or loss. Information flows from observations and subordinate reports through command into explicit supply demand. Objective income closes the economic loop.

At this scale, troop transport and supply carriers are necessary operational tools. A formation walking 2,000 metres at 2 metres per second takes roughly seventeen minutes before terrain effects; a troop truck can cover a clear road in a little over two minutes. This difference is intended gameplay. The army must arrange transport, unload before fighting, and keep a physical supply route open.

Both rear and battlefield share one simulation clock. Switching views does not stop either. Pause allows inspection and logistics decisions while stopping movement, work, income, fuel use, and combat. Speed options are pause, 1 times, and 2 times. Player controls never become direct tank steering, bridge placement on the battlefield, or manual target selection.

## 3 Entity model and common attributes

### 3.1 Definitions and ownership

Every entity has a design type, visible instance identifier, owner, controller if applicable, current state, state entered time, creation time, and inspection description. Physical entities have one location or transit leg, a position or holder, and a mass or carrying allowance. Abstract entities such as a campaign have no physical position. There is exactly one physical copy of each person and each counted quantity.

Ownership and control are separate. A leased transport can remain supplier-owned while being player-controlled and therefore a legitimate enemy target. Goods belong to their purchaser, not automatically to their carrier's owner. The only battlefield combat affiliations are the two opposing armies. Unowned objectives do not constitute another faction. Future actor types must not be classified as hostile merely because they are outside the player's army.

### 3.2 Common attribute dictionary

| Entity category | Required attributes and default meanings |
| --- | --- |
| Person | Assignment; location; basic training flag; one specialist qualification or None; health 100; morale 60; suppression 0; equipment; loaded and loose ammunition; military service time; parent formation or duty; current action; leader appointment or None |
| Goods stack | Resource or equipment type; whole quantity; unit mass; physical holder; reserved quantity; available quantity; claimant and purpose for each reservation |
| Recipe | Inputs by type and quantity; outputs by type and quantity; eligible facility; required operator-work seconds; access prerequisite; batch state; consumed inputs; reserved output capacity |
| Facility | Footprint; orientation; entrance; input and output storage; staffing target and actual staff; priority; recipe and target stock; work progress; protected-starter flag; current blocking reasons |
| Vehicle | Type; owner and controller; footprint and facing; health; crew by station; passengers; freight; fuel; loaded and stowed ammunition; speed and route; mobility state; mission; parent formation; observation and weapon state |
| Manifest | Mission mode; exact requested goods, people, crew, and vehicle; committed reservations; current staged and onboard quantities; cumulative arrived and unloaded quantities; payload and seats; route; authorization; lifecycle |
| Formation | Echelon; leader; parent; subordinate people or elements; authorized and issued loadout; mission and role; capability list; readiness; cohesion; ammunition and fuel demand; fallback and rendezvous |
| Order | Issuer; recipient; desired outcome and purpose; target; constraints; priority; creation and acknowledgement; progress; fallback; cancellation or completion |
| Contact | Observer; actual observation time; reported position; class and observed count; confidence; currently visible flag; sharing recipients; uncertainty |
| Construction project | Blueprint; owner; exact footprint and facing; required M11 or M06; delivered and consumed quantities; workers; progress; access and safety; cancellation state |
| Structure or bridge | Type; footprint or span endpoints; owner; maximum and current health; occupancy; cover or operating benefit; supplies; staffing; traversal or load restrictions; operational state |
| Field device | Type; owner; position; M06 committed; placement and arming progress; controller if remote; trigger; detected-by sides; active or inert state |
| Terrain tile | One-metre position; terrain class; height and slope; vegetation and obstacles; road or bridge overlay; traversal permissions; movement, sight, cover, and fuel effects |
| Scenario | Dimensions; terrain and topology; seed and rules version; gates and HQs; initial stock and people; objective set; available content; caps; difficulty; result conditions |
| Campaign and profile | Position 1 to 5; engagement history; current scenario; run state; permanent card collection; XP; earned boxes; settings; fixed pending rewards |

Control priority is Emergency, High, Normal, or Low, default Normal. Missing assignments are None, not a zero quantity. A reservation has a claimant, type, amount, source, purpose, and age. It cannot exceed physically owned available quantity and does not move goods. Durable non-person assets are destroyed at zero health; people instead follow the wound lifecycle. An incapacitated operator does not make an intact weapon permanently nonfunctional.

### 3.3 State and interruption rules

Assignments are exclusive: Available, Rear Labour, Training, Strategic Crew, Awaiting Deployment, Passenger, HQ Reserve, HQ Duty, Formation Duty, Wounded, Recovery, or Dead. Reporting, boarding, and crew-station changes are phases within those assignments. A wounded assignment means incapacitated; an injured active person can remain on their ordinary duty. People in transfer remain recorded and cannot fill a destination squad before they arrive.

Activities record required work, completed work, assigned people, inputs, target, and blocking reason. Work does not advance without prerequisites. Pause preserves progress. Unless a more specific rule states otherwise, interruption preserves consumed inputs and work; explicit cancellation applies the activity's refund or loss rule. Loading cancellation leaves real goods aboard until physically unloaded.

## 4 Units accounting and conservation

Distances are metres, map tile edges are one metre, time is simulation seconds, and requisition is abstract money. Movement and weapon ranges use horizontal map distance; slope and height separately affect travel and sight. The reference map is 4,000 columns by 6,000 rows, or 24,000,000 tiles. Tile resolution defines world dimensions and occupancy checks; visual map zoom need not draw every tile separately. Terrain cells are identified by coordinates, not individually named actors. People may have continuous positions within that space and cannot walk through an impassable footprint.

Every listed material unit weighs 1 kg. Equipment has its listed unit weight. A person contributes a standardized 80 kg body mass plus carried equipment. A person's personal equipment and supply limit is 25 kg, excluding their body. An ordinary hauling load is at most 25 kg and one item type. Carrying wounded people is a specific exception.

Recipe quantities and carrying weights remain independently balanced prototype values. Output mass is not required to equal input mass; no unlisted material delivery is implied. This is an explicit economic abstraction. Physical continuity preserves identities, counts, ownership, and locations during movement and issue. A later decision to conserve literal manufacturing mass would require a complete recipe and capacity rebalance.

Production consumes a complete input batch once at start and creates the exact output once at completion. Construction and device rules specify their own consumption point. No reservation is consumed as a second copy of its goods. Fuel transferred into a tank remains accounted as that vehicle's internal fuel until consumed by movement.

Goods, seats, people, and health are whole counts. Work, capture progress, distances, fuel in a tank, and money accumulation can be fractional. Damage rounds up after all modifiers. Half salvage rounds down separately per type. Capacity uses actual values even when the display rounds them. Loaded ammunition is part of total ammunition, not an additional free quantity.

## 5 Resources acquisition and economy

### 5.1 Resource catalogue

| ID | Resource | Unit mass kg | Unit price | Source | Uses |
| --- | --- | --- | --- | --- | --- |
| M01 | Metal | 1 | 2 | Purchased | Weapons, vehicles, building materials, and ammunition |
| M02 | Components | 1 | 4 | Purchased | Mechanisms, tools, vehicles, and equipment |
| M03 | Gunpowder | 1 | 1 | Purchased | Rifle ammunition, smoke rounds, and explosives production |
| M04 | Timber | 1 | 1 | Purchased | Building materials production |
| M05 | Textiles | 1 | 2 | Purchased | Protection and medical equipment |
| M06 | Explosives | 1 | Not purchasable | Manufactured R27 | Shells, mortar bombs, mines, and demolition |
| M07 | Electronics | 1 | 12 | Purchased | Vehicles, radios, controllers, and drones |
| M08 | Fuel | 1 | 2 | Purchased | All vehicle engines |
| M09 | Medical compound | 1 | 6 | Purchased | Medical packs |
| M10 | Battery cells | 1 | 8 | Purchased | Drone batteries |
| M11 | Building Materials | 1 | Not purchasable | Manufactured R26 | Every engineer-built structure, road, bridge, and field repair |

M01 replaces the previous display name Steel with Metal. M03 replaces Propellant with Gunpowder. M06 keeps its identity as explosive stock but is now produced rather than purchased. M11 is the single construction and field-repair resource. Equipment tools, ammunition, medicine, and fuel still have their separate purposes; infrastructure does not consume a collection of screws, concrete, wire, and steel sub-resources.

Unarmed M06 stock and stored ammunition do not spontaneously detonate. Only completed and armed field devices or released projectiles produce explosive effects. Secondary warehouse explosions and volatile cargo chains are disabled. These resources remain physical freight that must reach engineers, gun crews, or vehicles.

### 5.2 Purchases and income

Baseline income is 6 requisition per second. Each owned, uncontested Resource Objective adds 1.5 per second. There are six in the full scenario, so maximum resource income is 9 additional points per second. Ownership does not create materials in a depot. Income is continuous, with no interest, debt, or storage cap.

The rear terminal purchases M01, M02, M03, M04, M05, M07, M08, M09, and M10. Material orders hold 1 to 5,000 kg per external resource truck and cost unit prices plus 20 requisition per vehicle. Orders over that size are shown as separately priced vehicles before commitment. Arrival is 60 seconds after purchase, followed by berth waiting and real unloading. Ten external arrivals may wait off-map; purchases that exceed reserved receiving queue space are unavailable.

A standard manpower order brings eight untrained people for 120 requisition plus the 20 transport fee, in an external troop carrier. Arrival is 90 seconds. Rear population capacity is 120, including workers, trainees, strategic crews, and people still physically in the rear. Returning strategic crew retain their rear population place while away, so purchases cannot fill their home capacity and prevent return. Non-returning passengers or Fleet Transfer crew release rear places when they leave the rear, while remaining counted as real people in transit. Incoming orders reserve places. Purchased people become player people when they disembark; the supplier's carrier and driver leave rather than joining the fleet. Personnel arrivals use a separate pull-off at F08 with capacity for two pending passenger vehicles, independent of the ten-vehicle freight queue. They disembark under their own movement without unloading labour. A rear with zero workers can therefore receive people even when freight receiving is blocked.

Purchases can be cancelled for full refund during their first 5 seconds. After that they are dispatched and cannot be cancelled. A recipe offer costs 75 requisition including transport, arrives after 45 seconds as a 1 kg document, is unloaded and hauled to the terminal, and is consumed when opened. At most one unopened or unselected offer may exist. The free initial offer is already present before play.

### 5.3 Recovery and essential access

R01, R02, R08, R25, R26, R27, and R28 are always active: rifles, rifle rounds, engineer kits, resource transports, Building Materials, Explosives, and troop transports. Basic infantry, engineer, and vehicle crew training are always available. Cards never gate the ability to produce essential bridge inputs or restore a transport fleet.

If no basic-trained person remains in the rear, the terminal offers one trained instructor arrival for 100 requisition plus the 20 fee, after 90 seconds, using one reserved population place. Only one such recovery arrival may be pending. They are a normal P01 afterward. Dispatch warns before removing the final eligible instructor.

If no owned strategic-capable vehicle survives, a 150-requisition Emergency Transport Contract brings one leased resource transport or troop transport, chosen at purchase, after 90 seconds. It arrives with a qualified service driver and full fuel, executes one legal strategic manifest, returns, and leaves. It cannot join the military fleet or donate its driver to the recruit pool. There is one active or pending contract at most. Its driver and losses are recorded separately as paid external service; the vehicle is player-controlled and attackable during the trip. No goods or deployable people are included. This is a recovery service, not vehicle manufacture.

## 6 Equipment weapons and recipes

### 6.1 Equipment catalogue

| ID | Item | Unit mass kg | Purpose |
| --- | --- | --- | --- |
| E01 | Service rifle | 4 | W01; empty when manufactured |
| E02 | Rifle round | 0.02 | W01, W02, W05, and mounted machine guns |
| E03 | Helmet | 1 | 5 percent direct small-arms protection |
| E04 | Body armour | 5 | 15 percent direct small-arms protection; 0.85 infantry speed |
| E05 | Support machine gun | 9 | W02; portable weapon; mounted guns are integral to vehicle recipes |
| E06 | Mortar | 18 | W03; 3 heavy-weapons specialists |
| E07 | Mortar bomb | 2 | One W03 explosive shot |
| E08 | Engineer kit | 6 | Reusable engineering tools and device controls |
| E11 | Medic kit | 4 | Reusable treatment tools |
| E12 | Medical pack | 1 | One treatment episode |
| E13 | Field gun | 180 | W04; 4 artillery specialists; direct or indirect mode |
| E14 | Artillery shell | 5 | One W04 shot in either mode |
| E15 | Recon drone | 5 | Unarmed; recovered after a successful sortie |
| E16 | Drone controller | 4 | One controlled drone per qualified operator |
| E17 | Drone battery pack | 1 | Consumed at launch |
| E18 | Field radio | 3 | Remote indirect-fire mission coordination |
| E19 | Marksman rifle | 5 | W05; marksman qualification |
| E20 | Binoculars | 1 | Stationary observation out to 350 metres |
| E21 | Stretcher | 4 | Two-person casualty carry |
| E24 | Smoke round | 2 | Mortar smoke; no blast damage |
| E25 | Tank shell | 12 | One W07 shot; one general-purpose game ammunition type |
| E26 | Autocannon round | 0.5 | One W06 shot; one general-purpose game ammunition type |

An individual has one active personal weapon, one helmet, one armour item, and one specialist kit. A crew-operated item belongs to its formation and occupies a real position. A new weapon is empty. Reloading moves rounds from carried loose stock into the weapon's loaded quantity. A dropped weapon retains its loaded rounds; the former holder loses them. Loose rounds drop separately. A handoff requires people within 2 metres and 2 seconds without firing. Deployed portable machine guns have 80 health, mortars 120, and field guns 400; packed weapons are not separately targetable. Destroyed deployed weapons cannot be repaired, but intact ones can be recovered. The drone's 30 health is defined in its sortie rules.

T01 to T05 are vehicles, not personal equipment. Vehicle manufacture includes the listed integral gun and mounting mechanism where applicable; it does not create a spare loose E05 or a second inventory weapon. It produces zero crew, passengers, fuel, or ammunition. A qualified rear driver must physically move a completed hull out of the assembly bay; otherwise the bay reports Awaiting Qualified Driver. All rear-owned manufactured hulls require a rear-fleet production admission when the order is accepted, plus a legal output and parking or collection destination before starting and again before physical creation. A planned military destination never substitutes for rear admission. An accepted Fleet Transfer additionally holds an incoming military-fleet admission; the rear slot remains held until actual HQ handoff or destruction, as clarified in section 23.6 and D03. These reservations cannot create a crew or bypass the occupied output bay.

### 6.2 Weapon values

The damage columns are maximum damage to an infantry person, a vehicle on a qualifying penetration, and a structure. Personal armour applies only to direct small-arms injury. Penetration is compared with the vehicle surface actually hit. Direct and blast damage from one shot do not stack on the same target; apply the larger valid result.

| Weapon | Range metres | Damage infantry / vehicle / structure | Penetration | Base direct hit chance | Cadence | Loaded capacity | Reload |
| --- | --- | --- | --- | --- | --- | --- | --- |
| W01 Service rifle using E02 | 160 | 34 / 10 / 2 | 5 | 0.55 | 2 seconds | 10 | 3 seconds |
| W02 Portable or mounted machine gun using E02 | 250 | 24 / 18 / 2 | 8 | 0.45 | 0.25 seconds | 60 | 6 seconds |
| W03 Mortar using E07 | 100 to 900 | 70 / 70 / 70 | 20 to top | Location scatter | 8 seconds | 1 | Included |
| W04 Field gun direct using E14 | 60 to 650 | 120 / 180 / 200 | 100 | 0.60 | 10 seconds | 1 | Included |
| W04 Field gun indirect using E14 | 200 to 1,400 | 120 / 120 / 120 | 30 to top | Location scatter | 12 seconds | 1 | Included |
| W05 Marksman rifle using E02 | 300 | 55 / 14 / 3 | 8 | 0.70 | 4 seconds | 5 | 4 seconds |
| W06 APC autocannon using E26 | 450 | 35 / 35 / 20 | 45 direct | 0.60 | Three shots at 0, 0.33, 0.67 seconds; next burst at 2 seconds | 30 | 6 seconds |
| W07 Tank cannon using E25 | 700 | 140 / 260 / 400 | 130 direct | 0.65 | 8 seconds | 1 | Included; requires loader |

The tank coaxial gun uses W02 values and E02. Mounted W02 does not require a separate ammunition assistant. Portable W02 requires a P04 operator and one active assistant for full rate; without an assistant cadence is 0.5 seconds and reload is 12 seconds. Portable setup and pack time are 6 seconds. Mortar setup and pack are 12 seconds with three P04; field gun setup and pack are 20 seconds with four P05. An incomplete mortar or field-gun firing crew cannot fire. A vehicle's station requirements are specified separately.

For mortar fire, flight time is 8 seconds, scatter radius 18 metres, and blast radius 10 metres. Field-gun indirect flight is 10 seconds, scatter radius 25 metres, and blast radius 12 metres. Scatter is uniform over a circle. Direct cannon travel time is distance divided by 300 metres per second, minimum 0.25 seconds. Rifle and machine-gun shots resolve at release. Direct autocannon blast has radius 2 metres and maximum infantry damage 30, vehicle penetration 10; tank shell blast has radius 6 metres and maximum infantry damage 100, vehicle penetration 20. Direct-hit vehicle damage uses the direct penetration value instead. Field-gun direct blast uses radius 8 metres, maximum infantry damage 100, and penetration 20.

Blast damage falls linearly from its maximum at impact to zero at its radius, rounding up within the radius. Distance is to the closest part of the target footprint, zero when the impact is inside it; a person without an area footprint uses their position. The best valid cover multiplies that damage; ordinary heavy cover halves it and a bunker multiplies it by 0.25. Opaque walls block direct fire; blast uses the cover rule rather than simulating structural fragments. Every released round is consumed once, including a miss. No gun has unlimited ammunition.

### 6.3 Recipe catalogue

Inputs must be physically local and available before a batch starts. The full input is consumed at start; complete output capacity is reserved before starting. Work is operator-work seconds: four present operators finish a 100-work-second batch in 25 seconds. Zero staff pauses work; no staff or material teleportation occurs. Production runs on one selected recipe per facility, continuously or to a player stock target. Owned rear goods reserved for shipment do not satisfy an unreserved stock target.

| Recipe | Output per batch | Inputs | Facility | Work seconds |
| --- | --- | --- | --- | --- |
| R01 | 1 E01 Service rifle | 2 M01, 1 M02 | Workshop | 40 |
| R02 | 100 E02 Rifle round | 1 M01, 1 M03 | Munitions Workshop | 40 |
| R03 | 1 E03 Helmet | 1 M01 | Workshop | 15 |
| R04 | 1 E04 Body armour | 3 M01, 2 M05 | Workshop | 35 |
| R05 | 1 E05 Support machine gun | 5 M01, 3 M02 | Workshop | 90 |
| R06 | 1 E06 Mortar | 8 M01, 3 M02 | Workshop | 120 |
| R07 | 10 E07 Mortar bomb | 10 M01, 10 M06 | Munitions Workshop | 80 |
| R08 | 1 E08 Engineer kit | 3 M01, 3 M02 | Workshop | 45 |
| R11 | 1 E11 Medic kit | 2 M02, 2 M05 | Support Workshop | 40 |
| R12 | 10 E12 Medical pack | 4 M05, 6 M09 | Support Workshop | 50 |
| R13 | 1 E13 Field gun | 100 M01, 60 M02 | Vehicle Works | 600 |
| R14 | 10 E14 Artillery shell | 30 M01, 20 M06 | Munitions Workshop | 140 |
| R15 | 1 E15 Recon drone | 2 M02, 3 M07 | Support Workshop | 100 |
| R16 | 1 E16 Drone controller | 2 M02, 2 M07 | Support Workshop | 70 |
| R17 | 5 E17 Drone battery pack | 5 M10 | Support Workshop | 40 |
| R18 | 1 E18 Field radio | 1 M02, 2 M07 | Support Workshop | 50 |
| R19 | 1 E19 Marksman rifle | 3 M01, 3 M02 | Workshop | 75 |
| R20 | 1 E20 Binoculars | 1 M02 | Support Workshop | 25 |
| R21 | 1 E21 Stretcher | 2 M01, 2 M05 | Support Workshop | 25 |
| R24 | 10 E24 Smoke round | 8 M01, 4 M03, 2 M05 | Munitions Workshop | 70 |
| R25 | 1 T01 Resource Transport | 120 M01, 80 M02 | Vehicle Works | 800 |
| R26 | 100 M11 Building Materials | 30 M01, 70 M04 | Building Materials Plant | 100 |
| R27 | 1 M06 Explosives | 10 M03, 2 M01 | Munitions Workshop | 40 |
| R28 | 1 T02 Troop Transport | 100 M01, 60 M02 | Vehicle Works | 700 |
| R29 | 1 T03 Technical | 80 M01, 50 M02 | Vehicle Works | 900 |
| R30 | 1 T04 Armoured Personnel Carrier | 500 M01, 250 M02, 20 M07 | Vehicle Works | 2200 |
| R31 | 1 T05 Tank | 1200 M01, 500 M02, 40 M07 | Vehicle Works | 4000 |
| R32 | 10 E25 Tank shell | 100 M01, 20 M06 | Munitions Workshop | 180 |
| R33 | 100 E26 Autocannon round | 30 M01, 20 M06 | Munitions Workshop | 100 |

R26 makes 100 Building Materials from 30 Metal and 70 Timber. R27 makes one Explosives unit from 10 Gunpowder and 2 Metal, making Gunpowder a substantial throughput requirement rather than a token ingredient. Explosives then feed mortar bombs, artillery shells, tank shells, autocannon rounds, and field devices. There is no separate purchased demolition compound or mine-item production chain. Mine and charge identities are created only by engineers' field actions.

Recipe access can be bundled by a card so a cannon arrives with its ammunition recipe. All outputs are fixed, with no random quality. Pausing retains batch progress. Changing recipe explicitly cancels its current batch, loses consumed inputs, and resets work after a player confirmation. Cancelling a queued, unstarted batch has no material cost. Finished goods remain physical output even if their original request is cancelled.

## 7 Manpower training and qualifications

### 7.1 Courses and personnel types

Basic training requires an untrained person, a student place, a basic-trained instructor, and 120 seconds. One instructor supports six concurrent students; two support twelve. A specialist course adds its listed duration after basic training. The student must report physically; progress stops if the facility lacks instructor coverage. Excess students are paused newest first. Training does not consume ammunition in this edition.

| Personnel | Course after basic | Access | Duties and limits |
| --- | --- | --- | --- |
| P00 Untrained person | None | Arrival | Labour or conscript deployment; acting conscript leadership only |
| P01 Trained infantry | Basic course 120 seconds | Always | Rifle combat, normal leadership, radio use, observation, and instruction |
| P02 Engineer | 180 seconds | Always through R08 | Kit-based structures, roads, bridges, repairs, mines, clearance, and demolition |
| P03 Medic | 180 seconds | R11 active | Treatment and recovery with kit and packs |
| P04 Heavy weapons specialist | 180 seconds | R05 or R06 active; technical gunner course also available with R29 | Portable W02, mortar crew, and technical gunner |
| P05 Artillery specialist | 180 seconds | R13 active | Field gun operation and relocation |
| P06 Drone operator | 180 seconds | R16 active | Sorties with drone, controller, and battery |
| P07 Marksman | 180 seconds | R19 active | W05 precision fire and observation |
| P08 Vehicle crew | 240 seconds | Always through R25 | Drive any listed vehicle; operate its integral stations, including mounted guns; cannot operate a portable mortar or field gun without that other qualification |

People retain completed basic training and one specialist qualification. Qualifications do not grant equipment. Each person may have only one specialist qualification in this roster; a vehicle crew member is not also a field engineer. All basic-trained specialists may serve as instructors under the standardized curriculum. Withdrawing from an unfinished course loses that course's time, not earlier qualifications. Returning to labour before military commitment preserves qualifications.

### 7.2 Assignment and commitment

The player requests counts, not named people. Selection prefers eligible idle people, then safe reassignment from rear work. A person carrying goods finishes the carry or deposits into safe valid storage before changing duty. People reserved for deployment stop contributing labour when they report to dispatch. No person works and trains simultaneously.

A Strategic Delivery crew remains a rear logistics assignment even while physically at HQ; they return with their vehicle. Passengers committed to the army become military personnel after disembarking. In Fleet Transfer, the vehicle and every assigned crew member pass to military control at HQ. They cannot be returned to rear industrial labour during the engagement. The dispatch view states which people are returning crew and which are permanent commitments.

Conscripts have aim multiplier 0.75, incoming suppression multiplier 1.25, new-order response delay 2 seconds, and safe morale recovery 1 point per second. Basic-trained people and specialists use aim 1, suppression 1, response delay 0.5 seconds, and morale recovery 2. Training does not increase health or carrying capacity. An acting conscript leader grants no radio or specialist abilities.

## 8 Rear facilities labour and physical work

### 8.1 Facilities

The rear reference area expands to 240 by 180 metres to fit vehicle assembly and construction shipments. It remains separate from the 4 km by 6 km battlefield. Buildings cannot overlap, close their only access route, or obstruct a vehicle berth. Roads serving Vehicle Works and dispatch have at least 8 metres clear width. Completed rear buildings and their workers are invulnerable to battlefield attack.

| Facility | Footprint metres | Staff positions | Input kg | Output or depot kg | M11 build cost | Build work seconds |
| --- | --- | --- | --- | --- | --- | --- |
| F01 Terminal | 6 by 6 | 0 | 0 | 0 | 0 | 0 |
| F02 Receiving Bay | 16 by 12 | 4 | 0 | 5000 | 100 | 160 |
| F03 General Depot | 20 by 16 | 0 | 0 | 10000 | 100 | 160 |
| F04 Workshop | 16 by 12 | 4 | 1000 | 1000 | 150 | 200 |
| F05 Munitions Workshop | 16 by 12 | 4 | 1000 | 1000 | 180 | 240 |
| F06 Training Facility | 20 by 16 | 2 | 0 | 0 | 150 | 200 |
| F07 Dispatch Bay | 20 by 16 | 4 | 0 | 6000 | 150 | 200 |
| F08 Personnel Area | 16 by 12 | 0 | 0 | 0 | 0 | 0 |
| F09 Support Workshop | 16 by 12 | 4 | 1000 | 1000 | 150 | 200 |
| F10 Vehicle Works | 28 by 24 | 8 | 5000 | 0 | 400 | 480 |
| F11 Vehicle Park | 30 by 20 | 0 | 0 | 0 | 150 | 160 |
| F12 Construction Office | 10 by 8 | 4 | 0 | 0 | 60 | 80 |
| F13 Building Materials Plant | 20 by 16 | 8 | 2000 | 3000 | 180 | 240 |

F01 and F08 are fixed. Other rear structures consume only M11 in the displayed build amount. Up to four ordinary rear builders supply one work second each per second, after all required Building Materials reach the site. Rear construction does not require a P02. F10 output is one heavy object or vehicle, not zero storage; a new batch cannot begin while that bay is occupied. F11 provides four idle parking places per park. F06 has twelve student places in addition to two instructor positions.

A new F13 requires Building Materials, but the starting scenario already includes a working F13 and a starter stock. The initial F02, F12, and F13 have a visible protected-starter flag and cannot be dismantled, preventing the loss of every receiving bay, builder office, or producer needed to recover the economy. Additional copies can be dismantled. F01 and F08 are also fixed. The player therefore never needs to build the first materials producer using a resource they cannot yet make. Cancelling rear construction before work returns all delivered M11; after work starts it returns half, rounded down. Dismantling an eligible completed rear building takes 20 work seconds, returns half its build M11, and physically releases stored goods. A live production batch must be cancelled first.

### 8.2 Staffing and jobs

The player sets staffing targets at each facility plus General Hauling and Construction pools. Targets may exceed available people; shortages remain visible. Actual production requires workers physically present. Qualified P08 are needed for yard driving and strategic crew; ordinary operators do not drive a tank merely because they built it.

Staffing priority is Emergency, High, Normal, Low. Equal demand first fills the greatest unfilled share of requested positions, then the oldest request. Workers choose the highest-priority accessible job they can perform, then shortest complete carry, then oldest job. Waiting work rises one priority level every 60 seconds to a maximum High. Explicit Emergency work can starve ordinary jobs; after 120 seconds the base reports that cause.

Job types are unload, haul, supply workshop, operate recipe, instruct, stage, load, refuel, board, move a completed vehicle, rear construction, and return or recover goods. Unburdened workers walk 1.5 metres per second, burdened workers 1.2. Picking up a load takes 2 seconds and putting it down takes 2. A load is at most 25 kg and one type. A thousand rounds can be carried together rather than creating one job per round.

Capacity is reserved before pickup. Source goods remain reserved while the worker approaches. If the source is unreachable for 10 seconds the reservation is released, the reason is shown, and demand remains. A destination invalidated during a carry causes delivery to nearest valid safe storage, or a marked recoverable temporary pile if none fits. Workers never delete freight to solve congestion.

Heavy equipment uses built-in loading gear at Vehicle Works, Dispatch, and HQ: two loaders transfer one field gun in 20 seconds. T01 can carry at most two field guns within its ordinary payload; T02 can carry one field gun only with passenger capacity reduced to eight for that mission. Other vehicles carry no loose field gun. A working gun can be pushed by two P05 at 0.5 metres per second, requiring four to fire. No listed vehicle is shipped as loose vehicle freight: it must travel under its own power or the defined tow rules. A manifest can collect heavy goods directly from Vehicle Works before visiting Dispatch.

A pushed or towed field gun uses wheeled-equipment terrain access and cannot cross a B01, enter a trench, or pass intact wire. Carrying a mortar is ordinary infantry equipment movement. The field gun does not acquire infantry traversal merely because people are pushing it.

Workshop inspection shows recipe, local inputs, present staff, work progress, local output, capacity, and every blocking reason. Main status priority is Paused, No Recipe, Output Full, Missing Inputs, Missing Labour. Depot inspection separates owned, available, reserved, inbound, outbound, and physical location. Storage filters do not erase existing goods; changes generate relocation work.

## 9 Vehicle catalogue and operating rules

### 9.1 Five vehicle roles

| Type | Crew stations | Passenger seats | Payload kg | Empty mass kg | Health | Footprint metres |
| --- | --- | --- | --- | --- | --- | --- |
| T01 Resource Transport | 1 | 2 | 5000 | 4000 | 450 | 7 by 2.7 |
| T02 Troop Transport | 1 | 16 | 2000 | 3200 | 400 | 6.8 by 2.5 |
| T03 Technical | 2 | 2 | 400 | 2000 | 300 | 5.2 by 2.1 |
| T04 Armoured Personnel Carrier | 3 | 8 | 1200 | 14000 | 650 | 7.5 by 3 |
| T05 Tank | 4 | 0 | 200 | 30000 | 1200 | 8.5 by 3.5 |

Passenger seats exclude crew stations. T02 carries two full eight-person squads plus its driver. T04 carries exactly one eight-person squad plus its three crew, with cannon fire support during and after deployment. T01 carries Building Materials, Explosives, ammunition, fuel, and equipment toward forward positions. T03 is an unarmoured pickup with an integral roof machine gun. T05 is a tracked tank with a cannon and coaxial machine gun.

All hull masses exclude people, ordinary freight, fuel, and ammunition. Payload is the combined mass of passengers, their gear, and ordinary freight; dedicated crew body and personal gear, tank fuel, and ammunition in integral racks are additional to that payload but count in gross bridge load. A loose ammunition crate carried as freight still consumes payload. Moving it into a rack changes its container, not its quantity.

### 9.2 Motion fuel and access

| Type | Cross-country m per second | Road m per second | Tank capacity | Road fuel units per km | Turn radius metres | Tow limit kg |
| --- | --- | --- | --- | --- | --- | --- |
| T01 | 8 | 12.0 | 40 | 2 | 10 | 3000 |
| T02 | 10 | 15.0 | 40 | 2 | 9 | 0 |
| T03 | 12 | 18.0 | 30 | 1.5 | 7 | 0 |
| T04 | 8 | 12.0 | 80 | 4 | 8 | 0 |
| T05 | 6 | 9.0 | 120 | 6 | 0 | 35000 |

Cross-country speed is multiplied by the terrain's movement factor. The road column is cross-country speed times 1.5 on a sound ordinary road. The listed turn radius applies to a rolling turn. T05 can pivot in place at 30 degrees per second; T04 hull turn rate is 40, T03 is 70, and T01 and T02 are 45. Wheels still need the stated turn clearance. A towed combination requires 20 metres turn clearance and speed 0.25 of its tractor's normal terrain speed.

Fuel burn equals metres travelled divided by 1,000 times the listed rate times the terrain fuel factor. Road fuel factor is 1, so full tanks nominally permit 20 road kilometres for every type. Towing doubles fuel burn. Stationary engines, turret rotation, and firing consume no fuel in this edition. Fuel at zero stops motion immediately and reports Fuel Empty; it does not destroy the vehicle or prevent a stationary gun from firing.

M08 transfers from physical local stock into a vehicle's fuel tank in whole units. Travel can consume fractions. Refilling requires at least one full unit of free tank space, never creates a partial loose resource unit, and takes normal staff handling. Fuel in the tank is not simultaneously depot stock. Routes require enough fuel for the planned leg and a reachable next resupply point with 25 percent reserve. Strategic Delivery requires that margin for the complete return trip. Fleet Transfer requires the one-way leg and HQ access. No fuel reservation can exceed capacity; command must plan an intermediate fuel stop or reject the route.

Vehicles are not amphibious. Deep water, forbidden slopes, insufficient clearance, an incompatible bridge, a known mine exclusion, or an impassable obstacle invalidates the route. A faster route is not usable if a vehicle cannot fit it or carry enough fuel. Combat AI uses knowledge of terrain changes it has actually received; a destroyed distant bridge is not magically known to an uninformed driver.

### 9.3 Stations qualifications and fire

| Type | Crew stations | Minimum combat deployment | Remaining capability after casualties |
| --- | --- | --- | --- |
| T01 | One P08 driver | One qualified driver | Stops without driver; passengers do not become drivers unless P08 and physically reassigned |
| T02 | One P08 driver | One qualified driver | Same; passengers may disembark if safe |
| T03 | P08 driver; P04 or P08 gunner | Both | Driver alone can withdraw; gunner alone can fire while stationary |
| T04 | P08 driver, gunner, commander | All three | Driver enables motion, gunner enables cannon, commander enables 450 m observation; remaining crew can change stations |
| T05 | P08 driver, gunner, loader, commander | All four | Driver enables motion; gunner and loader together enable main gun; gunner enables coax; commander enables 700 m observation |

A station change takes 3 seconds while stationary. One person occupies one station and cannot simultaneously drive and operate a gun. A wounded station occupant must be physically extracted before replacement. Crew carry their own gear under the 25 kg personal limit. Personal rifles are optional self-defence issue, not a prerequisite to drive, and are never automatically manufactured with a hull.

The vehicle commander is also its element leader. If that station is vacant, a remaining qualified crew member acts as leader without filling two physical stations at once. T03's gunner leads its element, while T01 and T02's driver leads theirs. Undercrewed vehicles do not start ordinary offensive missions, but surviving stations can defend or withdraw. A Fleet Transfer may move an incomplete hull to HQ with a single P08 driver, reporting Not Combat Ready until command supplies the missing crew and ammunition.

T03 turret turn rate is 90 degrees per second, T04 is 60, and T05 is 45. The gun must align within 5 degrees before release. T03 moving fire multiplier is 0.55, T04 is 0.75, and T05's main gun is 0.60. Stationary fire uses 1. The tank gunner cannot release main and coaxial fire simultaneously; changing weapon takes 1 second. The loader can reload the main gun while the gunner uses the coax. The tank prioritizes its main gun against armoured vehicles and structures and coax against exposed infantry, unless an infantry cluster of at least four justifies a shell with a safe blast area.

### 9.4 Armour and ammunition

| Type | Front | Side | Rear | Top | Bottom |
| --- | --- | --- | --- | --- | --- |
| T01 | 0 | 0 | 0 | 0 | 0 |
| T02 | 0 | 0 | 0 | 0 | 0 |
| T03 | 0 | 0 | 0 | 0 | 0 |
| T04 | 35 | 20 | 12 | 10 | 15 |
| T05 | 100 | 65 | 40 | 25 | 45 |

Front is within 60 degrees of hull facing, rear within 60 degrees of the reverse, and other horizontal hits use side. Indirect fire uses top; pressure anti-vehicle mines and road IEDs use bottom. A shot penetrates when its penetration is at least that surface's armour. Failure deals zero hull health damage. Successful penetration deals the weapon's vehicle damage after blast falloff if applicable. Nonpenetration does not silently become percentage damage that lets enough rifles destroy a tank.

T03 targets 900 E02, maximum 1,200. T04 targets 180 E26, maximum 240. T05 targets 30 E25 and 900 E02, maximum 40 and 1,200. Loaded rounds are included in these totals. Racks are distinct from freight and passenger inventories. No vehicle fires ammunition still on another truck, at HQ, or reserved for it. Reload requires the same vehicle's actual rack stock.

Armoured compartments protect occupants from ordinary nearby small-arms and blast injury while the hull remains functional. A penetrating cannon or indirect hit dealing at least 35 hull damage also inflicts 10 injury on each occupant, once per shot. A shot that destroys the hull instead uses the destruction occupant rule, not both rules. T03's exposed gunner can be directly targeted with a 0.65 hit multiplier from the mounting cover. Other seated occupants cannot be selected separately through the hull. An incapacitated person's gear remains physically inside until extraction or ejection.

### 9.5 Damage recovery and towing

At or below 50 percent health, maximum vehicle speed is multiplied by 0.75. At or below 25 percent it becomes Damage Immobilized. A surviving anti-vehicle mine or road IED hit causes Damage Immobilized regardless of remaining health. Fuel Empty, missing driver, damage immobilization, and Terrain Stranded after loss of a supporting surface are separate reported conditions.

At zero hull health the vehicle is Destroyed. Each active occupant receives 60 injury and 80 suppression, then is ejected to the nearest passable adjacent position within 8 metres. Health reaching zero creates an incapacitated person. An already incapacitated occupant receiving this further damage dies. If the wreck is in deep water or no adjacent survival location exists, occupants die; swimming and rescue boats are disabled. A destroying attack does not apply its own external blast to the same ejected people a second time. Later attacks can harm them normally.

Half of each loose freight and loaded-plus-stowed vehicle ammunition quantity survives, rounded down. Fuel, mounted weapons, and the hull are lost. Surviving goods form an owned wreck pile. Deep-water destruction instead loses all cargo and vehicle ammunition; submerged salvage is unavailable in this roster. Dead people's gear follows the normal drop rule where a reachable ground pile exists. A hull already Destroyed cannot be repaired or towed into a working vehicle. A land wreck blocks its physical footprint until engineers clear it using 20 M11 and 60 work seconds; clearing a wreck produces no extra Metal.

An engineer with E08 restores 100 hull health for 10 M11 and 40 work seconds, capped at maximum. Up to two P02 contribute simultaneously to one vehicle. Clearing Damage Immobilized requires a distinct 20 M11, 60-work-second repair; it also restores 100 health once. Mobility returns only if health is above 25 percent, a driver is present, and fuel exists. A full-health vehicle cannot consume a health-repair action. Work requires stationary accessible vehicles and no visible hostile within 150 metres or damage in the past 10 seconds. A repair point supplies a suitable location, not free repair materials or engineers.

T01 can tow a disabled technical or field gun up to 3,000 kg total towed gross mass. T05 can tow up to 35,000 kg. Attaching or detaching needs one P02 with kit and 20 active seconds while both vehicles stop. Cable and towing fittings are reusable parts of the vehicle and kit; no consumable tow item is created. The tractor cannot fire while towing. Gross bridge load is the sum of tractor and towed object, including any remaining people and stock. A fully loaded tank towing another fully loaded tank fits B03's 80-tonne limit but cannot use B02. Towing is recovery, not repair.

## 10 Strategic delivery and forward logistics

### 10.1 Mission modes and physical preparation

Strategic Delivery is available to T01 and T02. The player specifies cargo and passengers; the returning crew and hull remain part of the rear fleet. At HQ the army receives only the disembarking passengers and unloaded freight. Fleet Transfer permanently hands the hull, crew, passengers, internal fuel, and ammunition to military command at HQ. Every vehicle type supports Fleet Transfer when it has a qualified driver and a legal route.

Payload, passenger seats, and crew stations are independent limits. A manifest exceeding any one is unavailable and identifies the excess. Automatic multi-vehicle splitting is disabled; a convoy is a player-authorized group of individually valid manifests. An otherwise empty Fleet Transfer is valid because the hull itself is the delivered asset. Passengers need not have personal weapons before leaving the rear; HQ command issues from actual stock.

Requested, Staging, Ready, Loading, Loaded Waiting Dispatch, Departed, Transit, Arrived, Unloading, Complete, and Cancelled are manifest states. Returning and Parked belong to vehicles. Ready means every requested good is at the assigned Dispatch Bay or already aboard the assigned vehicle, and selected people are waiting or aboard. Heavy pickup can occur during Staging. A field gun collected at Vehicle Works is onboard, not falsely counted as Dispatch-staged.

The inspection columns are requested totals, committed reservations, current staged amounts, current onboard amounts, cumulative arrived amounts, and cumulative unloaded amounts. They are not additive inventories. Cancelling before departure releases uncollected reservations and creates real return or unloading jobs for collected goods. Departure is irreversible this trip. Complete means the final item or receiving person has actually unloaded or disembarked. Partial dispatch is disabled; the player can edit the manifest before departure.

### 10.2 Travel and handling

The reference rear exit connects to the friendly battlefield entry by a safe off-map road leg of 1,000 metres. Travel time and fuel derive from vehicle speed and this distance, rather than an unrelated fixed timer. The same vehicle and its exact cargo remain in transit. Terrain distance within the rear and the 400-metre battlefield entry-to-HQ route add actual travel. At 12 metres per second, T01's off-map leg alone is 83.33 seconds and consumes 2 fuel; T02 takes 66.67 seconds at 15 metres per second and also consumes 2.

Goods need normal 2-second pickup and drop handling per worker load. Boarding and disembarking take one person per second per vehicle, excluding already seated crew. A vehicle must stop at a valid safe boarding position with a legal exit tile; people walk to it rather than teleport. Fleet crew are assigned before departure and physically report. Personal gear counts as passenger or crew load in the appropriate limit.

HQ has two receiving berths, 20,000 kg stock, 96 reserve places, 12 recovery places, four initial logistics staff, and a Commander. Staff and Commander are real people. Cargo waits onboard when stock is full; people wait onboard when their receiving capacity is full. Unloaded stock becomes available, while reserves become usable only after disembarking. Driver or operator death does not cancel the physical inventory ledger.

HQ logistics assigns available reserve people to replace lost staff before forming new ordinary squads, up to four actual logistics staff. Service duty preserves each person's identity and qualification. HQ medics, engineer service, and forward depot staff come from military people, not generated staff. The initial fixed HQ five are separate from the flexible recruit pool; losses remain recorded.

### 10.3 Forward supply and transport roles

Military T01 carries materials, fuel, ammunition, and medical supplies to forward depots, caches, construction sites, and stationary operating units. T02 carries formations and replacements. T04 transports one squad while also providing fire support; it cannot transport a second squad in its crew stations. T03 escorts and supports from range rather than serving as a substitute armoured carrier. T05 has no passenger seats.

Unloading and local hauling use actual people: depot staff, guards temporarily assigned to handling, engineers, or a parked vehicle's driver after vacating that station. Personal equipment reduces remaining carry allowance. A person assigned to carry does not simultaneously fire, construct, treat, or operate a crew station. The delivery planner names its unloading help before departure; without help the truck reports Waiting for Handling rather than dumping an entire load into a remote inventory. No unnamed labour force appears at a construction site.

Command creates forward delivery missions, reserves source stock, loads real goods, and names an unloading destination. A cache is self-service; a depot has two assigned people for receiving and issue. A supplied unit must physically collect at a depot, rendezvous with the carrier, or receive an actual carry from nearby staff. The supply truck's presence within an arbitrary radius never causes instant inventory refill.

New replacements leave HQ in a real troop transport or under a secured armed escort. They remain recorded on transfer duty and count against the military person cap. They join the recipient squad only when both meet. A squad cannot receive remote people by reducing HQ reserve count alone. Wounded return along the same physical routes.

Forward depots can be built anywhere with an engineer presence, a legal footprint, and a feasible supply route. There is no 150-metre HQ tether in this edition. A cut route stops new deliveries while existing accessible local stock remains usable. Command can rebuild a bridge, create a bypass, transfer goods through a footbridge by haulers, or withdraw; it cannot assume every route is passable to every vehicle.

### 10.4 Safe route decisions

Route choice first excludes impassable terrain, overload, width and turn failure, insufficient fuel, and known armed devices. A military supply planner may divide demand into several explicitly recorded loads that fit a route's lower bridge limit. This does not authorize silently sending a player manifest partly complete; the player edits that manifest or chooses another route. Among remaining routes, prefer the shortest expected travel time that does not enter an observed hostile effective firing area. The company can authorize a protected combat convoy only when an escort and an explicit suppression or armour plan exists; an ordinary resupply order cannot override that restriction silently.

If a route becomes unsafe, the driver stops at the latest safe waypoint, reports, and waits up to 10 seconds for a safe local alternative. It then returns toward supply if a safe route exists; otherwise it remains in cover and requests assistance. Expiry of a timer never authorizes driving into known mines. A new bridge or cleared mine updates route access only for units receiving that information.

No military AI may commandeer a rear Strategic Delivery hull or its returning crew during this edition. The player selects Fleet Transfer explicitly. This makes vehicle and manpower commitments legible and avoids silently removing the rear's last supply vehicle.

## 11 Military organization and capability

### 11.1 Hierarchy and force limits

An infantry squad targets eight people. A platoon has up to three infantry squads and two attached vehicle elements; a company has up to three platoons and two additional service vehicles. An army has up to three companies, nine platoons, twenty-seven infantry squads, and twenty-four military vehicles. The total of active military people, crew, service staff recruited from reserves, and assigned transfers is limited to 384, excluding the initial fixed HQ five and transient leased service drivers. HQ unassigned reserve capacity is separately 96. Infantry squad capacity is 216 people. Rear-owned strategic vehicles are separately limited to eight and need actual parking. Rear Strategic Delivery and temporary leased delivery hulls are not military fleet slots; the latter are bounded by at most three incoming delivery services. Their people and hulls still have real locations and separate service-ledger counts.

These are scenario caps, not a claim that all elements are infantry. A vehicle is an element with its actual crew, parent, mission, capability, and passengers. A squad riding in an APC remains a separate squad, with the same roster, and contributes no dismounted fire or capture until it exits. Service teams can be assigned under a company without inventing a below-minimum combat squad. Their people and gear still count.

Squad leaders are trained active members, with an acting conscript exception. Platoon and company appointments use existing trained subordinate leaders, creating no people. A person can hold a squad appointment and one senior appointment. If too few eligible people exist, senior responsibilities remain temporarily delegated to the next higher living leader with a reported command shortage. Losing a leader causes a 5-second replacement delay; existing intent and immediate survival continue. Losing the HQ Commander appoints the highest eligible trained senior leader as acting Commander without moving that person or duplicating them.

### 11.2 Infantry loadouts

All rifle and marksman carriers in a minimum package need at least 30 matching rounds. Desired quantities below scale with actual people for personal weapons; fixed crew equipment stays fixed. Optional helmets and armour are issued after mandatory load. Crew weapons and mission freight can be transported separately when personal carrying limits require it.

| Squad | Desired eight-person composition and load | Minimum ordinary deployment |
| --- | --- | --- |
| Rifle | Eight generic people; one E01 and 60 E02 each | Four people, rifle and 30 rounds each |
| Machine gun | Two P04 and six guards; one E05, 360 team E02; guards each E01 and 60 E02 | Four including two P04; gun and 180 team rounds; guards armed with 30 each |
| Mortar | Three P04 and five guards; E06, twelve E07, one E18; guards rifle and 60 each | Four including three P04; mortar, six bombs, radio, armed guard |
| Engineer | Two P02 and six guards; two E08; rifle and 30 each; M11 and M06 are mission freight | Four including two P02 and both kits; all armed with 30 each |
| Medical | Two P03 and six guards; two E11, twelve E12, two E21; rifle and 30 each | Four including one P03, one kit, three packs, one stretcher, armed guards |
| Artillery | Four P05 and four guards; E13, twenty E14 delivered locally, E18; guards rifle and 60 each | Six including four P05; gun, ten shells, radio, armed guards |
| Reconnaissance | Two P06 and six guards; E15, E16, three E17, E20; rifle and 30 each | Four including one P06, drone, controller, battery, armed guards |
| Marksman | Two P07 and six guards; two E19, two E20, six E01; 60 E02 each | Four including one P07 with marksman rifle and binoculars; others rifle; 30 rounds each |

Only actual issued goods count. Equipment is assigned to qualified holders first, ammunition to compatible least-loaded holders next, protection last. Armour is withheld if mandatory personal load would exceed 25 kg. An engineer carrying a full kit and rifle has less room for Building Materials or Explosives; large projects therefore require a carrier.

### 11.3 Readiness and creation

Readiness is the lowest of personnel fraction toward eight, mandatory equipment fulfillment, and ammunition fulfillment, each capped at one. Each fulfillment uses the least-satisfied required type, not an average that hides a missing radio or empty shell supply. Vehicle readiness uses actual required crew stations, health fraction, mission ammunition target, and fuel required for the assigned route. Explicit capability checks always override a numerical readiness score.

Organization prioritizes HQ survival, replacements for existing capable formations, restoring ammunition, then new formations. A new squad needs its type-specific minimum, including six for Artillery. Command avoids spreading scarce equipment across many unusable groups. It retains specialists for compatible roles unless immediate HQ survival requires otherwise. New vehicle crew are drawn from actual qualified reserves; an empty hull does not manufacture its own operators.

New squad priorities are Rifle during HQ threat; Medical when two reachable untreated wounded need support; Engineer for a blocked required route, mine hazard, or approved infrastructure project; armour for a known hostile armoured threat; indirect support against defended cover; reconnaissance before an unobserved advance; machine guns or marksmen against their suitable observed targets; then Rifle. Ties prefer the highest-value blocked parent mission, then oldest demand. Crew and equipment availability determine which candidates are feasible.

Prepare Assault raises participating rifle and marksman carriers' ammunition target to 90 each, requiring physical issue. Vehicles prepare their full listed target ammunition and enough fuel for the operation and fallback. The ordinary 60-round loadout does not secretly prevent the army from ever meeting an assault condition. When the mission ends, excess carried rounds remain until used or returned.

## 12 Combat observation and survival

### 12.1 Infantry actions and hit resolution

Infantry move at 2 metres per second on open ground, 1.5 while tactically engaging, and 2.5 while withdrawing without firing, then apply terrain and armour factors. Ordinary sight range is 220 metres; stationary binoculars after 3 seconds give 350. Weapon range does not automatically become sight range. A field gun's aimed direct observation reaches 650 while deployed. Active vehicle commanders provide their listed sight; without one, remaining crew supply at most 220, except the technical gunner's 250. No camera view grants AI enemy knowledge.

Direct hit chance is base chance times training, range, shooter movement, target movement, cover, and suppression. Range factor is 1 minus 0.5 times distance divided by maximum range. Infantry shooter movement is 0.60; mounted gun movement uses its vehicle value. A moving target multiplies chance by 0.80. Suppression factor is the greater of 0.20 and 1 minus suppression divided by 125. Final probability is clamped 0.05 to 0.95 only after valid range, target, sight, and firing-line checks. Vehicle hull targets ignore infantry ground-cover bonuses unless an actual opaque obstruction blocks them. Infantry target size is 1; drone size is 0.40; vehicle size is 1.25 before the final clamp.

Helmet and body armour reduce direct small-arms infantry injury by 5 and 15 percent, additive to 20. They do not reduce cannon blast or vehicle-spall injury. Direct shots are withheld if a friendly person lies within 0.5 metres of the line or a friendly vehicle intersects the line before its target. Blast can damage either side. Indirect safety includes the entire scatter circle plus damage radius plus 5 metres for known friendlies. A shot that may collapse a bridge also checks all known friendly occupants of that span, not only those near its impact.

### 12.2 Capability before force ratios

An infantry rifle has no ability to penetrate T04 or T05 armour. A platoon with many rifles and no valid anti-armour capability cannot treat numerical superiority as permission to assault an observed tank. Valid responses include avoidance, covered withdrawal, a flanking autocannon attack against a penetrable surface, a field gun, friendly tank support, or an engineer mine and obstacle plan. Command requests the missing capability and states its effect.

Strength estimates guide choices only after capability and route checks. An active rifle carrier contributes 1, marksman 1.5, operational machine gun team 2, mortar 2, direct-capable field gun 4, technical 3, armed APC 6, and tank 10. Multiply infantry by health fraction and suppression factor 1 minus suppression divided by 200. Defending dismounted strength uses a 1.3 modifier in heavy cover and 1.15 in light cover. Crew weapons use average active operator factors; vehicles use hull health fraction and actual operational stations. Empty, broken, uncrewed, or ineligible weapons contribute zero to the action they cannot perform. Transport passengers contribute only when a legal dismount is planned, not as firing occupants.

### 12.3 Suppression morale and cohesion

A directed rifle or marksman shot adds 4 suppression even on a miss, W02 adds 8, and a person within 5 metres beyond a damaging blast radius receives 20 once per explosion. Apply training multiplier and cap at 100. After 3 seconds without incoming fire suppression declines by 5 per second. At 60 a person is Pinned and cannot advance into a threat, but can fire, seek nearby cover, or withdraw. They leave Pinned below 40.

Morale begins at 60. A nearby friendly incapacitation within 20 metres costs 8, subsequent death costs 4, blast injury costs 10, and loss of an occupied vehicle costs its surviving occupants 20. Capturing an objective gives participants 5. After 10 seconds safe from incoming fire, nearby casualty, and visible hostile within 100 metres, morale recovers toward 60 at the training rate. Below 20 the person Breaks and seeks fallback; at 40 in safety they may rejoin.

An armoured crew does not receive full suppression from every rifle miss outside its hull. Nonpenetrating fire adds 2 per event, capped at 30 from that source alone; a penetrating hit adds 20. Crew Break causes withdrawal when a qualified driver can act. A pinned driver may withdraw but not advance toward the threat. Crew never jump out of a moving vehicle to satisfy individual cover-seeking.

Squad cohesion is active dismounted people within 30 metres of their leader divided by active dismounted people. A fully boarded squad uses coherent boarding status instead. Below 0.5, offensive coordination pauses for up to 10 seconds to regroup; continued failure reports Dispersed and triggers fallback. Transporting a squad does not divide its people into independently strategizing passengers.

### 12.4 Wounds recovery and dropped stock

At zero health a person is Incapacitated and has 60 seconds until bleed-out. Further positive injury kills them. AI never deliberately targets an incapacitated person, although blast and released shots can. Active injured people remain active until assigned treatment. Incapacitation drops carried personal equipment at the person's real location, retaining loaded ammunition inside the dropped weapon; worn protection stays on the body until death. Inside a vehicle, those holdings stay in that vehicle until extracted or ejected.

An intact dropped item remains usable. Loose piles are not individually destructible after container salvage is resolved. They persist until collected or engagement end. A person restored by treatment must physically recover or reissue missing equipment. Death releases their formation place and creates one loss record. No death or reward can count the same person twice.

## 13 Engineers infrastructure defences and explosives

### 13.1 Engineering work contract

The military hierarchy selects battlefield sites and projects. The player supplies personnel, tools, Building Materials, Explosives, vehicles, and priorities in the rear. An engineer uses E08 and must physically reach the site. Up to four P02 provide one work second each per second to one ordinary project; two are the minimum crew for bridge construction and deliberate bridge demolition. Work needs no visible hostile within 150 metres and no site damage in the previous 10 seconds. Guards can defend while engineers work; engineers cannot fire and contribute construction work simultaneously.

All construction consumes M11 only. A complete project's material quantity must be physically staged within its site supply area before work starts, and is consumed once at start. The site's temporary storage capacity is the exact required quantity; it does not become a free permanent depot. Hauling or arranging materials is work separate from active construction. Pausing preserves progress. Cancellation before consumption returns all staged stock. After start, cancellation returns half consumed M11 as a real pile and loses the rest. An unfinished durable structure has one quarter of completed maximum health and is not operational. S11 is a non-damageable terrain overlay without a health value and provides no completed road benefit until work finishes.

Field repairs also consume M11, with the vehicle rules above. Ordinary structures restore 100 health for 10 M11 and 40 work seconds; one engineer can work, two can cooperate. No repair raises maximum health. Destroyed ordinary structures require rebuilding from their full blueprint. No separate repair-pack resource remains.

### 13.2 Infrastructure and defences

| Structure | Footprint metres | M11 cost | Work seconds | Health | Effect |
| --- | --- | --- | --- | --- | --- |
| S01 Trench | 20 by 2 | 100 | 200 | 1500 | 8 infantry; heavy cover 0.40 |
| S02 Sandbags | 10 by 1 | 25 | 60 | 500 | Protected side cover 0.65; infantry crosses at 0.8 speed |
| S03 Bunker | 8 by 6 | 300 | 400 | 3000 | 8 infantry; front 120 degree ports; cover 0.25; blast multiplier 0.25 |
| S04 Wire | 20 by 2 | 20 | 40 | 250 | Blocks infantry and wheels; tanks can crush it |
| S05 Vehicle obstacle | 10 by 4 | 150 | 180 | 1800 | Blocks wheels and tracks; infantry speed 0.70 |
| S06 Forward cache | 6 by 6 | 100 | 150 | 600 | 2,000 kg; 16-person rendezvous; self-service |
| S07 Forward supply depot | 12 by 12 | 300 | 480 | 1500 | 10,000 kg; 2 truck berths; 2 actual assigned logistics staff |
| S08 Aid post | 8 by 8 | 150 | 200 | 800 | 8 patients; no free medic or healing |
| S09 Repair point | 10 by 10 | 200 | 240 | 1200 | One vehicle or gun; requires engineers and BM for each repair |
| S10 Lookout post | 4 by 4 | 60 | 120 | 600 | One actual trained observer and binoculars; 500 m sight |
| S11 Road segment | 20 by 6 | 40 | 80 | Not applicable | Movement overlay; no wear or direct damage in this edition |
| S12 Causeway segment | 20 by 6 | 100 | 160 | 1200 | Raised swamp road; cannot bridge deep water |

A bunker has front firing ports over a 120-degree arc set by its construction facing. Its eight actual occupants use their own issued weapons and ammunition. At most one portable machine gun can be deployed within it, using its qualified crew and normal setup; that consumes two occupancy places. No empty bunker fires. Entering or leaving takes one person per second at a valid entrance. Enemy occupants prevent entry; abandoned structures can be occupied as cover, but enemy caches and depots cannot be looted into ownership automatically.

S03 cover affects direct hit chance; blast protection multiplies injury by 0.25. S01 trench gives direct multiplier 0.40 and blast multiplier 0.50. Trenches have entry points every 10 metres and cannot contain vehicles. Wrecks and town ruins are separate obstacles. A T05 crossing wire or sandbags crushes the contacted segment after 3 seconds at 0.25 speed, receiving no hull injury; other wheeled vehicles cannot use that as an assumed route until it is clear. Vehicle obstacles block tracks too and require clearance or demolition.

Removing wire needs one engineer, kit, and 20 work seconds per segment with no consumables. Dismantling a vehicle obstacle needs 120 work seconds or enough M06 demolition for its health. Cutting a farm fence needs 5 work seconds per 5-metre segment. Clearing a tree requires 10 work seconds, and a small boulder 2 M06 and 20 work seconds; removed props become passable ground and yield no free Timber or Metal. Cliffs and whole mountains cannot be erased with this action.

A road overlay is buildable only on dry passable ground with at most 10 degrees slope. S12 causeways can cross shallow swamp or bog edge, not deep water or cliff. Their constructed surface has road movement values and 8-tonne load limit, enough for troop trucks and technicals but not fully loaded T01 or armoured units; a heavy causeway upgrade doubles its M11 and work and raises the limit to 80 tonnes. The upgrade must finish with the segment empty before heavy access changes. Sound generated arterial roads use heavy foundations wherever required, so starting heavy routes do not depend on an unaffordable upgrade.

Destroying a causeway removes its surface and restores its base terrain. A wheeled vehicle over now-impassable mud becomes Terrain Stranded without automatic hull damage; tracks and people may leave only if the base terrain permits them. A health repair alone does not restore access. Rebuilding that same causeway may support the stationary stranded vehicle while the segment remains closed to other traffic; completion restores the legal surface. Compatible towing is an alternative only where its whole route is traversable. Deep-water bridge collapse instead uses its lethal span rule.

Forward caches, depots, aid posts, repair points, and lookout posts require actual people for their active services. An empty aid post does not heal, a repair point does not repair, and a lookout without observer and binoculars does not reveal enemies. Limits are one supply depot, two caches, one aid post, and one repair point per company, plus four lookouts per army. Ordinary trenches, sandbags, and obstacles have a total army limit of 100 active segments; bridges use a separate limit of six newly built crossings. These caps are visible scenario defaults.

### 13.3 Bridge catalogue and crossing access

| Bridge | Width metres | Maximum span metres | Maximum load kg | M11 per metre | Work per metre | Health formula |
| --- | --- | --- | --- | --- | --- | --- |
| B01 Footbridge | 2 | 20 | 1000 | 10 | 10 | 800 plus 20 times span metres |
| B02 Light road bridge | 6 | 30 | 10000 | 40 | 20 | 2000 plus 50 times span metres |
| B03 Heavy road bridge | 8 | 60 | 80000 | 80 | 40 | 4000 plus 100 times span metres |

Bridge span is the clear water width between stable bank endpoints, rounded up to a whole metre. The footprint includes the stated width across the entire span plus 5 metres of approach at each end. Both endpoints need land support and legal access from at least one friendly bank. A bridge can be constructed from the friendly side without already owning the far bank, using the project's whole span; a visible enemy within 150 metres or damage to the site prevents active work. This avoids requiring the completed crossing before it can be built.

All bridge inputs are M11; no steel beam or concrete sub-resource is required. Cost and work are per metre times span. Maximum health is the listed base plus listed per-metre health. A 30-metre B03 costs 2,400 M11, requires 1,200 work seconds, and has 7,000 health. Four engineers need 300 active seconds after delivery. A 20-metre B02 costs 800 M11 and 400 work seconds. A B01 permits infantry and stretchers, not any vehicle.

Gross load includes the complete vehicle, people, gear, freight, fuel, ammunition, and any tow. One vehicle or one explicitly coupled towing combination occupies a bridge at a time; infantry wait clear while that vehicle crosses. This prevents two separately valid heavy vehicles from collectively exceeding a bridge's limit. On B01, at most eight people occupy the span and their actual combined mass must remain at or below 1,000 kg. No overload route is permitted. B02 admits all listed soft vehicles fully loaded, but not T04 or T05. B03 admits every listed vehicle and one tank towing another within 80 tonnes.

Bridge entry speed is at most 4 metres per second, with a holding point 20 metres from each bank. Known mines or hostile units on an approach block ordinary supply crossing. Traffic gives an occupied crossing time to clear rather than sending opposing friendly vehicles into each other. Two sides fighting over an entrance do not gain a ghost right to pass through the other side.

### 13.4 Bridge damage repair and denial

At or below 50 percent health a bridge is Damaged: maximum crossing speed 2 metres per second and load limit half its original value. At zero it is Destroyed and the whole span becomes unusable. Its endpoints remain repair sites. Current gross load is checked before entry; a bridge damaged below the load of an already crossing vehicle does not automatically collapse, but subsequent fire can destroy it. A full destruction kills people and destroys vehicles still on its water span; no amphibious rescue exists in this roster. Other entities outside the span are affected only by the actual attack's damage.

Repairing a damaged bridge restores 100 health for 10 M11 and 40 work seconds, up to four engineers. Rebuilding a destroyed span costs its full original M11 and work, from either accessible bank, and creates the same bridge class unless a new blueprint is explicitly chosen. Upgrading a sound B02 to B03 is allowed only within B03 span and footprint limits, costs the difference between those classes' full M11 and work for that span, and closes the crossing until complete. Health becomes B03 maximum on completion; no partial upgrade enables early heavy crossing.

Engineer demolition reserves M06 equal to known current target health divided by 500, rounded up, minimum one; use full type health when damage is unknown. The authorized quantity stays fixed unless the project is explicitly revised before consumption. Two P02 must reach within 2 metres of an accessible bridge endpoint or target structure. Placement work is 10 plus 2 times the M06 quantity, shared by at most two engineers. Stock is physically carried or staged within 10 metres, and is consumed when placement finishes. An interruption before finish preserves unconsumed stock and project work; it cannot create a half-armed free charge.

After placement the squad withdraws at least 25 metres. The charge takes 10 seconds to arm. It can use a 5-second fuse after the clearance check, or Remote Denial mode controlled by a living P02 with kit within 300 metres. Remote control is a reusable function of E08, not another consumed electronics resource. Its trigger is an observed assigned hostile vehicle on the span, or an explicit command order to deny the crossing. Command never knows an unseen vehicle is on a bridge through hidden entity information.

Detonation applies 500 structural damage per consumed M06 to the assigned target and a separate 8-metre blast of 200 infantry injury with vehicle penetration 60 and maximum hull damage 200. The target takes the larger applicable damage, not two copies. Detonation is withheld while a known friendly occupies the affected bridge or the blast plus 5-metre safety margin. If the operator leaves range, dies, or lacks information, a remote charge remains planted and inertly waiting until another qualified operator physically assumes it. One armed remote demolition project per engineer squad is allowed.

Bridge denial needs a company or Commander order, rather than a squad destroying a convenient route without regard for its own army. An authorized denial may target an unowned world bridge or a friendly-built bridge as well as an enemy one; third-party ownership is not required. Before authorization, command checks friendly retreat, forward supplies, wounded evacuation, and an alternate crossing or restoration plan. Emergency denial to stop a direct HQ assault may strand a force, but the order and consequence must be reported. The existence of two starting routes does not guarantee they remain usable after player-caused battlefield changes.

### 13.5 Mines and road explosive devices

| Device | M06 cost | Placement work | Arming | Trigger and effect |
| --- | --- | --- | --- | --- |
| D01 Anti-personnel mine | 1 | 8 seconds | 10 seconds | Any dismounted person within 1 metre; 90 infantry blast injury within 5 metres; penetration 5 |
| D02 Anti-vehicle mine | 3 | 12 seconds | 10 seconds | Any moving wheeled or tracked vehicle within 1.5 metres; 650 hull damage, bottom penetration 160, survivor immobilized; infantry blast 100 within 4 metres |
| D03 Road IED | 4 | 20 seconds | 10 seconds | Qualified remote operator within 300 metres and an observed hostile vehicle in its designated 6-metre trigger zone; 900 hull damage, bottom penetration 180, survivor immobilized; infantry blast 120 within 6 metres |
| D04 Attached demolition | Health-based as above | Health-based as above | 10 seconds | Assigned structure or bridge; the section 13.4 contract |

D01 and D02 are not magically faction-selective. Known friendly devices are excluded from friendly routes, but a unit forced onto one can trigger it. Trigger distance for a vehicle is measured from its physical footprint entering the trigger circle, not only its centre marker. Infantry do not trigger D02; vehicles do not trigger D01. D03 is command-triggered and withheld for known friendlies within its damage radius plus 5 metres. Placement requires safe access, kit, and actual Explosives; no separate manufactured mine item exists. The resource is consumed at completed placement, then the object arms after the clear delay.

A device occupies one metre, must be at least 4 metres from another device, and has 20 health once placed. There are at most 96 pressure mines per army and one armed D03 or D04 remote project per engineer squad in total. Enemy devices are hidden until detected, triggered, or revealed by observed placement. An engineer stationary with kit scans a 20-metre radius for 3 seconds to reveal devices with a clear ground sight line. Drones cannot reveal buried pressure mines automatically. Known hazard markers identify location, class, and last observation; they do not disclose the opponent's unseen mine stock.

Disarming a revealed device takes a P02 with kit within 2 metres and 12 active seconds. It returns no Explosives. A deliberate shot or blast causing 20 damage makes a revealed device inert without a sympathetic explosion. No random disarm failure applies. A trigger during placement or before arming does not detonate the object. Discovery or one triggered mine causes the platoon to mark the surrounding 30 metres hazardous, stop ordinary convoys, and request an engineer sweep or another route.

## 14 Terrain movement cover and natural features

### 14.1 Terrain catalogue

Every tile has one dominant traversal class plus height and explicit overlays or obstacles. A road or intact compatible bridge replaces the base surface movement restriction only along its completed footprint. It does not remove a nearby cliff, building, tree, or excessive slope. Terrain multipliers apply to the unit's base movement speed. Zero means forbidden, not very slow. Use the most restrictive applicable movement limit rather than multiplying unrelated terrain classes together. Terrain fuel factor applies to distance travelled; blocked routes consume no imaginary traversal fuel.

| ID and terrain | Infantry speed | Wheeled speed | Tracked speed | Direct hit multiplier | Sight cost per metre | Fuel multiplier | Restrictions |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TR01 Open field | 1 | 1 | 1 | 1 | 0 | 1 | Dry open ground |
| TR02 Road | 1.1 | 1.5 | 1.5 | 1 | 0 | 1 | 8 metre arterial; terrain grade still limits access |
| TR03 Farm and harvested crop | 0.95 | 0.85 | 0.95 | 0.85 | 0.2 | 1.1 | Fences are separate removable obstacles |
| TR04 Tall crop | 0.85 | 0.7 | 0.85 | 0.8 | 0.5 | 1.3 | No vehicle concealment bonus |
| TR05 Light forest | 0.8 | 0.45 | 0.65 | 0.65 | 1 | 1.8 | Tree trunks block occupied footprints |
| TR06 Dense forest | 0.65 | 0 | 0.4 | 0.5 | 3 | 2.5 | Wheeled travel forbidden; tracked vehicles still need trunk clearance |
| TR07 Rocky field | 0.75 | 0.4 | 0.65 | 0.5 | 0 | 2 | Boulders block footprints and sight locally |
| TR08 Town street | 1 | 1.1 | 1.1 | 1 | 0 | 1.2 | Building footprints block; alleys require clearance |
| TR09 Swamp | 0.5 | 0 | 0.35 | 0.8 | 1.5 | 3 | Tracked motion only in shallow swamp; deep bog is impassable |
| TR10 Shallow ford | 0.35 | 0.4 | 0.5 | 1 | 0 | 2.5 | Wheeled ford depth at most 0.35 m; tracked at most 0.8 m |
| TR11 Deep water | 0 | 0 | 0 | 1 | 0 | 0 | River, lake, or pond; no amphibious unit in this roster |
| TR12 Cliff or deep bog | 0 | 0 | 0 | 1 | 0 | 0 | Never passable without an explicit constructed crossing |
| TR13 Rubble | 0.7 | 0.35 | 0.5 | 0.6 | 0 | 2 | Remains of a demolished town building |

T01 to T04 are wheeled; T05 is tracked. People are infantry traversal class whether riflemen, engineers, or dismounted crew. Dense forest does not grant the tank permission to pass through tree trunks; it can use clear gaps with the listed tracked multiplier. No vehicle automatically removes a forest just by pathfinding through it. All classes require clearance for their own footprint and equipment.

Terrain cover values multiply direct hit chance against dismounted people in that cover; they do not stack with structure cover. The strongest physically valid benefit applies separately for the damage being evaluated. Natural blast-cover clarification, 26 October 2026: TR06 Dense forest gives a dismounted person actually occupying valid cover a blast injury multiplier of 0.5. TR07 Rocky field gives 0.5 only when an actual rock shields that person from the blast's impact origin; a terrain label, proximity or wrong-side rock is insufficient. Without usable impact/shield geometry, report missing or invalid eligibility rather than fabricating protection. TR01–TR05 and TR08–TR13, including light forest, swamp and rubble, have natural blast multiplier 1. These infantry benefits do not apply to vehicle hulls. Raised roads and exposed completed bridge decks provide no natural cover. Benefits never stack; existing trench 0.5, bunker 0.25 and actual town-garrison 0.5 blast multipliers remain unchanged. Direct-hit terrain values are unchanged. This is a proposed balance baseline, not a realism measurement or an implementation of integrated damage resolution.

### 14.2 Height slope and sight

Height is measured in metres. Up to 10 degrees slope allows normal terrain movement. Above 10 to 15 degrees, infantry multiply speed by 0.8, wheels 0.6, tracks 0.8. Above 15 to 25, infantry use 0.65, wheels are forbidden, and tracks use 0.5. Above 25 to 40, infantry use 0.4 and all vehicles are forbidden. Above 40 degrees all listed units are forbidden. Multiply the slope factor by the permitted dominant terrain factor. These are game traversal limits rather than claims about real vehicles.

A mountain region is shaped height, exposed rock, and cliff with explicit passes; it is not a uniformly impassable rectangular biome. A rocky field is traversable between boulders and can be flat. Swamp depth and marked ford properties decide where the table's permissions apply. Unmarked deep bog is forbidden even to tracks.

Sight requires range, height clearance, and a clear line. The line runs between the actual observer and target heights: dismounted observer eye 1.7 metres, vehicle driver 2, APC commander 3, tank commander 3, lookout platform 6 above local ground, and drone 40 above local ground. Terrain ridges and opaque footprints block a line passing through them. Weapon direct fire uses muzzle height of 1.5 metres for rifles, 2 for portable support positions, 3 for vehicle guns, and 1.5 for the field gun; no shot passes through a ridge just because a drone can observe the other side.

Vegetation uses a sight-obstruction budget of 100. Each metre inside concealing terrain spends the listed sight cost, including the total across mixed vegetation. Reaching 100 blocks ground observation beyond that point. Open terrain spends zero. Thus light forest allows about 100 metres through foliage and dense forest about 33, even with long-range optics. Standing behind a single tree can also be blocked by its opaque trunk. Drones ignore low crop obstruction but cannot see people hidden under dense tree canopy or inside opaque buildings. Smoke is opaque to ground and drone observation through its volume.

Height gives no automatic damage or accuracy bonus. Its advantage is actual sight, firing lines, approach access, and cover. Weapon range remains in metres on every map. Changing map size does not rescale a rifle into a kilometre-range weapon.

### 14.3 Water rivers and ponds

Rivers are continuous connected water paths, 10 to 80 metres wide in ordinary reaches, with deeper lakes and smaller ponds. Water follows terrain downhill or along a low valley toward a boundary or lake outlet. There is no waterfall crossing, freeze, flood, or changing water level during an engagement. River banks have stable, labelled bridge sites and optional marked fords.

A ford requires a firm bottom and approachable banks. Infantry ford depth is at most 0.6 metres; wheeled depth at most 0.35; tracked at most 0.8. If a marked ford supports only infantry, other classes cannot enter it merely because their own maximum differs. Ford properties state the permitted classes. Outside a valid ford or crossing, deep water is impassable to everyone in this roster. Ponds are not automatically shallow.

Generated crossing sites suitable for new bridges have span at most 30 metres for at least two alternate sites on a dividing river. Wider scenic river reaches remain possible, but they cannot be the only locations from which the army could restore connectivity. Every generated mandatory heavy bridge uses B03 width and load rules. Existing bridges may have longer spans as authored world structures only if a defined repairable blueprint exists; this edition avoids that exception by limiting mandatory crossing spans to 60 metres.

### 14.4 Towns farms and terrain objects

Towns follow roads, junctions, dry ground, and available slopes. They contain houses, stores, barns, gardens, fences, and side lanes. Farms sit in irregular adjacent field parcels with access to roads; their graphic boundaries follow terrain instead of tile noise. Forest edges, rocky outcrops, swamp margins, and water shores use broad patches and transitions. One-metre tile resolution must not look like randomly alternating one-metre terrain squares.

Town houses use an 8 by 6 metre footprint, 800 health, and up to eight infantry garrison places. Barns use 12 by 8, 1,000 health, and twelve places. Both are opaque, provide heavy direct cover 0.4 and blast multiplier 0.5 to actual occupants, and have front and rear exits and defined firing windows. Entering or leaving takes one person per second. People fire only through an unobstructed window within their weapon arc; a building does not let every occupant fire in every direction. Firing exposes that window occupant to valid direct return fire with garrison cover. Opposing people cannot enter an occupied hostile garrison; indoor melee is disabled. An empty garrison may be occupied by either army, changing its controller while its world ownership remains unowned. No civilian population is spawned.

At zero building health, occupants take 50 injury and exit to a passable position within 8 metres; an already incapacitated occupant dies from further injury. If none exists they die. The footprint becomes Rubble and loses garrison slots. Remaining gear is a real pile. A tank may traverse rubble at its terrain multiplier if it fits; it cannot drive through an intact house without first destroying it. Farms are visual and tactical terrain, not hidden requisition or food production.

## 15 Procedural battlefield specification

### 15.1 Scenario frame and strategic placement

Every campaign engagement generates a 4,000 by 6,000 metre battlefield before play. The long axis is north to south. The player HQ centre is (2,000, 400), enemy HQ is (2,000, 5,600), with entry gates at (2,000, 0) and (2,000, 6,000 boundary). Gates connect by heavy-access roads to their HQ. The final edge point is a boundary entrance, not a tile beyond the playable grid. A 300-metre HQ safe-start radius is dry, buildable, and free of enemy spawns or armed devices.

The world has exactly one HQ for each army, no neutral parties, and no additional hidden headquarters. Each HQ has 10,000 health, a 24 by 24 metre building footprint, and the logistics perimeter specified below. Destroying the opposing HQ wins. Both destroyed in the same simulation instant is a Draw. Players cannot relocate their HQ during an engagement.

Six Resource Objectives form three roughly corresponding lane pairs: nominal x positions 800, 2,000, 3,200, with one at y 2,600 and one at y 3,400 for each lane. Two Route Hubs lie near (1,000, 3,000) and (3,000, 3,000), and one Observation Objective lies near the central front. Exact sites can move up to 200 metres to valid dry terrain, subject to fairness checks. Resource objectives add 1.5 income each. Route Hubs provide useful road and depot access locations, not a magical permission radius for supplies. The Observation Objective gives stationary friendly binocular users within 30 metres an additional 150 metres sight, maximum 500, without revealing through opaque terrain.

Terrain and initial roads are known to both sides at start. Enemy people, vehicles, stock, mines, and orders remain under observation rules. Later bridge destruction, new structures, and cleared routes become known through actual observation and reports, except that a side always knows its own issued construction and device locations. Objective ownership is public strategic information; it does not disclose the occupying force.

### 15.2 Generation families

| Family | Selection weight | Terrain and intended contest |
| --- | --- | --- |
| River Valley | 40 percent | One meandering river crosses the middle front; two existing heavy bridges on separated lanes, plus alternate engineering sites |
| Lake District | 25 percent | One to three lakes with tributaries and ponds; two heavy-access land or bridge routes around major water; no single unavoidable shoreline trap |
| Highland Passes | 20 percent | Mountain and rocky regions with at least two heavy-access passes and one additional infantry approach |
| Farmland and Towns | 15 percent | Several irregular farms, three to six towns, fields and forest blocks, with connected roads and limited water obstacles |

Nominal exclusive dominant terrain budgets are shown below. Each tile belongs to one generation cover group for this budget; those groups can contain several traversal classes, such as light and dense forest, or cliffs and shallow rocky hills. Deep bog belongs to Swamp even though it uses the same impassable traversal class as a cliff. Town and water subtype placement, roads, tree props, and fine slope variation refine these budgets; they do not add percentages on top of the same area. Roads are an overlay over 0.5 to 2 percent of total area. Each dominant budget can vary by up to 3 percentage points, with the final selection still summing to 100 and passing all access tests.

| Family | Water | Forest | Rock hills and mountain | Swamp | Town | Farms and crops | Open fields |
| --- | --- | --- | --- | --- | --- | --- | --- |
| River Valley | 12 | 22 | 18 | 6 | 8 | 20 | 14 |
| Lake District | 16 | 24 | 18 | 8 | 6 | 14 | 14 |
| Highland Passes | 4 | 18 | 42 | 4 | 6 | 10 | 16 |
| Farmland and Towns | 8 | 14 | 8 | 4 | 12 | 34 | 20 |

The generator first establishes strategic anchors and broad landform intent, then water and height relationships, connected access corridors, terrain regions, settlements and fields, cover, and final placements. This is a required design dependency order, not a prescribed implementation algorithm. It may modify or reject a candidate to satisfy playability, but may not secretly shrink the map or remove a required vehicle type's access.

### 15.3 Natural appearance requirements

Rivers follow valleys, form continuous channels, and have banks rather than isolated zigzag water cells. Lakes occupy basins with plausible inlets or outlets where rivers connect. Mountains have continuous ridges and traversable lower passes. Forests grow as clusters with clearings and varied edges, with dense stands away from roads. Swamp clusters around low wet ground. Towns occupy buildable land and place entrances on their street network. Farm parcels use coherent field sizes rather than unrelated scattered crop tiles. Rock fields contain clusters and exposed outcrops with usable gaps.

Opposite halves need comparable strategic opportunity, not literal copied scenery. A town on one side may be balanced by wooded or rocky cover on the other if route and cover tests pass. Geometric symmetry is permitted for testing but is not the required presentation. Decorative objects cannot invalidate a route after access validation; final tree trunks, walls, bridge approaches, and town corners are included in that validation.

### 15.4 Mandatory playability and fairness checks

| Check | Required bound before acceptance |
| --- | --- |
| World and HQ count | Exactly 4,000 by 6,000 one-metre tiles and exactly two opposing HQs |
| Initial positions | Every initial person, vehicle, HQ, and stock location fits valid terrain with a legal exit |
| Gate to HQ | Heavy-road access for the heaviest enabled loaded and towed combination; opposite route travel times differ by at most 5 percent |
| Cross-front access | At least two spatially separate routes for infantry, ordinary wheeled transports, and fully loaded tanks between each HQ region and the central contest |
| Route separation | The two mandatory vehicle routes pass through central crossing or pass regions at least 800 metres apart; a single road junction or single bridge cannot sever both |
| River restoration | At least two bank-accessible alternate bridge sites span at most 30 metres; their approaches can receive a T01 from either corresponding home side |
| Resource opportunity | Sorted travel times to each side's nearest three resource points differ from the opposing side's corresponding times by at most 10 percent for infantry, T01, and T05 separately |
| Central contest | Each Route Hub and the central Observation Objective differ in fastest heavy-road travel time from the HQs by at most 12 percent |
| Cover balance | Central objectives have usable infantry cover within 150 metres on both approach sides; protected-person capacity differs by at most 25 percent |
| Home terrain burden | Outside safe-start zones, opposite home halves differ by at most 5 percentage points for water, dense forest, and impassable mountain coverage individually |
| Clearance | Vehicle footprints, turn radius, tow-combination turn clearance, road width, and bridge load all fit along required routes |
| Traversal limits | Required routes do not depend on forbidden slopes, unknown shallow water exceptions, impassable props, or an unbuilt bridge |
| Production recovery | Both sides begin with a viable transport and engineer path and access to the essential Building Materials and Explosives chain |
| Strategic variety | At least one terrain-driven flanking opportunity and one defensible operational location exist outside the HQ safe zones |

Travel comparisons use each class's actual terrain speed and access, not straight-line distance. Cover capacity counts usable protected positions with a view of the contest, not every decorative rock. Required access must survive removing either one mandatory prebuilt crossing in a dividing-river layout, while its alternate route remains. Destroying both crossings during play is a valid battlefield outcome, after which engineering restores access; the generator is not required to protect every route from war.

### 15.5 Seeds rejection and saved worlds

A campaign has a recorded 32-bit seed. Engagement index, campaign position, and selected family derive a fixed encounter seed under generation-rules version 0.2. A manually entered seed is available in a test scenario mode. Saving and loading never rerolls a layout, offer, device position, or resolved chance outcome. A new engagement gets a new encounter seed; replaying its engagement-start save preserves the original.

Try at most 100 candidates for an encounter, using fixed attempt variation from that seed. A candidate failing any mandatory check is rejected. If all fail, load a fully specified authored 4 km by 6 km fallback of the selected family's valid geometry, recording the rejection and fallback reason. A fallback is part of the implementation acceptance work and must pass the same checks before that milestone is complete; this document does not claim one has already been generated or validated in a running game.

Save the actual accepted terrain, props, structures, road and crossing state, seed, and generation version. An updated generator must not reconstruct an old save into a different world. Runtime destruction and engineering update the saved map and known-information state. Generation affects scenarios only in this edition; it does not invent randomized weapon statistics, resource types, or recipes.

## 16 Hierarchical military and service AI

### 16.1 Responsibility and decision timing

| Role | Main question | Regular reconsideration | Required fallback |
| --- | --- | --- | --- |
| Rear allocator | Where can available qualified people satisfy requested capacity? | On change, at most 2 seconds | Keep safe work and expose shortage |
| Worker | Which useful accessible task should I complete? | On completion; blocked check each second | Safe storage or recoverable pile |
| HQ organizer | What force and supply can actually be assembled? | 3 seconds | Repair current capability before unsupported expansion |
| Commander | How do we protect HQ and create a winning operation? | 10 seconds | Defend critical approaches and request the missing capability |
| Company | Which platoons and services complete this operation? | 5 seconds | Secure a corridor, stage, or withdraw |
| Platoon | How do squads and vehicles cooperate locally? | 2 seconds | Regroup and escalate an unsolved threat |
| Squad or vehicle leader | What action fulfills this role safely with current capability? | 1 second | Cover, dismount, defend, resupply, or withdraw |
| Individual or crew station | What immediate action executes the element's intent? | 0.25 seconds | Immediate survival and legal station function |

Immediate threats, capability loss, HQ damage, and casualties cause response within the next 1-second leader decision or 0.25-second individual decision, plus actual information delay. A high-level mission persists at least 10 seconds and a tactical action 3 seconds unless safety, feasibility, or parent intent changes. The army does not repeatedly reverse direction because of tiny score changes.

Intent contains desired outcome, purpose, constraints, priority, and fallback. Supported orders are Defend HQ, Hold Area, Seize Objective, Probe, Support Formation, Prepare Assault, Assault HQ, Move by Transport, Escort Convoy, Deliver Supply, Resupply, Regroup, Evacuate, Build Infrastructure, Secure Crossing, Clear Minefield, Deny Crossing, and Recover Vehicle. A subordinate acknowledges within 2 seconds after receipt or states why it cannot comply.

Reports cover contacts, progress, completion, inability, casualties, lost capability, low supply, blocked route, mine hazard, threatened crossing, and opportunity. The lowest capable echelon attempts a feasible local solution; after 10 seconds without one it escalates. HQ danger, more than 25 percent casualties in 10 seconds, or loss of required anti-armour or transport capability escalates immediately. Unchanged reports refresh useful data without repeating alerts.

### 16.2 Information and uncertainty

A current sighting has confidence 1, falling by 0.02 per second since actual observation to zero at 50 seconds. Continuous visibility refreshes at least once per second. Reports take 1 second per command link and retain their original observation time. A delayed message is not a new sighting. Within a squad current visibility shares after 0.5 seconds. Routine communication is a reliable abstraction; E18 specifically gates remote indirect fire, not every ordinary command exchange.

Contacts show class, position, observed count, source, age, confidence, visible facing where observed, and uncertainty. They do not reveal exact unseen health, fuel, inventory, mines, or future orders. A stale contact older than 10 seconds adds 25 percent caution to its last strength estimate; at zero confidence it no longer supplies a target position. Unknown observed infantry count as armed full-health rifle carriers for threat planning. A visible vehicle's class allows known armour-profile planning, but not knowledge of its hidden loaded shell count.

Direct fire needs a current visible or shared currently observed target and a legal firing line. Indirect fire needs observation age at most 15 seconds, confidence at least 0.6, radio, setup, crew, local ammunition, and authorization. A lost report or dead observer does not become omniscient tracking. A subordinate missing its leader continues its last feasible intent up to 20 seconds, then holds safely and reports. Replacement leadership preserves the chain of authority.

### 16.3 Commander priorities and operation choice

Immediate HQ threat means a visible hostile with HQ-damaging capability inside 500 metres, hostile artillery currently hitting HQ, or HQ taking damage in the last 10 seconds. Empty transports alone are not such a threat. Assign enough suitable defenders to meet observed attack strength at ratio 1.2, preserving at least one deployable squad at HQ whenever possible. If insufficient, commit available defenders and report the actual shortage.

Without that emergency, candidate operation base values are restore a severed primary supply route 100, protect a threatened owned resource 85, seize an unowned resource 80, secure a required crossing 75, prepare a feasible HQ assault 80, seize a Route Hub needed for forward logistics 70, seize Observation 55, probe an unknown approach 40, and assault a located enemy HQ 120 when ready. Subtract 0.1 per expected travel second and 30 times eligible enemy strength divided by eligible friendly strength. Impossible terrain, no supply route, inability to counter required armour, or an incomplete essential bridge plan makes a candidate ineligible rather than merely slightly less attractive. Ties prefer the shorter trip, then oldest unserved objective.

An HQ assault needs a company with readiness at least 0.75, dismounted rifle and marksman loads of 90 rounds each, and either an operating armoured or indirect support element or a feasible engineer demolition plan. Attacking eligible strength must be at least 1.5 times observed local defenders. If no defenders are observed but HQ is located, require a probe or current reconnaissance before assuming the approach is empty. No amount of rifle ammunition substitutes for a missing response to an observed tank.

Prepare Assault creates the ammunition, fuel, transport, and engineering demands before checking final readiness. The Commander keeps an explicit demand list prioritized HQ survival, route restoration, replacements and current weapon ammunition, fuel and medical supply, then new capabilities. It does not select rear recipes or commandeer a shipment. A request names quantities and consequences, such as a tank unable to move without 30 fuel or a heavy crossing waiting for 1,600 Building Materials.

### 16.4 Company operations and supply corridors

With three platoons, assign primary action, complementary support, and reserve or resupply. With two, assign primary and support. With one, proceed only when the local objective is feasible; otherwise hold and request assistance. A staging area must be outside known enemy effective range plus 100 metres unless heavy cover blocks that threat. Wait for at least 75 percent of assigned people and required vehicles to arrive, for at most 60 seconds before reporting delay or proceeding only if minimum capability still exists.

A company establishes a supply corridor connecting HQ, depot, dismount points, crossings, and fallback. It requests a forward depot when an ordinary round trip to HQ exceeds 4 minutes and the position is likely to be held for at least 3 minutes. It requests an aid post when recovery travel exceeds 3 minutes and a medical team exists. It requests bridge construction if a route is cut or a new crossing reduces a planned operation's travel time by at least 25 percent with acceptable risk. Choose the least costly bridge satisfying the heaviest assigned crossing gross load and span; choose B03 for an operation requiring tanks or tank recovery.

The company considers bridge denial only with a parent order, reports stranded forces and evacuation effects, and assigns an engineer squad to the actual demolition site. It does not plant arbitrary mines on its only retreat path. Mines protect a threatened approach or flank and reserve a marked friendly corridor. A project is not useful merely because Building Materials or Explosives exist.

### 16.5 Platoon combined arms and movement

An ordinary attack needs eligible local strength at least 1.3 times the defender estimate. When possible, one infantry squad fixes from cover, another manoeuvres at least 30 degrees around the target, and the third supports or reserves. A technical supports that fire plan from a covered flank. APCs suppress and carry infantry to a dismount opportunity; tanks engage armour and hard positions while infantry protect them from close engineers and observed mine hazards. The platoon does not send empty or unsupported vehicles to capture an objective they cannot capture.

T02 uses a dismount point at least the known threatening weapon range plus 75 metres from that threat, or 300 metres from an unobserved objective approach. T04 may approach within 250 metres against observed rifle-only opposition if armour protects it and a retreat route exists. Against a tank or direct gun, it uses the threat range plus 100 unless friendly support is actively suppressing that threat or terrain blocks the line. Dismounted infantry then use their own cover and sight. An APC does not become invulnerable merely because it carries passengers.

For a journey over 600 metres, request transport when one can arrive and complete the trip faster than walking. Existing mission urgency and route safety still apply. If no transport exists, a safe foot march is allowed with an explicit estimated arrival; command does not wait forever for an absent truck. When the supporting weapon loses ammunition or a bridge becomes unusable, the advancing element pauses in cover and reassesses. If eligible strength falls below 0.8 of the enemy estimate, withdraw unless defending HQ or no safer route exists.

### 16.6 Squads crew and personal action

A squad keeps mission, tactical role, rally, fallback, casualty baseline, issued load, and contacts. Cover choice values bunker 40, heavy cover 30, light 15, minus 0.2 per expected movement second and minus 40 for an exposed crossing of a known enemy firing area without support. Do not leave the parent's objective to chase an unrelated convoy. Nearby recoverable stock within 20 metres may be collected if no exposed enemy fire makes that unsafe.

Average rifle ammunition below 15 rounds triggers urgent resupply. This is a final fallback threshold, not the first time a delivery can be requested. A crew weapon empty of its matching ammunition loses that firing capability immediately. Vehicles request urgent resupply below 25 percent of target ammunition or when fuel no longer supports the planned fallback with reserve. Squads request replacements below six active people and withdraw for reorganization below their type minimum, except immediate HQ defence. Loss of 60 percent of original mission people or more than half Broken causes withdrawal and report.

Individuals first avoid a known imminent blast where a safe reachable position exists, then obey Break or Pinned restrictions, maintain their role, engage the assigned threat, reload, or continue movement. An enemy threatening self or a squadmate within 30 metres can override a distant target. An infantry person does not choose army strategy. A crew member performs their actual station and cannot fix a missing loader by declaring themselves both loader and driver.

An all-conscript squad can move, fire, hold, capture, and withdraw under an acting leader, but does not initiate split-team manoeuvre or remote fire support. Engineers follow project and hazard rules; medics triage; gunners apply penetration and fire safety; drone operators preserve a return path. Vehicle crews are allowed to dismount a disabled hull into safety, retaining identity and carried gear, but do not automatically become a fully equipped infantry squad.

### 16.7 Engineer and vehicle service decisions

Engineering priority is rescue an immediately stranded or blocked HQ route, clear a known mine on a required route, restore a damaged crossing that will otherwise block retreat, prepare a needed forward supply position, construct the cheapest useful defence, then prepare an authorized denial project. A threatened vehicle repair is deferred until covered or recovered; an engineer does not repeatedly walk into observed cannon fire because the tank has low health.

Within that priority, the following project rules guide selection. Expected holding time is the parent's planning horizon, default five minutes for a captured objective and ten for HQ or a primary crossing. It is an intention estimate, not knowledge of future events. Material arrival, unloading, qualified workers, and active work all contribute to completion ETA. A discretionary project must be ready before the planned operation needs it; otherwise choose a shorter alternative or report the delay. Critical restoration of the sole viable route may justify a longer project with an explicit operation pause.

| Project | Required need before requesting it |
| --- | --- |
| Sandbags | Hold at least one minute and no useful light cover within 30 metres |
| Trench | Hold at least three minutes with at least eight infantry and no useful heavy cover within 30 metres |
| Bunker | Defend HQ, a primary crossing, or an objective for at least five minutes, with an actual armed garrison available |
| Vehicle obstacle or mines | An observed mechanized approach or repeated hostile attack, with a marked friendly passage and a retreat alternative |
| Forward cache | Delivery lead time makes carried ammunition insufficient and a safe temporary rendezvous can be completed before depletion |
| Supply depot | Recurring round trip to HQ exceeds four minutes and a position is planned to be held at least three minutes; actual staff can be assigned |
| Aid post | Recovery travel exceeds three minutes and medics, packs, and evacuation access exist |
| Repair point | At least two useful damaged vehicles or guns are within 300 metres and the area can be held at least five minutes |
| Lookout | A required approach lacks observation, with a real trained observer and binoculars available |
| Road or causeway | A recurring supply route has a fixable terrain bottleneck and the projected ten-minute convoy time saving exceeds material-delivery and construction time |
| Bridge | A required route is cut, or the company has a timely operation benefiting from at least 25 percent shorter travel; bridge class must fit the heaviest intended load |
| Denial charge | A company or Commander authorizes the specific bridge or structure after its friendly supply and retreat consequences are assessed |

Vehicle recovery chooses in-place repair when safe and its required supply can arrive, otherwise compatible towing along a route whose combined gross load fits. If neither exists, report Abandoned Until Recoverable and withdraw exposed people. The hull remains physical. A driver dead inside a good truck prompts real replacement crew, not a remote change of the crew count.

The supply planner prioritizes ammunition and fuel for active missions, medical emergencies, required crossing material, and replacements ahead of speculative stockpiling. It forecasts consumption and delivery lead time at mission preparation, then updates at least every 10 seconds during operations. Ammunition reorder point is expected consumption rate times estimated source handling, loading, travel, unloading, and local issue time plus a 60-second buffer. Use the greater of recent 60-second actual consumption and one-half nominal release rate for an assigned active combat weapon; an inactive reserve formation uses actual demand instead of speculative firing. Fuel forecast uses the planned route and fallback with its 25 percent reserve.

Before a long attack, pre-position operating stock and plan a cache or carrier rendezvous rather than waiting for the first empty rifle. Extra mission ammunition beyond personal or vehicle capacity travels as real freight to that location. Source shortages immediately appear in rear demand reports; forecasts do not create stock. One T01 load maximizes critical unfilled demand resolved per expected round-trip second, while reserving enough stock to finish a useful load or project rather than leaving all formations equally unusable. Fleet and transport demand are separate from a vehicle's cargo demand.

### 16.8 Doctrine

Balanced uses the values above. Cautious uses attack ratio 1.6, HQ assault ratio 1.8, rifle resupply below 25 rounds, and an additional 100 metres dismount safety. Aggressive uses attack ratio 1.15, HQ assault ratio 1.3, and rifle resupply below 10. No doctrine overrides terrain, bridge load, fuel, crew qualification, observed mine restrictions, or inability to damage armour. The terminal changes doctrine after a 30-second adaptation delay, with one pending change at most.

## 17 Medical reconnaissance and indirect support

### 17.1 Treatment and evacuation

A medic with E11 starts care within 2 metres of a living incapacitated patient using one E12. Ten cumulative seconds of active care pauses bleed-out and restores 35 health. Interruption preserves work but resumes the remaining bleed-out timer. Another medic with a kit can finish that committed treatment without a second pack. Cancelling the episode loses its pack and progress. Active care means stationary, in reach, not firing, hauling, or operating another task.

A treated person enters Recovery and cannot fight before completing HQ or aid-post recovery care. One person can drag an incapacitated person at 0.5 metres per second up to 10 metres to cover. Two people with one E21 can carry a patient at 1 metre per second without that distance limit. The patient's body is an explicit carrying-capacity exception; the carriers cannot fire or haul additional freight. Vehicle evacuation needs a real passenger seat, 80 kg plus retained personal gear, stopped accessible loading, and a receiving place. Incapacitated patients continue bleeding during travel unless active care is possible.

At HQ or a staffed aid post, a medic spends one additional E12 at recovery start and 30 cumulative active seconds to restore 100 health, morale at least 40, and zero suppression. Interrupted care preserves progress and does not consume another pack. Active injured people below 50 health request this through resupply; any injured person who actually reaches care may be treated. A completed patient waits if reserve capacity is full, without consuming another pack. A patient at 35 health with no medic or pack waits safely in a recovery place, not as a deployable reinforcement.

T01's two passenger places can evacuate two patients; T02 can evacuate up to sixteen while meeting payload and receiving capacity. T04 offers protected extraction for up to eight, but an occupied seat cannot also contain an infantry passenger. Treatment inside a vehicle requires it to be stationary and a medic physically in an accessible passenger compartment. A tank has no passenger compartment; a wounded crew member must be extracted first. A vehicle destroyed during evacuation uses the same occupant injury and incapacitation rules as any other load.

Triage selects the reachable patient with least remaining bleed time for whom treatment can complete, then those needing recovery, then active injured people by lowest health. A protected aid post does not stop bleed-out by itself. There is no passive health regeneration or resurrection. At engagement end, living incapacitated people count as surviving in the result ledger, but reset with other physical state rather than producing free recruits next battle.

### 17.2 Reconnaissance drone

One P06 uses one E15, one E16, and one E17. Launch takes 5 seconds, consumes the battery, and starts a maximum 180-second sortie including launch, return, and 5-second recovery. Speed is 20 metres per second, operating radius 1,200 metres from the stationary operator, sight radius 350, and health 30. It ignores ground traversal while moving but obeys canopy, opaque structures, smoke, and terrain visibility. It has no weapon, freight, crew slot, or capture power.

The operator plans return whenever elapsed time plus direct return time plus 5-second recovery plus 10-second reserve reaches 180. The drone returns earlier if mission ends, operator must relocate, range will be exceeded, or danger forces loss of control. An incapacitated operator triggers automatic return to launch position. Another living P06 with controller must physically recover it before expiry. Failure, zero health, or an inaccessible recovery position loses the drone. A recovered drone can launch again only with a new battery.

Enemy units can engage a visible drone in range using the direct hit formula and target-size factor 0.40. It provides observations, not exact hidden health or ammunition. It does not detect buried mines automatically. A sortie has an explicit purpose such as inspect a crossing, locate a hostile vehicle, or observe a fire mission; an operator does not patrol a random empty area while its company is blind on the actual attack route.

### 17.3 Indirect fire and smoke

Mortar and indirect field-gun fire require complete active crew, setup, radio, valid recent contact, an assigned fire mission, actual ammunition within 3 metres of the weapon, and a safe impact area. Company requests go through the platoon to a support squad. Target priority is HQ during an authorized assault, an active hostile support weapon, an infantry cluster of at least three within one blast radius, then a defended structure blocking the parent operation. Illegal range, inadequate penetration for the intended armoured target, stale information, or friendly risk makes a mission unavailable.

A mission permits at most three shots before reassessment. Crew loss, empty local ammunition, target expiry, or a friendly entering the predicted scatter and damage area stops new releases, not shots already in flight. An observer maintaining sight refreshes the contact without repeating unchanged alerts. Seeing shell impacts can produce a rough suspected firing region of 150 metres radius in the direction of arrival, not an exact unseen artillery position; command may probe that region.

Smoke uses E24 in the mortar, with the same range, flight, and scatter. It creates a 20-metre-radius opaque area for 25 seconds, causing no damage or suppression. Smoke can target an authorized advance, dismount, evacuation, or withdrawal route without an enemy contact. Both armies lose sight through it. Smoke cannot make a bridge intact, an unsafe slope traversable, or a known mine harmless.

## 18 Objectives interface alerts and saved state

### 18.1 Capture and economic feedback

Every objective has a 25-metre capture radius. An active unbroken dismounted person with a functional weapon and at least one matching round supplies one capture work per second, capped at four per army. Crew inside vehicles, passengers, drones, empty structures, unarmed people, and incapacitated people contribute zero. To capture from an APC, the squad must actually dismount.

Control is a scale from minus 60 for the enemy to plus 60 for the player, starting zero. One uncontested army moves toward its end at its capture work rate. Owner is lost at zero and gained at its full end. Four eligible people take 15 seconds to take neutral ground and 30 to reverse full enemy ownership. Both armies present means Contested, no progress, and no resource income. Nobody present causes partial progress to return at 2 per second to the current owner's end, or toward zero if unowned. This is explicitly a two-army rule.

Resource ownership adds its income only while controlled and uncontested. Route Hubs are strategic road and depot locations; the benefit is access and shorter supply travel, not generated fuel. Observation grants the stationary equipped observer benefit already defined. Objective structures themselves are indestructible. Nearby roads, bridges, garrisons, and constructed defences can still be damaged normally.

### 18.2 Inspection requirements

| Entity | Required inspection |
| --- | --- |
| Material and equipment | Actual location, owner, available and reserved count, unit and total mass, pending production and demands |
| Facility and worker | Requested and actual labour, qualifications, current action, route, local inputs, progress, output, and all blockers |
| Person and training | Exclusive assignment, health, morale, suppression, qualifications, equipment, course and progress, intended deployment or crew duty |
| Manifest | Mission mode, returning versus committed people, all quantity stages, actual payload and seats, missing crew, fuel reserve, route, departure and arrival |
| Vehicle | Crew by station, passengers by squad, hull and mobility, loaded and stowed ammunition, fuel, actual gross load, armour faces, mission, route, supply and repair demand |
| Formation | Parent and subordinates, active versus boarded versus en-route people, readiness, actual capabilities, last decision and reason, fallback, supply destination |
| Project and structure | Required, delivered, consumed and missing M11 or M06; qualified workers; progress; safety block; health; occupants; function and supplies |
| Bridge | Span, class, current health, current load limit, crossing queue, actual convoy load, closure or repair, known armed charges |
| Device and hazard | Known type and location, arming state, controller, safety or trigger status, permitted clearance action; hidden enemy devices are omitted |
| Terrain and map | One-metre scale, dimensions, movement-class passability, slope, sight and cover effects, roads, current known bridge access, seed and generation family |
| Objective and HQ | Ownership and capture, income, actual unloaded stock, reserve and recovery capacity, incoming supplies, staff work, and army demand |

The interface separates producing from delivering and owning from issuing. It shows why a tank cannot attack: no loader, no shell, no fuel, no traversable bridge, no target information, or tactical danger. A single vague Inactive label is insufficient. Changes in capability have a dated cause trace leading to the relevant supply, crew, health, or route event. Friendly-controlled management information is exact. Enemy inspection shows only observed type, position, visible equipment, and observed condition, with its age; it does not expose unseen fuel, ammunition, qualifications, or stock. Retaining legal ownership of a captured garrison does not provide hidden live information about its enemy occupants.

### 18.3 Alerts controls and map use

Critical alerts cover HQ damage, lost sole viable supply access, zero surviving strategic vehicles, no operational response to observed hostile armour, and mass casualty or fuel collapse. Actionable alerts cover a workshop blocked 15 seconds, manifest missing requirements 30 seconds, unloading blocked 20 seconds, military demand unfilled 30 seconds, a damaged bridge about to lose heavy access, a known mine on a supply route, and a vehicle stranded without recovery. Unchanged alerts combine and link to inspection.

The player controls rear acquisition, facilities, staffing, recipes, training, shipment modes and composition, dispatch, card selection, doctrine, camera, overlays, speed, and pause. The player does not directly place battlefield mines or bridges, choose tank targets, or manually move a squad. Watching a command decision and its explanation should make those actions understandable.

The strategic map displays metre or kilometre distances, a scale bar, HQ and objective anchors, formation and convoy markers, known crossings, and optional route, passability, supply, and threat layers. It must support both 6 km overview and individual people near a truck without treating the one-metre grid as always-visible decoration. A travel-time overlay uses the selected movement class and known map state. A generated map's acceptance report is available in test mode; normal play shows its family and seed rather than internal generation attempts.

### 18.4 Presentation accessibility and persistence

Use a readable overhead view of a fictional industrial battlefield. Terrain silhouettes and transitions distinguish water, mud, dense forest, slope, town, and road at strategic scale. Vehicle type, carried squad, and engineering activity remain distinguishable. Sound supports work, loading, departure, incoming fire, immobilization, bridge failure, objective change, and HQ danger; necessary cues always have a visual equivalent. Labels and shapes accompany colour. Text scales to 150 percent, and pause is always reachable.

Saving preserves actual terrain and generation version, seed, every person's identity and assignment, crew and boarding, cargo and fuel, all loaded ammunition, batches, courses, reservations, routes, contacts and their original observation times, devices and detection knowledge, projects, changed bridge access, objectives, pending offers and fixed rewards, and campaign state. Load begins paused with exactly that state. It cannot reroll already generated content or resolved outcomes. Manual save and engagement-start autosave are available.

## 19 Campaign cards and opposing economy

### 19.1 Campaign and reward rules

A campaign begins at position 3. A win at positions 1 to 4 advances one position; winning at 5 ends in campaign victory. Losing at positions 2 to 5 retreats one; losing at 1 ends in defeat. Both HQs destroyed in the same instant is Draw, no position movement, and a repeat of that position with a new engagement seed. Surrender is a confirmed loss. There are no other victory conditions in this edition.

Each fresh engagement resets all physical people, vehicles, buildings, materials, requisition, training, current recipe access, and battlefield state to its starting package on a newly generated battlefield. Permanent cards, XP, earned unopened boxes, run position and history, selected doctrine, and settings persist. Nothing physically crosses between battles in this roguelike default. Saving within an engagement is different from starting the next one.

Normal finish gives 100 XP, victory another 100, and each of the first four distinct objectives captured gives 20, for at most 80 objective XP. Recapture gives none. Defeat retains finish and earned objective XP. Draw gives exactly 100. Surrender gives exactly 25 total. Profile level is 1 plus whole XP divided by 500, with no stat bonuses. Each crossed 250-XP boundary gives one free earned box.

A box offers two permanently locked cards, or the one remaining. Choose one permanently; the other stays locked. Candidate order is fixed when earned and cannot reroll on load. If an already owned card occupies a delayed box choice, use the next still-locked card in its fixed order. With the collection complete, record a commendation and no currency, XP, or power. Boxes cannot be purchased or traded.

### 19.2 Bundled capability cards

Essential recipes are always active as listed in section 5. A card grants all its listed recipes for that engagement. The permanent collection only determines eligible offers; it does not grant permanent recipe operation. Recipe access does not add goods, a vehicle, a building, or trained people. Duplicate recipe access from two different cards creates no extra output.

| Card | Recipes granted together | Capability |
| --- | --- | --- |
| C03 Helmets | R03 | Protection |
| C04 Body Armour | R04 | Protection |
| C05 Support Machine Guns | R05 | Heavy-weapons crew and rifle rounds |
| C06 Mortar Battery | R06, R07, R18 | Crew, bombs, and radio supplied through one offer |
| C11 Medical Support | R11, R12, R21 | Medic, kit, packs, and evacuation |
| C13 Field Artillery | R13, R14, R18 | Artillery crew, gun, shells, and radio |
| C15 Aerial Reconnaissance | R15, R16, R17, R20 | Operator, drone, controller, batteries, and observation |
| C19 Marksmen | R19, R20 | Marksman and observation |
| C24 Smoke Support | R24 | Eligible only after R06 is active |
| C29 Technical Vehicles | R29 | P08 driver and P04 or P08 gunner; E02 ammunition |
| C30 Armoured Carriers | R30, R33 | Three P08 crew, cannon ammunition, and eight passenger places |
| C31 Tanks | R31, R32 | Four P08 crew and tank ammunition |

This edition has twelve cards. The initial permanent collection is C03, C05, C06, C11, C29, C30, and C31; all five vehicle roles are therefore available in the first campaign, although their combat manufacture depends on that engagement's choices. C04, C13, C15, C19, and C24 are persistent unlocks. Essential transports, engineers, materials, explosives, and crossing blueprints require no card.

Each engagement starts paused with one free three-card offer at the terminal. Later offers arrive physically as purchased documents. Sample distinct permanently owned cards not already selected this engagement that grant at least one new recipe; C24 additionally requires R06 already active. With fewer than three eligible cards, show all. With none, disable purchase. Unselected cards remain eligible for later offers. Selecting C30 includes its cannon-shell recipe and C31 includes its tank-shell recipe, avoiding an unusable tank build caused solely by missing ammunition-card luck.

### 19.3 Enemy physical supply

The opposing rear industry is off-map. Enemy acquisition purchases declared finished packages using its own requisition. Every package travels to its gate, then physically reaches and unloads at enemy HQ. Opposing command has the same movement, crew, armour, fuel, ammunition, information, engineering, and hierarchy constraints. It cannot issue a gun remotely or see hidden mines. Its economic prices are explicit balance values for an off-map industry, not a simulated copy of the player's workshops.

| Package | Price | Off-map preparation seconds | Delivery and contents |
| --- | --- | --- | --- |
| A Conscripts | 300 | 60 | Leased T02: eight P00, eight E01, 480 E02 |
| B Trained infantry | 400 | 90 | Leased T02: eight P01, eight E01, 720 E02 |
| C Machine gun squad | 550 | 120 | Leased T02: two P04, six P01, one E05, six E01, 720 E02 |
| D Engineers | 600 | 120 | Leased T02: two P02, six P01, two E08, eight E01, 480 E02, 500 M11, 20 M06 |
| E Medical | 550 | 120 | Leased T02: two P03, six P01, two E11, twelve E12, two E21, eight E01, 480 E02 |
| F General supply | 1,200 | 180 | Leased T01: 1,000 M11, 100 M06, 100 M08, 6,000 E02, twenty E12 |
| G Technical | 800 | 180 | T03 Fleet Transfer: one P08 driver, one P04 gunner, 900 E02, full fuel |
| H APC | 2,000 | 300 | T04 Fleet Transfer: three P08 crew, eight P01 passengers with rifle and 60 rounds each, 180 E26, full fuel |
| I Tank | 4,000 | 540 | T05 Fleet Transfer: four P08 crew, thirty E25, 900 E02, full fuel |
| J Mortar | 650 | 150 | Leased T02: three P04, five P01, E06, twelve E07, E18, five E01, 600 E02 |
| K Artillery | 1,100 | 240 | Leased T02: four P05, four P01, E13, twenty E14, E18, four E01, 480 E02 |
| L Reconnaissance | 800 | 180 | Leased T02: two P06, six P01, E15, E16, three E17, E20, eight E01, 480 E02 |
| M Marksmen | 600 | 120 | Leased T02: two P07, six P01, two E19, two E20, six E01, 720 E02 |

Leased carriers have separately recorded service drivers, arrive fuelled for delivery and return, and leave after unloading; they cannot be retained as free military vehicles. During the mission they are enemy-controlled and attackable. H, I, and G are actual transferred military hulls and actual crew who remain, not delivery carriers that secretly disappear. Sources are off-map external industry, not a neutral battlefield faction. Cargo, passenger, and crew capacity are checked for every package.

Enemy starts with 2,500 requisition, baseline 6 per second plus its resource income, and the same field package as the player. At most one purchase starts every 60 seconds, up to three packages in preparation or transit. It reserves 600 requisition for essential manpower or resupply before a discretionary armoured purchase. Priority is HQ emergency reinforcements, missing ammunition or fuel through F, engineer replacement when routes are cut, medical need, then new specialist or vehicle capability for the highest-value mission. It purchases troop packages only when reserves cannot fill current losses or planned forces. An unaffordable tank does not block all ordinary reinforcements.

Armour purchasing prefers an APC if it has none and needs protected infantry transport; a tank if it has no operational tank and observes hostile armour or defended hard positions; otherwise the highest unmet vehicle demand. It does not buy endless empty carriers. Existing live army and incoming reserved people or hulls count against caps before purchase. When neither immediate replacement nor support demand exists, it can save toward that planned capability. Basic package choice is A or B according to difficulty and available budget; its trained mixture is visible in post-battle reporting.

### 19.4 Difficulty positions

| Position | Enemy income factor | Infantry preference | Doctrine |
| --- | --- | --- | --- |
| 1 | 0.80 | A before B | Cautious |
| 2 | 0.90 | Alternate A and B when affordable | Balanced |
| 3 | 1.00 | B when affordable, otherwise A | Balanced |
| 4 | 1.10 | B; technical and APC capability receive higher new-capability priority | Balanced |
| 5 | 1.20 | B; tank and artillery receive higher new-capability priority | Aggressive |

Income factors apply only to the enemy's declared baseline and objective income. There are no hidden health, hit, penetration, fuel-efficiency, or visibility bonuses. Map generation fairness bounds apply at every campaign position. Difficulty does not silently remove the player's bridge access or move an enemy HQ closer to the first objective.

## 20 Starting scenario and reference calculations

### 20.1 Rear starting state

The full v0.2 engagement begins paused with 2,500 requisition and sixty rear people: forty-two P00, twelve P01, and six P08. All are healthy; specialists retain basic training. Three P08 crew the strategic fleet of two T01 and one T02; the other three are available. Two P01 are instructors. Vehicle manufacture never adds these people again.

Initial depot quantities are 600 M01, 300 M02, 200 M03, 600 M04, 100 M05, 40 M06, 40 M07, 200 M08, 40 M09, 20 M10, and 500 M11. Each strategic vehicle has forty fuel already inside, additional to loose depot M08. There is no starting rear manufactured weapon stock. Starting stock is initialized scenario supply, not an unobserved runtime transfer.

All thirteen rear facility types exist initially, with two F11 parks supplying eight idle spaces. Reference centres in the 240 by 180 metre rear are Terminal (20,20), Receiving (45,25), Depot (80,20), Workshop (125,25), Munitions (125,55), Materials Plant (125,95), Vehicle Works (180,40), Training (55,110), Support (90,110), Dispatch (210,100), Personnel (20,90), Construction Office (30,140), and Parks (180,140) and (80,145). Non-overlapping eight-metre vehicle lanes connect receiving, depot access, Vehicle Works, parks, and dispatch to entry and exit. Exact lanes must pass footprint validation; they do not run through building centres.

Staffing targets are Receiving 4, Workshop 4, Munitions 4, Support 0, Materials Plant 6, Vehicle Works 4, Training 2, Dispatch 4, General Hauling 16, Construction 2, and Strategic Crew 3. This allocates forty-nine people and leaves eleven available. R01 targets 32 unreserved rifles, R02 targets 6,000 unreserved rounds, R26 targets 1,000 unreserved M11, Vehicle Works has no recipe selected, and no students begin enrolled. The player can change all these allocations.

### 20.2 Battlefield starting state and ledger

Each army begins with three eight-person Rifle squads, one eight-person Engineer squad, and one eight-person Medical squad. Those forty people comprise thirty-six P01, two P02, and two P03. Rifle squads have 60 E02 per person; engineer and medical squads have 30. Every one of those forty has an E01, with ten of their existing rounds loaded. Engineers have two E08; the medical squad has two E11, twelve E12, and two E21. There are 1,920 rifle rounds across the forty people, not 1,920 plus their loaded rounds.

The field fleet is two T02 with one P08 driver each, one T01 with one P08 driver, and one T03 with a P08 driver and P04 gunner. This is five actual crew people, including four P08 and one P04. Tanks and APCs are absent initially and arrive through production and acquisition decisions. The technical carries 900 E02 total, sixty loaded. Field transport tanks are full: forty in each T01 or T02 and thirty in the technical, totalling 150 fuel inside vehicles.

Two additional P03 serve HQ recovery with one E11 and five E12 each. Four initial logistics staff and one Commander are the fixed HQ five. Thus each army starts with forty infantry, five vehicle crew, two flexible medical service people, and five fixed HQ people: fifty-two on the battlefield. The player's sixty rear people bring the full starting player population ledger to 112, before external service drivers. No crew or passenger is counted inside both totals.

HQ loose stock is sixteen E01, 6,000 E02, two E08, two E11, two E21, forty E12, 600 M11, forty M06, and 300 M08. This stock is additional to explicitly issued gear and filled vehicles. Both HQs start with one trench segment and two sandbag segments protecting the forward approach, with actual occupants only if assigned. Initial people and vehicles stand in valid staging locations outside the HQ footprint, not inside an impassable building.

One company with two platoons organizes the five squads. Three Rifle squads fit one platoon; Engineer and Medical fit the other. The two troop carriers are company transport; the technical and resource carrier attach to the appropriate platoon or service mission. One Rifle squad stays on HQ defence initially. The first lift can carry two Rifle squads, Engineer, and Medical, thirty-two people, while the remaining eight defend. Command decides the actual loads and routes from the generated map.

### 20.3 Delivery example

Eight new people, eight rifles, and 480 rounds fit a T02 Strategic Delivery. Passenger bodies are 640 kg, rifles 32, ammunition 9.6, totalling 681.6 kg payload and eight of sixteen passenger places. The driver is a separate crew person and not an infantry reinforcement. With no other load and forty fuel aboard, gross bridge load is 3,200 plus driver body 80 plus driver personal gear if any plus fuel 40 plus payload 681.6, or 4,001.6 kg before any driver personal gear. B02 can carry this; B01 cannot.

Eight R01 batches use sixteen Metal and eight Components with 320 operator-work seconds. Five R02 batches create 500 rounds from five Metal and five Gunpowder with 200 work seconds. Send 480 and retain twenty at their actual rear location. Four present operators need 80 and 50 production seconds respectively, excluding input movement, staging, loading, travel, receiving, and issue. Those are work-only minima, not delivery promises.

### 20.4 Bridge and ammunition example

A 30-metre B03 consumes 2,400 M11 and 1,200 work seconds. Twenty-four R26 batches create that material from 720 M01 and 1,680 M04, with 2,400 plant operator-work seconds. Six operators need 400 active production seconds; four engineers then need 300 active construction seconds. The starting engineer squad has two qualified builders, so it alone needs 600 active construction seconds; training or combining another team halves that part of the delay. Freight is 2,400 kg and fits one T01, but those production and construction stages still need actual source delivery, loading, travel, unloading, and site handling. Recipe inputs cost 3,120 requisition before transport fees and capital.

R27 consumes ten Gunpowder and two Metal for one Explosives unit, input cost 14 requisition before labour and transport. Ten tank shells use one hundred Metal and twenty Explosives, input cost 480. One hundred autocannon rounds use thirty Metal and twenty Explosives, input cost 340. A full thirty-shell tank target therefore needs sixty Explosives and six hundred Gunpowder upstream, in addition to shell casings and the small Metal input used by the Explosives chain. These costs show the same manufactured explosive resource feeding both engineering and guns. Ammunition has no implied real-world formulation.

The same B03 has 7,000 health. Full-health demolition therefore reserves fourteen M06, placement work 38 seconds, then clearance and arming. A destroyed crossing needs the full 2,400 M11 and work to rebuild, creating a real strategic material and transport commitment rather than a free repair click.

## 21 Playable milestones and issue scopes

### 21.1 Delivery milestones

The v0.2 target includes all requested vehicles, engineering, and procedural maps. The following stages sequence verification rather than defer those features to an unspecified later design. An intermediate infantry test is useful but does not satisfy the full v0.2 acceptance target. Every battlefield milestone uses the full 4 km by 6 km scale; a 600-metre test map is not a substitute for the operational pacing test.

| Milestone | Playable result | Exit evidence |
| --- | --- | --- |
| M0 Rear economy and people | Acquire, haul, manufacture, train, and assign actual people | Exact inventories; no doubled reservations, manufactured crew, or hidden local inputs |
| M1 Full procedural world | Generate all four families at required dimensions with valid terrain and routes | Accepted-map report for each seed and movement class; deliberate invalid candidates reject; full-sized fallback is validated |
| M2 Operational transport | T01 and T02 connect rear, HQ, and a real front | Payload, seats, crew, gross load, fuel, boarding, unloading, and local issue survive a complete cycle |
| M3 Autonomous infantry engagement | Command contests objectives and returns requisition | Downward intent, upward reports, coordinated squads, resupply, and an HQ result on the large map |
| M4 Engineering control of routes | Build defences, depot, roads, bridges, mines, and charges | A convoy is blocked, cleared or rerouted, a crossing is denied, and engineers restore access using actual materials |
| M5 Full vehicle combat | Technical, APC, and tank join the economy and command chain | Real crew stations; armour interaction; one-squad APC load; combined arms; damage, recovery, and fuel constraints |
| M6 Supporting capabilities | Medical, mortar, field gun, marksman, and drone systems integrate | Complete people-equipment-supply pairs; safe fire; actual evacuation; useful observation and counter-support |
| M7 Full run and persistence | Campaign, bundled cards, rewards, save and load, and whole-loop playtest | All prior systems remain coherent across generation, battle, result, and next engagement |

### 21.2 Proposed issue backlog

These are scoped issue drafts within the design document. They describe behaviour and acceptance, leaving implementation decisions to the engineer. Publishing them to GitHub requires selecting the project repository in the continuing project-management work.

| Issue | Scope and dependency | Required result |
| --- | --- | --- |
| G01 Physical identity and ownership | M0 foundation | People, goods, controllers, reservations, and positions reconcile; A01 to A03 |
| G02 Procurement and receiving | M0 after G01 | Purchased materials and people travel, berth, unload, and respect capacity; A04 and A58 |
| G03 Rear staffing and hauling | M0 after G01 | Targets select eligible people; work is physical and constraints visible; A05 and A06 |
| G04 Recipes and essential material chains | M0 after G02 and G03 | All listed batches use local inputs, exact yields and work; BM and Explosives are manufactured; A07 to A09 |
| G05 Rear construction and placement | M0 after G03 and G04 | M11 sites, footprints, access, cancellation, and output bays function; A10 and A59 |
| G06 Basic and specialist courses | M0 after G03 | Instructor capacity, progress, P02 and P08 access, commitment, and shortage recovery; A11 |
| G07 Vehicle assembly and crew stations | M2 after G04 and G06 | Empty hulls have no free crew, fuel, or ammunition; qualified stations work; A12 and A13 |
| G08 Terrain movement and sight contract | M1 foundation | All terrain, slopes, footprints, cover, opacity, and ford limits have the defined effects; A14 and A15 |
| G09 Broad landforms and natural terrain | M1 after G08 | Four coherent families with water, ridges, towns, fields, and transitions; A16 |
| G10 Scenario anchors and validation | M1 after G09 | HQ count, dimensions, route independence, objective fairness, and clearance pass; A17 and A18 |
| G11 Generation repeatability and fallback | M1 after G10 | Seed, attempt cap, rejection, actual saved world, and validated fallback; A19 |
| G12 Dispatch manifests and modes | M2 after G03 and G07 | Strategic Delivery and Fleet Transfer have distinct commitments and correct quantity stages; A20, A21, and A60 |
| G13 Routes fuel and gross load | M2 after G08 and G12 | Actual distance, consumption, reserve, bridge load, and invalid paths govern movement; A22 and A23 |
| G14 HQ unloading and actual issue | M2 after G13 | Only unloaded, locally transferred stock changes people and vehicle holdings; A24 |
| G15 Military organization | M3 after G06 and G14 | Type minima, real appointments, attachment, crew, boarding, and cap checks; A25 |
| G16 Combat wounds and morale | M3 after G08 and G15 | Direct fire, ammunition, suppression, cover, wounds, and functional dropped goods; A26 and A27 |
| G17 Hierarchical orders and information | M3 after G15 and G16 | Observation ages correctly; meaningful escalation and coordinated action; A28 and A29 |
| G18 Objectives and income | M3 after G17 | Actual dismounted eligible presence changes control and money; A30 |
| G19 Field structures and roads | M4 after G04 and G17 | Engineer sites consume M11, require access, and create occupied rather than magical capability; A31 and A32 |
| G20 Bridge construction and traversal | M4 after G13 and G19 | Span, bank access, material delivery, work, health, class, and queues; A33 and A34 |
| G21 Bridge repair upgrade and demolition | M4 after G20 | Damage changes access; repair and denial respect occupied spans and retreat consequences; A35 and A36 |
| G22 Mines IEDs and clearance | M4 after G16 and G19 | M06 placement, arm time, real triggers, detection, safe route response, and inert clearance; A37 and A38 |
| G23 Vehicle armour and weapons | M5 after G07 and G16 | Surface penetration, mounted ammunition, station control, firing cadence, and target eligibility; A39 and A40 |
| G24 Vehicle destruction and recovery | M5 after G20 and G23 | Occupants and salvage resolve once; immobilization, repair, towing, and bridge load remain physical; A41 and A42 |
| G25 Combined-arms transport AI | M5 after G17 and G23 | Troop lifts, APC dismount, technical support, tank counters, and retreat; A43 and A44 |
| G26 Forward supply and service teams | M4 to M6 after G14 and G19 | Real fuel, BM, Explosives, shells, replacements, and staff reach real destinations; A45 and A57 |
| G27 Medical evacuation and care | M6 after G16 and G26 | Patient, seat, bleed timer, pack, medic, and recovery place remain consistent; A46 |
| G28 Indirect fire and reconnaissance | M6 after G17 and G26 | Crew, radio, local ammunition, observation, smoke, safety, and drone return; A47 and A48 |
| G29 Enemy package economy | M3 to M6 after relevant delivery and combat issues | Declared budgets and preparation produce real loads; vehicles and crew remain; A49 |
| G30 UI explanations and large-map controls | Alongside each system | Required inspection, route overlays, alerts, scale, and accessibility; A50 |
| G31 Campaign and bundled access | M7 after G04 and G29 | Full capability cards, essential access, progression, result, and reset; A51 and A52 |
| G32 Complete save and load | M7 after live systems exist | World, seed, crew, devices, fuel, cargo, progress, reports, and choices resume exactly; A53 |
| G33 Integrated pacing and fairness trial | M7 after all above | Repeat varied seeds and observe complete supply, engineering, transport, and armoured battles; A54 to A56 |

Each issue records the referenced design version, included entities, exact state transitions, dependency, required UI explanation, and acceptance scenarios. A changed number is a design revision, not an undocumented engineering substitute. There are no delivery dates or staffing estimates in this backlog.

## 22 Acceptance review migration and next decisions

### 22.1 Acceptance scenarios

These scenarios are requirements for implementation and playtest. Document calculations and catalogue checks can be performed now; the scenarios are not claimed to have run in a game that does not yet exist in this workspace.

| ID | Setup and action | Required result |
| --- | --- | --- |
| A01 | Allocate one person to labour, then enroll them in training | The same person changes duty after safe handoff and contributes to only one role |
| A02 | Two manifests request the same ten rifles | Combined reservations never exceed ten and the unfilled demand remains visible |
| A03 | Put loose and loaded ammunition on one person, then incapacitate and recover their weapon | Rounds are counted once and remain in their physical weapon or loose pile; an intact weapon remains functional |
| A04 | Buy raw goods with no unloading staff, then buy eight people | Goods remain unavailable onboard; people disembark under their own movement into reserved capacity and can restore labour |
| A05 | Staff a workshop but leave inputs in a depot with no haulers | Production waits for actual local material and explains the hauling shortage |
| A06 | Reassign a carrying worker or P08 yard driver | They finish a safe carry or park before changing assignment; no ghost worker or driver remains |
| A07 | Run R27 once from local inputs | Ten M03 and two M01 become exactly one M06 after forty operator-work seconds; M06 is not purchased |
| A08 | Run R26 once | Thirty M01 and seventy M04 become exactly one hundred M11 after one hundred work seconds |
| A09 | Run shell batches and select the tank card | R32 consumes actual M06 and Metal; C31 grants both hull and shell recipes without granting a hull, crew, or rounds |
| A10 | Attempt an obstructing rear placement, then cancel a begun valid site | Invalid access is rejected; cancellation returns only the defined half M11 and retains all unconsumed stored goods |
| A11 | Put twelve students under one instructor, then add a second | Six progress and six pause; all can progress with two; P02 and P08 courses never depend on a random card |
| A12 | Complete a vehicle recipe with zero available P08 | A real empty unfuelled uncrewed hull occupies output and cannot drive out or fire |
| A13 | Assign one P08 to a tank, then a full crew | Driver-only transfer can move legally; main fire requires gunner plus loader; ordinary combat deployment waits for all four |
| A14 | Route wheel and track units through dense forest, swamp, and steep slopes, then destroy a supporting causeway | Each obeys access and speed; a stranded wheel vehicle needs restored surface or legal recovery, not a free move from health repair |
| A15 | Place observers behind mixed forest, ridge, crops, and smoke | Sight range, obstruction budget, height, and opaque lines match the defined rules; map overview gives no enemy-unit sight |
| A16 | Generate each map family and inspect at strategic and local zoom | Water connects naturally; forests and farms form coherent patches; towns have accessible entrances; no one-metre terrain confetti |
| A17 | Validate dimensions, HQs, access and fairness for a seed | Exactly 24 million one-metre tiles, two HQs, separate class-valid routes, and all stated comparison bounds pass |
| A18 | Add a tree, narrow corner, or overloaded bridge to an otherwise valid mandatory route | Final candidate rejects or repairs the obstruction before acceptance; decorative placement cannot invalidate its access report |
| A19 | Force one hundred invalid candidates and then save the fallback | A validated full-sized fallback is used with recorded reason; load preserves that actual world rather than rerolling |
| A20 | Send eight people, eight rifles, and 480 rounds in T02 | Eight passenger seats and 681.6 kg payload are used; driver remains a distinct person and mode defines whether they return |
| A21 | Load a field gun directly at Vehicle Works and cancel before dispatch | It counts onboard rather than staged, preparation can complete, and cancellation requires actual unloading |
| A22 | Plan a route whose fuel is insufficient for the destination and next resupply with reserve | The route is rejected or gets a real fuel stop; a reservation does not instantly fill the tank |
| A23 | Send a fully loaded APC or tank toward B02, then B03 | B02 rejects it; B03 accepts within its actual gross limit and physical clearance |
| A24 | Unload fresh tank shells at HQ while a tank is 2 km away | Its rack does not refill until a delivery and local transfer occur |
| A25 | Offer three infantry people, four infantry people, and five Artillery people | No ordinary squad at three; a minimum rifle squad can form at four; Artillery still requires six including its four crew |
| A26 | Fire a weapon's last round while matching stock exists only elsewhere | Further fire stops and supply demand identifies the actual missing local stock |
| A27 | Incapacitate a person and interrupt treatment | Bleed-out, further injury, dropped gear, preserved care work, and committed pack behave consistently |
| A28 | Observe a stationary enemy for thirty seconds, then lose sight | Observation stays fresh while seen; after loss confidence and age decay from the actual observation time, including message delay |
| A29 | Give two squads a supported flank, then remove the fixing squad's ammunition | Responsibilities differ; loss of support pauses or redirects the manoeuvre and escalates inability |
| A30 | Park an APC on an objective with its squad inside, then dismount | No capture until actual eligible people exit; four take neutral control in fifteen uncontested seconds |
| A31 | Order a bunker with engineers but M11 still at HQ | No work until Building Materials are physically staged; no empty bunker gun or free occupants appear |
| A32 | Build a depot, aid post, repair point, and lookout without staff or supplies | Structures exist but their services remain blocked until actual qualified people, tools, and consumables arrive |
| A33 | Build a 30-metre B03 from one accessible bank | It consumes 2,400 M11 and 1,200 engineer-work seconds; four engineers complete work in three hundred active seconds after delivery |
| A34 | Queue vehicles and eight equipped people at a footbridge | Vehicles cannot cross; infantry crossing respects eight-person and actual 1,000 kg limits |
| A35 | Damage B03 to half health while a tank towing another tank is waiting | Its load limit halves to 40,000 kg and rejects a fully loaded tow combination above that mass; repairs restore access rather than granting a free full bridge |
| A36 | Plant fourteen M06 on a full-health 30-metre B03 with friendlies on it | Placement and arming are physical; detonation waits for friendly clearance; authorized detonation can destroy the 7,000-health span |
| A37 | Place D02 on a road and send an uninformed vehicle over it after arming | It triggers by vehicle presence, uses bottom penetration, and immobilizes a surviving hull; infantry alone do not trigger it |
| A38 | Reveal a mine, sweep it, or shoot it | Only observed knowledge changes routes; clearance needs actual work or sufficient damage; no recovered M06 or sympathetic chain is created |
| A39 | Fire rifles and an autocannon at a tank's front, then autocannon at its rear | Ineligible penetration causes zero hull damage; rear penetration can damage it without making rifles an armour counter |
| A40 | Order a tank to fire with no loader or no E25 but ample coax rounds | Main fire remains unavailable; compatible coax can function only with its actual gunner and E02 |
| A41 | Destroy a vehicle containing healthy, injured, and incapacitated people | Occupants receive the defined once-only consequence, salvage rounds down, and no person or item is duplicated |
| A42 | Tow a loaded tank with another tank over B02 and B03 | Combined load blocks B02; a valid combination below 80 tonnes can use B03, with reduced speed, increased fuel, and no tractor firing |
| A43 | Assign a company a known tank threat but only rifle squads | It does not infer an eligible attack from person count; it avoids, withdraws, or requests an actual counter |
| A44 | Move a squad inside T04 toward rifle-only opposition, then toward a known tank | APC transport and dismount follow protection and threat rules; exactly eight passengers plus three crew remain distinct |
| A45 | Cut the route to a supplied forward depot with replacements en route | Local stock remains; unsafe new delivery stops; replacement people remain in their actual transfer location until a real rendezvous |
| A46 | Evacuate an untreated patient by T02 to a full recovery area | The bleed timer continues unless active care is possible; a seat is used; safe treatment waits for a real place and medic |
| A47 | Prepare indirect fire with a friendly crossing in its scatter or collapse hazard | Release is withheld and no new round is consumed; a shot already released still resolves physically |
| A48 | Launch a drone at full operating radius | Return prediction includes actual distance, launch and recovery; a dead operator causes return and possible loss, never infinite flight |
| A49 | Let enemy packages queue outside a blocked HQ and destroy a transfer vehicle | No remote reserve or rack gains occur; transferred crews and hull losses count; an unaffordable tank does not block all infantry purchases |
| A50 | Inspect every blocked vehicle, structure and shipment at overview and close zoom | Cause, consequence, actual quantities, scale, and a relevant next inspection remain readable without relying only on colour or sound |
| A51 | Begin a run with no selected advanced cards | Building Materials, Explosives, engineers, vehicle crew, and basic transports remain available; combat vehicles require their bundled choices |
| A52 | Resolve victory at position five and a simultaneous HQ draw | Victory ends the run; draw moves neither way; rewards occur once; next engagement reset follows its distinct rule |
| A53 | Save during bridge upgrade, mine arming, a loaded APC journey, partial shell production, and an aged contact | Load preserves actual world and people, quantities, fuel, progress, knowledge, and fixed choices while paused |
| A54 | Run a River Valley engagement with a destroyed crossing and armoured offensive | At least one real engineering or routing response restores capability; all construction supplies can be traced to sources and transport |
| A55 | Run Lake District and Highland Passes seeds with identical initial forces | Paths differ naturally; both satisfy fairness and heavy access, and neither silently shrinks range, world size, or fuel requirements |
| A56 | Play a complete campaign engagement with two supply cycles, one forward depot, one vehicle loss, medical recovery, and one HQ result | Every major decision can be traced through production, people, physical movement, capability, AI action, and economic feedback |
| A57 | Assign an active front operation whose source-to-unit delivery takes five minutes | Forecast consumption and the sixty-second buffer request supply before the urgent fifteen-round threshold; missing source stock is reported and nothing is remotely issued |
| A58 | Fill the freight queue, remove all rear workers, and order eight people | The separate personnel pull-off and their own disembarking restore counted people without needing an unloading worker first |
| A59 | Attempt to dismantle protected initial Receiving, Construction Office, and Materials Plant instances | Each rejects with its recovery-path reason; additional unprotected copies still follow normal dismantling |
| A60 | Put a field gun and nine passengers in T02, then reduce to eight | The folded-bench eight-passenger limit rejects the first manifest even if its mass fits; the corrected load can prepare and travel normally |

### 22.2 What the logical and numerical checks cover

Before delivering this edition, verify all active references, unique IDs, recipe dependency reachability, bundled access, facility input and output capacities, vehicle payloads and crew limits, full-load bridge classes, representative tow mass, map budget totals, and worked examples. Review current states for creation, consumption, assignment, interruption, cancellation, injury, destruction, and save persistence. These checks can identify contradictions and impossible chains but cannot establish that the game is fun or that the AI wins sensibly without implementation and observation.

Playtests should record time to first contact, first useful shipment, first APC and tank, idle or blocked production by cause, material and shell demand, vehicle travel versus combat time, dismounted walking time, crossing queue time, bridge restoration delay, stranded-vehicle time, medical recovery, and objective ownership. Compare the four families and campaign positions. Repeatedly empty battlefields or twenty-minute foot marches indicate failed operational pacing, even if the generator's geometric tests pass.

### 22.3 Migration from version 0.1.1

| Earlier definition | Current replacement |
| --- | --- |
| Small authored 600 by 300 battlefield | Required procedural 4,000 by 6,000 world with validated full-sized fallback |
| T01 with 1,000 kg and twelve passengers plus an included manufactured driver | T01 resource transport with 5,000 kg, two passenger places, and an actual separately trained P08; T02 carries bulk infantry |
| E09 construction bundle and R09 | M11 Building Materials produced by R26 |
| E10 demolition charge and R10 | M06 field placement actions D01 to D04; no manufactured charge item |
| E22 repair pack and R22 | Direct M11 field repair costs with E08 and qualified engineers |
| E23 cache crate and R23 | Cache and depot blueprints consume M11 only |
| Purchased M06 explosive compound | Manufactured Explosives through R27 using Gunpowder and Metal |
| One recipe per card | Bundled capability access, including cannon ammunition with its vehicle |
| Short-range HQ-tethered forward caches | Physical forward logistics anywhere with a feasible safe route and real staff |
| Eighteen infantry squads and 144 active formation people | Twenty-seven infantry squads, separate vehicle elements, and a declared 384-person military cap |
| Combat vehicles and procedural generation reserved for later | Required parts of the current v0.2 target |
| Neutral actor extension design | Retained only as a possible future direction, with no neutral battlefield party enabled |

Retired identifiers E09, E10, E22, E23, R09, R10, R22, and R23 are not active inventory or recipe entries in this edition. Other IDs retain their conceptual identity while values or access can change. The revision is a design baseline change; previous numeric examples and issue acceptance references must not be mixed with this version.

### 22.4 Review priorities and remaining scope decisions

The largest proposed balance choices are vehicle production time and initial force, baseline and objective income, bridge cost and restore delay, penetration profiles, pressure-mine injury and immobilization, medical recovery access, and card grouping. Map generation thresholds are concrete first acceptance bounds; trial seeds may justify revising them while keeping both sides playable. Adjusting a threshold is an explicit design change with a recorded reason.

The game still promises physical continuity rather than a literal chemistry or industrial mass simulator. Every current vehicle requires actual people, and every current engineered asset requires delivered materials. Future aircraft, boats, additional resources, new terrain mechanics, factions, or generation of items can extend these definitions through a new complete dependency and acceptance review. Current map dimensions and caps are scenario defaults, while delegated command and physical supply remain governing principles.

The software engineer should receive the entire v0.2 definition plus its issue scopes and acceptance scenarios. This document does not prescribe storage layouts, algorithms, technologies, or software classes. It does specify the outcomes those choices must make possible.

## 23 Project-planning amendment v0.2.1 - 25 October 2026

This dated amendment governs milestone sequencing, issue closure and developer readiness where sections 21 and 22 conflict with it. The v0.2 gameplay catalogue and combat rules remain unchanged. These are Game Designer sequencing decisions for the authorized project-planning update, not claims that implementation or playtesting has occurred. See [design decisions](design_decisions.md) and [developer onboarding](developer_onboarding.md).

### 23.1 Milestone and acceptance sequencing

| Scope | Governing planning correction |
| --- | --- |
| M3 Autonomous infantry engagement | Exit requires sustained contested objective play that produces requisition, observable downward intent and upward reports, coordinated squads, and demonstrated retreat and physical resupply on the full-size map. An autonomous HQ result is not required for M3 closure. |
| Full HQ outcome | Verify an autonomous HQ outcome from M5 onward, when a legal winning capability is available, and retain full engagement and campaign outcome evidence for M7. Section 16.3 assault eligibility, capability checks, preparation and combat rules remain in force throughout. |
| G04 and A09 | G04 proves local shell-recipe inputs, consumption, work and exact output. Selecting C31 and verifying its bundled hull-and-shell recipe access is integration evidence owned by G31. This removes the G04/G31 closure cycle; the complete final A09 remains required. |
| G01 and A03 | G01 proves identity, exclusive assignment, holdings, reservations and loaded-versus-loose ammunition accounting. Incapacitation, dropped functional gear and casualty recovery integration are completed with G16. The complete final A03 remains required. |
| G03 and A05 | G03 proves actual staffing, physical source-to-local hauling and local-input readiness without production execution. G04 completes A05 with the integrated recipe's actual local input consumption, present labour, work and physical output. The complete final A05 is not passed by an input-gate fixture. |
| G07 and A13 | G07 proves empty hulls, real qualified people, distinct stations, legal driver-only transfer and combat-deployment crew requirements. Actual main-gun firing and ammunition interaction are completed with G23. The complete final A13 remains required. |
| G08 and A14 | G08 proves terrain, slope, footprint and sight rules with repeatable fixtures. The live destroyed-causeway and stranded-vehicle continuation is completed with G19; M1 does not wait for M4 engineering. The complete final A14 remains required. |
| G13 and A23 | G13 proves class and gross-load decisions against specified bridge fixtures. G20 completes traversal of bridges actually built by engineers; M2 does not wait for M4 construction. The complete final A23 remains required. |
| G11 and M1 | Supply four authored, full-size 4,000 by 6,000 metre fallbacks: River Valley, Lake District, Highland Passes, and Farmland and Towns. Each must satisfy the selected family's geometry and the same mandatory acceptance checks as a generated candidate. One universal fallback does not close G11. |

An early issue may close on its stated foundation evidence while retaining a linked later integration obligation. No deferred acceptance is waived. The issue that supplies the later behaviour owns the complete integrated scenario, with traceability to the earlier issue. Milestone closure requires its relevant integration obligations, not merely completed issue descriptions.

The published backlog applies the same rule to local world round-trips (G11/A19 before full G32 persistence), remote-stock refusal (G14/A24 before live G23/G26 tank supply), wound/care fixtures (G16/A27 before G27 evacuation), capture eligibility (G18/A30 before live APC transport), and tow-load fixtures (G21/A35 before G24 live recovery). G29's early infantry delivery proves the applicable A49 economy and physical-queue rules; its armoured and full-support stages retain the remaining integrated cases. Each later issue retains the complete scenario it enables.

### 23.2 Open design gates

| Gate | Required decision or evidence | Work allowed before resolution |
| --- | --- | --- |
| Presentation, platform and full-map performance | Confirm the intended presentation and target platform/hardware, then record measurable expectations for readability, interaction, generation/loading and operation at the full map scale. Existing renderer and window settings are bootstrap choices. | Measured prototypes and design-independent catalogue, identity, accounting and terrain-rule work. Production world presentation remains gated; this amendment chooses no 2D/3D mode or technical solution. |
| Cover-capacity fairness metric | [D02 decision v0.1 and reference fixtures](d02_cover_fairness.md), dated 26 October 2026, were accepted and merged in PR #52. The D02 definition gate is resolved. | G10 still implements and demonstrates final-world A17/A18; reference arithmetic does not pass those gameplay cases. |
| People and capacity across lifecycles | [D03 decision v0.1, lifecycle matrix and reference fixtures](d03_people_capacity.md), dated 26 October 2026, were accepted and merged in PR #53; the D03 definition gate is resolved. They govern earlier ambiguous membership/admission wording in sections 5, 7, 10, 11, 17 and 19 and define living military membership plus incoming admissions, rear home holds, local reserve/recovery, roster, physical blockage and hull/service lifetimes. | The owning G12/G15/G16/G23/G26/G27/G29/G32 issues still implement and demonstrate their complete gameplay cases. Definition calculations do not pass A01/A04/A20/A25/A41/A45 or G02 native verification. |

These gates require decisions about player-visible outcomes and acceptance. The engineer should surface concrete alternatives or measured constraints to the Game Designer rather than invent gameplay rules. A measured prototype does not commit the production presentation or waive full-size map acceptance.

### 23.3 Procurement admission clarification - 26 October 2026

The freight waiting queue is additional to physical unloading berths. G02's predefined F02 has one unloading berth plus ten off-map waiting places: at most eleven accepted, unfinished freight vehicles in total, including en-route reservations, arrived/waiting trucks and the occupied/reserved berth. Every accepted vehicle reserves one admission place before purchase commitment. Arrival or movement between queue and berth changes state, not the admission count. Reject a purchase needing unavailable places before debit. The ten-place off-map pool is shared by the rear, not multiplied by future additional F02 buildings; their integration belongs to G05.

The independent personnel pull-off admits at most two accepted, unfinished passenger vehicles total, including en-route reservations and vehicles currently disembarking. There is no additional passenger waiting pool. Reserve incoming rear population places independently under section 5.2. A58's full freight case has one blocked truck berthed, ten waiting, and no rear workers; a standard eight-person order still uses its independent pull-off and self-disembarkation to restore real labour.

Section 10.2's one-person-per-second boarding/disembarking rate applies to external manpower arrivals too; section 5.2's no-unloading-labour rule does not waive this handling time. Each stopped vehicle completes one passenger exit per second independently, excluding its seated supplier crew. Each passenger remains aboard until their own exit handling completes, then walks to F08 at their own movement speed. Only their actual F08 arrival converts that incoming place into an available player person. Vehicle admission remains occupied through the final passenger's arrival and the supplier's physical clearance.

Release vehicle admission exactly once on valid pre-dispatch cancellation, or after the completed supplier vehicle physically clears its berth/pull-off. An empty cargo hold alone does not make the bay vacant. Cancellation refunds and releases only that order's reservations. Receiving-stock reservations are separate: reserve free F02 storage for each unload before pickup, leaving any undeliverable remainder aboard. This clarification does not settle D03's forward/strategic personnel-cap membership.

### 23.4 Staffing and queued-work clarification - 26 October 2026

The Game Designer's [G03 assignment](https://github.com/TheInfinityIQ/Trencho_V4/issues/11#issuecomment-6417729799) stages A05 under section 23.1: actual staffing, hauling and local input readiness belong to G03; [G04 retains the full production/output continuation](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6417730111). No recipe value or complete acceptance is waived.

Under the [dated section 8.2 clarification](https://github.com/TheInfinityIQ/Trencho_V4/issues/11#issuecomment-6418512971), player-set facility/pool staffing priorities remain explicitly Emergency/High/Normal/Low until edited; greatest unfilled share and oldest-request tie-breaks do not promote a staffing target. Aging applies to queued work only: Low becomes Normal at 60 simulation seconds and High at 120, Normal becomes High at 60, High stays High and explicit Emergency stays Emergency. It grants no eligibility, source/access/capacity, staff transfer or interruption of a safe carry/park handoff. Released/retried reservations retain the original still-unfulfilled request identity/age. The 120-second Emergency-starvation warning must reflect real Emergency contention; unrelated staff/access/storage shortages retain their own causes. Apply this to implemented queued work kinds; deferred job systems remain separately scoped.

### 23.5 G03 foundation verification path - 26 October 2026

The Game Designer's [verification-path decision](https://github.com/TheInfinityIQ/Trencho_V4/issues/11#issuecomment-6432789314) replaces G03's earlier Windows-only pre-merge gate with reviewed domain logic, actual Godot input in Linux virtual-display CI, and visual review of genuine rendered artifacts from the submitted revision. This is a foundation acceptance path, not a Windows native pass or gameplay-definition change. The renewed single supported Windows click on clean revision1c7d56c failed with SendInput0/1/error122 and the capture remained at t0; further pointer attempts are stopped pending supported tooling recovery.

Windows OS input and native readability remain explicitly unverified obligations under D01 #42, M0 #1 and the G03 evidence record. Windows-first scope, complete A05's G04 production continuation, full playable M0 and all other acceptance obligations remain unchanged. CI image exports after rendered frames are labelled as CI renders; the Designer reviews their matching revision/state metadata before deciding on G03 foundation merge. This note alone grants neither merge readiness nor G04 release.

### 23.6 Production targets, output promises and heavy-output staging - 26 October 2026

The Game Designer's [production-boundary decision](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6432972072) governs the earlier stock-target and fleet wording in sections 6 and 8, alongside accepted [D03 hull admissions](d03_people_capacity.md#5-hull-and-external-service-domains-o8). The [equipment-wording correction](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6432988178) preserves integral guns/mounts. This resolves semantics and stages evidence; it implements no production and grants no G04 runtime release. Recipe inputs, yields, work, masses, access and integral vehicle equipment remain unchanged.

**Stock targets.** A target is a minimum of owned, uncommitted, physically usable rear stock. Usable stock A includes loose goods actually deposited in accessible, type-accepting receiving, depot or facility storage. Exclude goods reserved for another use, issued/loaded equipment, personal carries, vehicle cargo, inaccessible/incompatible stores and unrecovered piles. A source reservation solely for a valid internal relocation is tracked as coverage rather than usable stock.

Display A separately from planned coverage C: otherwise uncommitted active-batch output commitments and valid internal relocation portions between eligible rear stores, each counted once. Source reservation, pickup and deposit move an internal portion A → C → A once; a portion never appears in both. C suppresses duplicate starts but is never usable inventory or a claim on unborn goods. Supplier cargo still aboard and outward shipments count neither. An invalidated destination/commitment removes only its own coverage, preserving actual goods, consumed inputs/work and lawful recovery.

When A+C is below the target, start one whole fixed-yield batch and record its coverage before another start; whole-yield overshoot is allowed. A reduced target does not cancel an already consumed batch. Every start still requires actual local available ingredients, present eligible labour and complete output capacity; a rear-wide stock figure supplies no distant facility. With 200 physical E02 and 80 reserved for another use, A=120: target 150 starts one 100-yield R02 for projected 220, never 30 rounds or duplicate concurrent starts.

**Active output promises.** Reject an edit atomically if capacity would fall below actual contents plus all outstanding inbound/output promises, or its filter would reject an active batch's promised output. Explain the owning batch/claim and apply no part of the failed edit. Other filter edits preserve existing goods and request real relocation. Access loss pauses affected work while preserving consumed inputs, progress and the same output promise; legal restoration resumes. If fully worked but physical completion is invalid, retain completed work without creating goods until legal completion, then create the exact output once. No overflow, refund/restart or unborn-output pile. For 996 kg contents plus a 4 kg R01 promise, capacity 999 kg or an E01-excluding filter is refused; halfway access loss preserves work, and restoration plus the remaining work yields one empty 4 kg E01.

**Heavy output and fleet.** F10 remains one heavy object/vehicle bay. All rear-owned manufactured hulls reserve rear 8 admission at order acceptance; recheck that claim and legal output/collection destination immediately before physical creation. Seven live hulls plus one production promise stay 7/1 with no new hull while the destination is invalid; legal creation converts to 8/0 once. A planned military destination never bypasses rear 8. Accepted Fleet Transfer additionally holds incoming military 24 admission and retains the rear slot until actual HQ handoff or destruction. Parking alone does not release that fleet place. A missing actual P08 or fuel leaves a created hull in the occupied bay; no reset, timer, deletion or released fleet claim counts as clearance.

| Owner and linked continuation | Required evidence and boundary |
| --- | --- |
| [G04 recipes, issue 12](https://github.com/TheInfinityIQ/Trencho_V4/issues/12) | Exact recipe inputs/consumption/work and real empty, unfuelled, uncrewed T01–T05 output at legal F10, with zero passengers/ammunition and the listed integral gun/mount mechanisms retained without spare loose weapons. Prove admission-to-live conversion and occupied-bay refusal. Field-gun manufacture occupies that bay without a vehicle fleet slot. Fresh independent declared recipe setups are allowed; resetting an occupied live bay is not collection. |
| [G07 assembly/stations, issue 15](https://github.com/TheInfinityIQ/Trencho_V4/issues/15) | Positive physical clearance of those same G04-manufactured hulls for all types: actual reporting/boarding, local refuelling and legal parking. Driver-only transfer remains distinct from combat readiness; full station/crew requirements and A12/A13 remain. Initialized G03 yard-t01 is not produced-hull evidence. G23 retains the firing integration already staged in 23.1. |
| [G12 manifests, issue 20](https://github.com/TheInfinityIQ/Trencho_V4/issues/20) | Real field-gun collection with two loaders / 20 seconds; the same gun becomes onboard rather than falsely Dispatch-staged, and cancellation requires unloading. Retain manifest/dispatch/HQ integration, including A20/A21 and D03 admissions. [G13 routes, issue 21](https://github.com/TheInfinityIQ/Trencho_V4/issues/21) retains actual route/fuel travel. |

These later continuations remain required and linked to the G04 outputs they consume; no complete scenario or milestone obligation is waived. G03 foundation acceptance in PR #54 does not itself release G04. The first R01 implementation slice needs a separate Designer assignment after this contract review. Windows QA under D01/M0, full A05 production and playable M0 remain outstanding.
