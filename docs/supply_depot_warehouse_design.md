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

A partly filled crate still occupies its whole package position. Reducing its contents does not make a fractional slot available or merge it with another crate. Free the position only when the actual package vacates it. Repacking is not an automatic capacity shortcut.

## Full storage and truck feedback

When a package has no compatible receiving space, retain it on the same truck. Show a warning icon above that actual vehicle with an understandable reason, such as **Warehouse full — free storage or expand it**. Keep **Preparing storage**, **Waiting for haulers** and **Route blocked** distinguishable from genuinely full storage. Other packages with valid reserved destinations may continue unloading.

Do not deposit blocked cargo on an unplanned floor pile, create stock at the Table, remove packages visually before pickup or complete the order early. The player may free space, reassign labour or build an expansion; delivery continues through physical work when the real blocker clears. Existing money, admission and convoy rules still govern purchases. Shipment arrival does not promise immediate unloading, and all actual handover conditions must still finish before the convoy ordering gate releases.

## Ordinary return recovery

Provide a deliberate **Return cargo** action for a material truck still at the receiving area. Returning only its undelivered remainder can reopen ordering, but a warehouse already full of unusable material also needs a way to free actual space. The player may therefore add selected unused, unreserved purchased raw-material packages from the warehouse or its marked staging area to that same truck's return load when they fit. This is optional selection, not automatic removal of warehouse stock or a new general trading service.

Show the selected quantities, estimated goods refund and retained transport fee before confirmation. On Confirm, stop new unloading for that truck and safely release its uncollected pickup claims and destination commitments. Loads already physically held by workers retain their legal reserved destinations and finish their safe handover. They remain received and paid unless subsequently selected as available warehouse packages. Do not take goods out of hands, fabricate destination space or alter unrelated convoy members.

Workers physically reload the selected packages through the same handling, partner and route rules. Respect the truck's remaining payload, package fit and rear access. Select whole existing packages, including partly filled packages at their actual net quantity; do not split or merge crates without repacking. Reloading can clear complete positions or a fixture bay when the truck has room. It does not always provide enough space recovery: use the bounded outdoor staging below when its remaining slots cannot take the required packages. Warehouse space is freed through actual pickup and clearance, not by selecting Return.

Keep the same truck and actual goods. Once safe loading and all active handling finish, close its rear, clear the handling area and physically drive it to the exit. A blocked departure waits and explains why. The player receives the refund once the returned goods actually leave, not when Return is requested. Only the actual unused purchased raw quantities returned are refundable, at their paid goods price under the fixed prototype catalogue. Keep the original transport fee, with no additional restocking or collection charge for using this truck's existing departure. Used goods, manufactured materials, initial/free/debug grants and goods left in the warehouse or workers' hands are not refundable.

Record returned quantities and pending/paid refunds separately from delivered goods. The returning member resolves for the convoy gate when its safe return departure starts; other freight handovers and purchased-person arrivals must still finish. A later exit credits the refund once. Preserve the existing pre-dispatch cancellation policy separately. This is a bounded recovery using a present freight truck, not a civilian return system, remote collection fleet or permission to erase cargo.

## Bounded outdoor staging

Storage congestion should have ordinary recovery even when the departing truck cannot take more goods. Provide one reusable, visibly marked staging area for the starting Supply Depot, empty at the opening. Use **6 × 4 m** as the reversible starting footprint, with a compatible temporary support layout no higher than the current **1.8 m** warehouse fixture. Reserve its access and footprint from building placement, roads, doors and the supplier bypass. Warehouse expansions do not automatically add more staging areas.

Its limit is **one selected warehouse fixture's legal package layout and contents at a time**, constrained by actual supported fit, working access and a 10,000 kg absolute ceiling. That ceiling does not grant space or override the fixture-equivalent limit. The Lead must size the usable layout to hold a complete valid fixture load with real package/support positions; net-kilogram room alone does not establish recovery. Do not grow the pile or capacity on repeated clicks.

The player explicitly selects a warehouse bay to clear. Reserve the whole clearing batch and valid staging positions before pickup; finish or safely release conflicting existing claims first. Existing Hauling workers move the actual packages, keeping their quantities, ownership and purchase origin. Long timber still uses two workers. Preparing any needed temporary supports follows the existing worker-visit process, using included fixtures and reused smoke, with no extra charge, new profession or animation authoring. Do not start a second source-bay batch until the staged contents have physically left and the area is clear.

Only goods already deposited in the warehouse may enter this recovery area. It is never a truck-unloading destination, automatic overflow, production-output sink or a source of new goods or refunds. Staged stock remains available for physical collection into production, valid warehouse restocking or an eligible confirmed return. Display its actual contents separately from warehouse capacity and the debug cache.

Keep the source bay closed to new deposits while it is being cleared, so incoming freight cannot refill each vacated position before the task finishes. For the identified blocked-convoy case, first return the unwanted remaining freight member or members without requiring warehouse reload; let safe carries and departure conditions finish. Then clear one warehouse bay to staging and reuse or reconfigure it for the missing input. This gives an ordinary space-recovery sequence while preserving the rule that full-warehouse trucks cannot unload onto the ground. Staging changes no stock quantity, purchase price or construction-material availability.

## Explicit debug supply exception

Preserve Dawson's existing free raw-resource shortcut for quick prototype testing. Each successful explicit Instant Resources action supplies exactly 1,000 kg of each of the nine raw materials immediately and free, with another batch on another successful click. It does not require warehouse expansion. Explosives and Building Materials remain outside that grant.

Deliver this batch to a clearly labelled debug supply cache, retaining the existing debug-use marker. This is an explicit acquisition and storage bypass, separate from a normally packed warehouse receipt. Keep the cache accessible without obstructing roads, doors or the supplier bypass. It must not enlarge normal warehouse capacity, make ordinary shelf fixtures appear, or become a destination for normal incoming freight or automatic overflow. Workers may physically collect its goods in that debug-marked session; the grant is not evidence that the normal supply chain worked.

The new batch is all or nothing. A failed command leaves actual stock, existing paid orders, normal fixtures and reservations unchanged, without a partial grant or abandoned free order. Successful feedback identifies the free debug batch and storage bypass explicitly. Ordinary full-warehouse deliveries retain their cargo and warning. Only explicit debug commands may use this exception; this preserves the earlier testing convenience rather than quietly weakening normal storage rules.

## Building spacing and joined expansion

The current placement grid is **1 m**. Use a **two-cell, 2 m minimum clear gap** between ordinary building footprints, including between an ordinary building and a warehouse. Preserve existing road, entrance and working-access requirements as well.

Two compatible warehouse modules may meet with zero gap along a full matching cardinal edge. Corner contact, diagonal proximity or a mismatched partial edge does not join them. Preview the connection and retain a real passage into the expansion. If an occupied or reserved fixture prevents that passage, require clearance or a different valid join rather than teleporting its goods.

The added module must be paid for and built before it opens into the completed warehouse. Replace the compatible shared wall with usable passage so the result is a physically connected, lit interior. Existing stock, fixtures, people and reservations retain their identities and locations. Each completed module contributes its capacity once; joining is not a stock copy or a second receipt of the same goods. The combined view should let the player understand the usable space as one warehouse.

Removing a module must preserve actual goods, reservations and access to the remaining warehouse. Follow the existing safe-clearance rules before dismantling; an occupied or promised storage bay cannot simply disappear. The Lead owns connection, storage and navigation implementation.

## Readiness and continuing work

The older empty-field opening and solid-exterior depot references are superseded for this warehouse feature. The three frozen pickup design documents remain unchanged until their adoption. The ongoing pickup/capacity and material/civilian transport work is not cancelled. New animation authoring stays paused until Dawson resumes it; ready animation versions still require full videos for his approval. Use brief checks of changed behaviour under the existing verification policy, without a new regression campaign or local engine run.
