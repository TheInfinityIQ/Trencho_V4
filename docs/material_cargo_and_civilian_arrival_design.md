# Material cargo and civilian arrivals

10 November authority update: Dawson explicitly answered “Resume animations for
these vehicles” in Lead turn `01a1c6fc-6bab-7db2-af11-a090b04ffabb`. Materials
truck unloading and troop-transport passenger sequences are now authorized;
the earlier pause references below are historical for these two vehicles only.
Other animation work remains paused. Preserve the existing assets and concepts.

Accepted direction, 9 November 2026. Dawson requested material-specific cargo, efficient physical truck packing, rear unloading including paired plank carrying, visible civilian passengers and a completed transport passing a stopped vehicle. His later refinement selects an M35-style cab and six-wheel chassis with an enclosed moving-truck box and an upward sectional rear shutter for materials. The civilian carrier is a separate open passenger vehicle.

Handling follows the accepted Designer direction for this prototype. Package capacities below include the Lead's 10 November choices under Dawson's explicit delegation for abstract materials. The Lead owns the systems, packing algorithm, routes and integration; the Artist owns original faceted art and authored animations. The ongoing pickup and construction-capacity work continues. These requirements do not establish that either transport is implemented or accepted.

Dawson's 10 November update fixes full planks at **2.00 m**, with a central walkable aisle and shelves along both sides of the cargo box. The current **2.735 m interior length** is retained. This supersedes the earlier worker-height ratio and equality between one plank and the cargo-deck length. New animation authoring remains paused under his latest instruction.

Use Dawson's latest rounded faceted style, with enough modelled detail for credible vehicle forms. The Artist's current pickup, material truck and civilian carrier sequence remains in force.

## Cargo shape and material packages

The material truck carries materials, with its actual supplier driver in the cab. Full planks are **2.00 m long**, independent of worker height. Retain the current **2.735 m usable interior length** rather than shortening the truck to one plank. Measure usable interior space rather than the outside of the box. Visible cargo and packing must use the same eventual package dimensions.

Use labelled, resource-specific containers or bundles with rectangular packing envelopes. Every package label shows the actual material name and net contents in kilograms; the shape also helps recognition. Packaging represents existing stock, not a new purchasable or reusable-container economy.

| Material | Visible package | Full package quantity |
| --- | --- | --- |
| Metal | Strapped metal stock | 25 kg |
| Components | Labelled partitioned crate | 24 kg |
| Gunpowder | Marked closed keg | 25 kg |
| Timber | Bound full-length planks | 50 kg, carried by two workers |
| Textiles | Bound fabric bale | 25 kg |
| Electronics | Labelled padded crate | 16 kg |
| Fuel | Labelled jerrycan | 20 kg in the existing purchase units |
| Medical Compound | Labelled sealed crate | 16 kg |
| Battery Cells | Labelled divided crate | 24 kg |
| Explosives | Closed labelled manufactured-goods crate | 24 kg; manufactured only |
| Building Materials | Labelled construction-material crate | 24 kg; manufactured only |

One material unit remains one kilogram. The abstract-material capacities are net-stock quantities, not counts of complete machines, batteries or building kits. For example, a 24 kg Battery Cells crate contains 24 kg of cells, not 24 whole vehicle batteries. The selected 16 kg limits leave more package space for padding, inner containers or bulky contents; compact parts and cells use 24 kg. All remain within the existing 25 kg single-person stock-carry allowance.

The two proposed crate envelopes are **400 × 300 × 240 mm** for Components, Explosives, Medical Compound and Battery Cells, and **600 × 400 × 320 mm** for Electronics and Building Materials. These are proposed outer dimensions, separate from the selected net-stock capacities; they do not establish model or handling acceptance.

Purchasing still accepts any valid whole-kilogram quantity. Package sizes are not order increments. Split an order into full packages plus its exact remainder. A partly filled crate keeps the full outer envelope but contains and displays only that remainder, without rounding stock or cost upward. For example, 30 kg of Components uses a 24 kg crate and a 6 kg crate, retaining exactly 30 kg. Timber remainders retain the full plank-length envelope, with fewer or thinner visible planks. Board count is presentation, not a new conversion from kilograms to individual planks. No new kilogram-to-litre conversion is introduced for fuel. Explosives and Building Materials remain unavailable for direct purchase. Material prices and recipes are unchanged.

## Shelves and central aisle

Keep the central aisle and rear entry/extraction space clear, with storage shelving on both sides. Provide four shelf designs suitable for different material packages. Shelves, restraints, handles, hand access and worker space reduce usable cargo space; they are not additional packable volume.

The current dimensioned concept proposes these four families. These dimensions remain proposals, not approved model dimensions or demonstrated handling access:

| Proposed shelf family | Outside length × depth × height |
| --- | --- |
| Long-stock rack | 2.20 × 0.53 × 1.50 m |
| Adjustable crate shelving | 0.70 × 0.53 × 1.50 m |
| Restrained can and keg rack | 0.70 × 0.53 × 1.50 m |
| Protected-cargo cabinet | 0.70 × 0.53 × 1.50 m |

The candidate layout uses 0.55 m storage zones on each side and a 0.80 m clear single-file aisle within the current 1.90 m width. It illustrates all four shelf families; a shipment need not contain every family or every material. Actual worker grips, paired extraction, turning and ramp clearance remain unproven. A top-view fit is not proof of a usable two-worker handling route, and paused animation work must not be restarted merely to claim that proof.

The accompanying package-dimension proposal covers all nine raw and two manufactured materials. Treat those outer envelopes as representative game packages requiring review, not universal real-world material sizes or accepted new purchasing units. The exact contents in the table above remain unchanged. Proposed individual-board dimensions or illustrative wood density do not redefine the 50 kg timber bundle, integer purchase quantities or fuel units.

## Packing and quoted capacity

The existing supplier freight limit is **5,000 kg per truck**, with **20 requisition transport fee per truck**. Existing material prices and worker-order prices stay the same. New spatial constraints may require more trucks than a weight-only quote; show the resulting vehicle count and total fee before Confirm.

Use three-dimensional rectangular packing with supported stacking. Respect usable length, width and height, non-overlap, stable support, permitted package orientations and access for rear unloading. Jerrycans and marked upright packages stay upright; timber stays horizontal. Weight and physical fit are independent hard limits. A package cannot protrude through the cab, box or closed shutter to make a plan fit.

Among valid plans, use the fewest trucks, then minimise the number of trucks across which each material is divided. Keep one material together when splitting it saves no truck. If a feasible two-truck plan keeps all fuel on one truck, an otherwise equivalent two-truck plan should not divide that fuel. A material whose quantity cannot fit one truck must split, using as few trucks for it as the valid overall plan permits. Keep same-material packages clustered within a truck where rear access allows.

Packages have explicit quantities and envelopes for the confirmed shipment. Unload accessible packages in a feasible rear/top-first order; workers cannot reach a buried front package through other cargo. The purchase commits the complete quoted shipment once. Partial fill, packing and later handling must preserve the exact ordered stock.

The Lead chooses a bounded algorithm suitable for order planning. Consistent results for the same order are desirable. Do not claim a proven global optimum merely because a packing heuristic returned a valid plan. This is not a request for a per-frame solver, packing benchmark or new planning framework.

## Rear shutter and physical handling

The material box has an upward sectional roll-up rear shutter, following Dawson's latest reference. Open it while the vehicle is stopped, before workers enter its rear handling area or pick up cargo. Workers walk to actual rear access points, collect the real package, carry it to the receiving store and deposit it. The door animation alone neither transfers goods nor makes them available at the Table.

Reserve usable worker access and grip space inside the box as part of the packing plan. The required central aisle and a suitable rear step or ramp may support actual worker entry onto the stopped bed for extraction. That space is unavailable for cargo. Full-length planks require both workers to reach their grips and move the bundle through the rear opening before the ground carry; reaching through other cargo or making a front grip jump outside the truck is not acceptable. The Artist and Lead must agree on the visible approach, extraction and step-down sequence, rather than showing only a disconnected carrying loop. This is handling access, not general climbing or player access to the cargo interior.

Keep the rear door and handling area clear while people or packages use them. Close the shutter and confirm the rear is clear before departure. A missing worker, route, partner or destination space leaves an understandable waiting state. Show actual package collection, carrying and deposit separately from reserved goods.

## Two-person plank handling

A timber bundle uses two ordinary eligible workers from the current Receiving or Hauling pool. Hardhat presentation does not create a new profession or authorise taking busy construction staff. Carrying timber is hauling, so it does not consume the separate construction-worker capacity.

Both workers approach their positions and lift together, then walk with one shared bundle and lower it at the destination. The full bundle is 50 kg total: at most the existing 25 kg allowance per person. A light remainder still needs two people because of its length. Other packages retain single-person handling within that person's allowance. The current four-handler limit at a receiving berth counts people, so two pairs use four handlers, not two.

This rule follows long timber through ordinary rear hauling, including unloading, Table-to-production supply, storage relocation and recovery. Depositing it at the Table does not shorten the planks or turn them into a single-person crate. A smaller recipe demand may use a lighter full-length bundle containing only the requested available kilograms, with two handlers and the remaining stock retained at its source. Production consumes its actual ingredients through the normal recipe; no automatic cutting service, new conversion loss or free processing is implied. Other materials keep their current handling rules. The Lead chooses how the same joint-carry capability serves these callers; a consistent timber rule does not require a general cooperative-work framework.

Reserve both actual people and the required goods/destination capacity before lifting. Count the shared bundle once. Neither person performs another task while helping. If only one eligible worker is available, display that the bundle is waiting for a partner; do not fabricate a helper. Reassignment or cancellation before lifting releases the uncollected commitment safely. After lifting, use a safe shared put-down or completion before either worker leaves; do not delete stock or leave a lone worker carrying a full 50 kg bundle.

## Visible civilian arrival

Create a separate faceted open passenger carrier inspired by Dawson's [WW2 Armor reference](https://www.ww2armor.org/about-zeyde). Use neutral civilian colour and optional invented local markings, without US or Allied insignia or weaponry. Keep the cab driver and the actual purchased passengers visible. The existing eight-person order still brings eight people; the supplier driver is separate and does not join the workforce.

Passengers sit in real allotted places while travelling. Once the carrier is stopped and rear access is ready, each person stands, walks to the back, crouches, jumps down, lands and walks to the Supply Table arrival point. Preserve the same person's identity throughout. Do not show a standing passenger outside the vehicle while their seated copy remains aboard. People become available workers only after their actual arrival; incoming population reservations remain until then.

The disembarking cadence follows the complete action and clear rear/aisle space, replacing the earlier one-second exit shortcut. The next person may prepare while a landed passenger walks away if the path is clear. The carrier can leave once its last passenger has landed and cleared its rear, without waiting for the whole walk to the Table. That departure does not turn unfinished passenger walks into completed workforce arrivals.

## Concurrent service and passing

Materials and civilian carriers need separate usable stopping positions so both can unload in the same convoy. This supersedes the older shared-berth serialization. Keep the one-convoy ordering gate: a new order becomes ready only after actual material deposits, actual purchased-person arrivals and the required departure starts are complete. Early passenger-carrier departure cannot release missing handover conditions.

A finished carrier behind a stopped unloading truck should use an actual clear passing route and continue toward the exit. Its route must account for current vehicle bodies, road space, rear handlers and walking passengers. If that route is occupied or too narrow, wait with a reason and continue when clearance actually changes. Do not drive through another vehicle, teleport, skip elapsed time or interrupt its unloading to manufacture progress. Use the new models' actual footprints for spacing and service access. A general town-traffic simulation is not required for this bounded situation.

Keep the earlier general AI-vehicle contact response deferred. A bounded supplier bypass with protected handling areas is sufficient here. If the manager or personal pickup currently blocks that bypass, the supplier holds before further travel would enter the occupied space and explains the blockage. It retains the same vehicle, cargo, destination and remaining trip, then continues after actual clearance; waiting incurs no distance fuel. This does not authorise pushing, crushing, repositioning the player, closing menus, taking control of the pickup or freezing the rest of the game. An overlap already created by player intrusion, spawning or restoration remains a separate unresolved contact case; do not claim that a passing-path hold resolves every such case. No new collision-response or recovery system is required for this transport block.

## Motion and animation review

Both vehicles show an actual driver, wheel rolling and steering, restrained turn roll, acceleration/braking pitch and appropriate exhaust while operating. These visuals follow real vehicle activity and preserve Pause/speed behaviour. No cosmetic effect grants movement, fuel, goods or people. Existing fuel ownership remains in force; the personal pickup's development fuel exception does not apply to these transports.

When animations are ready, provide full videos for Dawson's approval of the shutter cycle, single-package handling, complete paired lift/carry/put-down, civilian seat-to-ground-to-Table sequence and vehicle movement. Label asset previews separately from integrated gameplay footage. Dawson's animation acceptance remains pending until he approves the shown versions; new animation authoring stays paused until he resumes it. This expands the current design without cancelling the pickup, changing military command or requiring a broad test campaign.
