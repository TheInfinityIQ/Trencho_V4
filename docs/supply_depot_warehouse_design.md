# Supply depot warehouse

Accepted gameplay direction, 10 November 2026. Dawson requested a prebuilt starting supply warehouse that stores all material types, allows workers and the manager inside, provides lighting and open upward warehouse doors, creates shelving after a worker reaches its site, and prevents unloading when compatible storage is full. Adjacent warehouse modules join as one expanded interior. This note records that direction and the Designer's prototype defaults; it does not claim implementation or playtest acceptance.

## Opening and prototype defaults

Use a **12 × 16 m module with 4.5 m clear interior height** as the initial size. These are reversible starting dimensions. Put the starting warehouse inside the southern build field, immediately north of the Supply Table/apron, with its main entrance facing the approach. Keep truck stopping and passing space, the personal pickup and pedestrian access clear. Leave a compatible full edge available for later expansion. The Lead chooses exact coordinates using the actual footprints and routes.

The starting warehouse is already complete and free, as Dawson requested. Keep the same manager, 2,500 requisition, 500 actual Building Materials and four existing workers. Those workers remain in the shared Hauling pool. Place the same 500 Building Materials in enough compatible, preinstalled warehouse fixtures to hold them: twenty full 24 kg crates and one 20 kg remainder. These opening fixtures and goods are initial state, not additional grants or runtime shelf construction. Do not leave another copy of that stock at the Table.

The Supply Table remains the ordering and civilian-arrival interface. Its former abstract storage allowance must not become an overflow that lets new freight bypass a full warehouse. Actual received stock belongs at its physical warehouse fixture or another explicitly valid existing destination, counted once.

Additional modules use the current Storage Depot baseline of **100 Building Materials and 160 builder-work units**. Keep **10,000 kg per completed module** as the structural stock ceiling, while compatible physical fixture space and access may limit usable capacity sooner. Construct modules using actual builders and materials under the shared construction-worker limit. A blueprint grants neither usable floor space nor storage capacity.

## Workers and fixture costs

Keep the Storage Depot default at **zero resident workers**. Existing eligible Hauling workers prepare shelves and move stock; there is no new storekeeper profession or free employee. A worker preparing a fixture is occupied and cannot simultaneously unload, carry or build elsewhere. This fixture task is hauling support and does not consume a construction-worker place.

Shelving and lights are included in the warehouse's construction cost. Preparing an internal fixture has no additional requisition or Building Materials charge and requires no separate manufacturing chain. Its labour and actual visit still occur. This keeps the player managing storage and labour without having to order each shelf.

## Walkable, lit interior

Workers and the same manager can enter through actual ground-level openings and walk inside the shared world. Walls, shelves and stored packages have real occupied space; usable aisles and doorways stay clear. A whole-footprint solid blocker with a decorative interior does not satisfy this requirement.

Use upward-opening warehouse doors, already in their open position when the building becomes usable. Interior lights are on at completion, without a new power or fuel economy. New animation authoring remains paused: use an open door pose and the existing low-poly completion smoke rather than commission a new door animation. The manager's walking views and normal management controls remain usable inside. General climbing, extra floors and vehicle access to the interior are not implied.

## Material storage and on-demand shelves

Support all nine raw materials and both manufactured materials in the [material transport design](material_cargo_and_civilian_arrival_design.md). Explosives and Building Materials remain manufactured-only. Preserve the selected net-kilogram package capacities and exact partial quantities. Crate shelving and long timber/log racks are visibly and physically different. Other package families use compatible fixtures; shelf appearance must not redefine their contents.

Prefer existing compatible shelf space. When more space is needed, reserve an empty fixture site that fits the required rack, its stored packages, worker grip space and a valid route. An eligible Hauling worker walks to that site. Once the worker actually arrives, the shelf appears within the reused low-poly smoke. It is created once for that reserved site and then becomes ready for physical deposits. An empty compatible shelf can be reused later without another construction effect.

Shelf preparation happens before cargo is collected for it. A carrier cannot prepare a rack while simultaneously holding its incoming load. An obvious replacement of an empty, unreserved fixture may use the same worker-visit process if the new fixture fits; do not rearrange occupied racks or erase their contents to satisfy demand. A visit or smoke effect creates a fixture, not delivered stock.

Reserve actual net-kilogram headroom and compatible package positions without double-booking them across trucks, workers or production. An empty area may be reserved for preparation, but goods stay on the truck until the fixture is ready and the real handling path is valid. Long timber retains its two-worker rule inside the warehouse and on onward rear hauls. A rack's geometric fit is not proof of paired access or grip clearance.

## Full storage and truck feedback

When a package has no compatible receiving space, retain it on the same truck. Show a warning icon above that actual vehicle with an understandable reason, such as **Warehouse full — free storage or expand it**. Keep **Preparing storage**, **Waiting for haulers** and **Route blocked** distinguishable from genuinely full storage. Other packages with valid reserved destinations may continue unloading.

Do not deposit blocked cargo on an unplanned floor pile, create stock at the Table, remove packages visually before pickup or complete the order early. The player may free space, reassign labour or build an expansion; delivery continues through physical work when the real blocker clears. Existing money, admission and convoy rules still govern purchases. Shipment arrival does not promise immediate unloading, and all actual handover conditions must still finish before the convoy ordering gate releases.

## Building spacing and joined expansion

The current placement grid is **1 m**. Use a **two-cell, 2 m minimum clear gap** between ordinary building footprints, including between an ordinary building and a warehouse. Preserve existing road, entrance and working-access requirements as well.

Two compatible warehouse modules may meet with zero gap along a full matching cardinal edge. Corner contact, diagonal proximity or a mismatched partial edge does not join them. Preview the connection and retain a real passage into the expansion. If an occupied or reserved fixture prevents that passage, require clearance or a different valid join rather than teleporting its goods.

The added module must be paid for and built before it opens into the completed warehouse. Replace the compatible shared wall with usable passage so the result is a physically connected, lit interior. Existing stock, fixtures, people and reservations retain their identities and locations. Each completed module contributes its capacity once; joining is not a stock copy or a second receipt of the same goods. The combined view should let the player understand the usable space as one warehouse.

Removing a module must preserve actual goods, reservations and access to the remaining warehouse. Follow the existing safe-clearance rules before dismantling; an occupied or promised storage bay cannot simply disappear. The Lead owns connection, storage and navigation implementation.

## Readiness and continuing work

The older empty-field opening and solid-exterior depot references are superseded for this warehouse feature. The three frozen pickup design documents remain unchanged until their adoption. The ongoing pickup/capacity and material/civilian transport work is not cancelled. New animation authoring stays paused until Dawson resumes it; ready animation versions still require full videos for his approval. Use brief checks of changed behaviour under the existing verification policy, without a new regression campaign or local engine run.
