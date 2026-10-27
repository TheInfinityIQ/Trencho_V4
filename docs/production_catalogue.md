# Connected non-heavy production catalogue

[Designer scope](https://github.com/TheInfinityIQ/Trencho_V4/issues/12#issuecomment-6455365836), based on accepted connected rear PR70/main `ac8dfaeb`. Related #12; full G04/M0 remain open.

The same connected base now supports all 23 non-heavy recipes. Canonical inputs, operator-work, count and unit mass come from GDD 6.1/6.3; no balance substitutions are made. All products are empty/unloaded/unissued physical stock. Production creates no personnel, loaded ammunition, armed device or battlefield capability.

| Facility | Recipes |
| --- | --- |
| F04 Workshop | R01 Service rifle; R03 Helmet; R04 Body armour; R05 Support machine gun; R06 Mortar; R08 Engineer kit; R19 Marksman rifle |
| F05 Munitions | R02 Rifle rounds; R07 Mortar bombs; R14 Artillery shells; R24 Smoke rounds; R27 Explosives; R32 Tank shells; R33 Autocannon rounds |
| F09 Support | R11 Medic kit; R12 Medical packs; R15 Recon drone; R16 Drone controller; R17 Drone batteries; R18 Field radio; R20 Binoculars; R21 Stretcher |
| F13 Materials | R26 Building materials |

The six Vehicle Works recipes R13/R25/R28/R29/R30/R31 remain separate. Their admission, heavy output, drivers, fleet and collection obligations are not bypassed by this catalogue.

## Sessions and controls

Normal launch remains essential-only: R01/R02/R08/R26/R27 are accessible, with other recipes shown locked. Orders now buys all nine canonical raw resources, including Textiles, Electronics, Fuel, Medical compound and Battery cells. M06 and M11 still require manufacture. Existing prices, transport fees, admissions, arrival and unloading rules apply.

Orders also offers **Essential recipes** and **Expanded non-heavy catalogue**, followed by an explicit **Start new session** action. Changing the configuration dropdown alone does nothing to the current base. Starting a session replaces its live state with the same declared prebuilt twelve ordinary people, 2500 requisition and no recipe goods, paused. Expanded access is copied at construction; it is controlled content access, not actual card offers, unlocks or progression. Inspection, tabs and diagnostic visits continue to preserve the current scene and inventory.

Work selects Workshop, Munitions, Materials or Support and one compact recipe menu for the selected facility. Modes, targets, pause, enable and cancel apply to that selected owner. A consumed-batch change asks for explicit confirmation of permanent input loss; declining retains its work and promise. The warning totals consumed ingredients by type to remain readable with many physical input portions; full receipts remain authoritative. Recipe-specific modes, targets, histories and unique batch/output IDs survive switching. Status names the selected recipe and output. Staff adds the existing four-position Support duty. Hauling groups Materials and each facility's equipment outputs into short menus; its physical stores and reservations are unchanged.

## Engineering and verification

The accepted F05 confirmed-selection lifecycle is shared by three explicit facility owners, preserving the fixed R01/R02 public defaults and shell diagnostics. F13 remains independent. The rear owns these four activities on the existing event clock and ledger; no scheduler, second inventory, autoload, seventeen diagnostic scenes or per-recipe PRs are introduced.

Nine focused domain cases check all 23 specifications against independently parsed GDD recipe/equipment rows, exact full-work outputs and masses, each new ingredient's missing/reserved/foreign/remote/personal/carried rejection, copied access and raw prices, whole output promises and lowered targets, decline/confirm/stale selection with histories, disjoint simultaneous staffing/interruption, distinct output minima and actual raw-purchase chains. Component tests explicitly initialize local materials; the connected case starts with no goods, purchases all nine raw types, makes helmets/medic kits/ten explosives/materials, then engineer kits/batteries and bombs fed by those actually hauled explosives.

Two focused SceneRunner flows use actual pointer/keyboard commands for expanded session creation, all nine purchases, shared staff, hauling, selections/targets and new Workshop/Support confirmations. They reuse proven pointer/spinner/embedded-menu targeting and advance controlled elapsed time through the public clock. Four representative normal/small images are retained under `.artifacts/production-catalogue/`. Full normal checks and all eight existing focused negative/restored controls remain; no per-recipe controls or all-image proof packet is added. Linux engine input/render evidence does not establish Windows-native acceptance.

Construction, training, final starting scenario, heavy/fleet/collection, actual cards, world/AI, save/load and full G04/M0 remain outside this assignment.
