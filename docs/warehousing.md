# Physical Supply Depot warehouse

Current implementation belongs to `codex/materials-warehouse-loop`, based on
`1d7ae006e123861c6138ac0ec2ee0cfdd967acea`. Publication/merge status is tracked in
[PR145](https://github.com/TheInfinityIQ/Trencho_V4/pull/145). [Accepted design](supply_depot_warehouse_design.md),
[pre-code plans](feature_plans/warehouse_v11.json) and the
[actual system atlas](system_atlas.html) distinguish current code from recovery
and transport work still to implement.

## Opening and storage

The empty-field opening has one free completed **12×16m** warehouse at `(120,169)`,
with **4.5m** clear height, a flush floor, raised-open **4×4m** portal and eight
lit ceiling fixtures. Its two preinstalled crate racks hold the same existing
**500kg Building Materials**, represented once by twenty24kg crates and one20kg
remainder. The four starting people remain real shared Hauling workers.

Each module has eight finite rack sites. A crate rack has16 physical package
positions; timber uses a distinct open four-position support rack. Each partial
package retains its whole outer envelope. The10000kg/module structural ceiling
never overrides occupied cells, compatible fit, access or outstanding promises.
The Supply Table remains the ordering/arrival interface and provides no ordinary
freight overflow. Explicit Instant Resources still grants exactly1000of each
nine raw materials to a separate labelled source-only DEBUG cache.

`IdentityLedger` alone owns stock quantities, origins and custody.
`WarehouseService` indexes actual stock IDs into cells and owns finite space and
handling reservations. Ordinary production/construction callers keep their
canonical `receiving` holder but resolve the selected stock's real fixture
position. Views and connected-module summaries never create a second inventory.

## Worker preparation and access

Allocation reuses compatible ready or pending fixtures before creating another
rack. A real worker reaches the reserved clear site, the existing low-poly smoke
runs1.5s, the rack appears at its opaque midpoint and becomes usable at the final
activity boundary. No new animation clip, extra profession, fixture fee or
construction-worker place is introduced.

An incoming package may reserve a free cell while its service face is busy.
The worker must acquire actual safe access **before pickup**; otherwise the
source claim and goods stay aboard. Specific blocker-clearance and reservation
events wake the wait. Finished haulers continue from the warehouse instead of
reporting to the Table between trips. Idle workers clear all shelf service
positions by using distinct end-apron rest points.

If no empty floor remains, a wrong-family Ready fixture can be converted only
when completely empty, unreserved and without a held handling face. The worker
still visits; the old fixture stays visible until the opaque smoke swap. Ready
commits the new family, while cancellation before Ready restores the previous
empty fixture. Domain episode42864955592 observed the actual visit and1.5s
conversion, preserving occupied opening stock and stopping before Timber pickup.

Full compatible storage leaves affected goods aboard the real truck and supplies
its above-truck warning. Readiness, preparation and blocked access are separate
states. There is no recurring overlap poll or whole-warehouse visual rebuild.

## Walkable expansion

Normal footprints require two clear1m grid cells. Warehouse modules may touch
only on a full matching cardinal12m or16m edge. A blueprint adds no usable space
and removes no existing wall. Actual completion adds eight new fixture sites,
opens the shared boundary on both modules and preserves existing stock IDs.
The existing additional-depot cost remains100M11/160builder-work.

Actual measured wall/post/floor/rack/package colliders replace the completed
warehouse's former solid footprint. Player entry/exit uses `Area3D` events for
roof cutaway and removal safety; hiding the roof never removes wall collision.
The existing camera-mode event keeps the actual ceiling visible in first person.
Occupied, reserved or connecting modules cannot be casually dismantled.

## Routing decision and evidence limits

The stocked expansion check exposed repeated per-crate GDScript visibility
searches: run42854233894 recorded736queries consuming26.483204s before the
unchanged28s watchdog. A native-grid-only intermediate completed but still
performed1519queries/4.064606s. Warehouse source selection now tries actual
packages in deterministic nearest-feasible geometric order, rather than exhaustively
optimizing every possible walking route. Actual source/access/capacity checks
remain authoritative; this deliberately does not promise a globally shortest walk.

Warehouse walking uses scene-owned Godot `AStarGrid2D`, uniform0.5m cells and
native jump search, with the original exact endpoint/segment guard and conservative
fallback. Geometry refreshes only when actual obstacles/bounds change. A bounded
cache reuses only exact endpoint queries within that geometry and returns detached
paths; stock availability and person clearance are never cached there. Vehicle
and legacy routing retain their existing authority.

Run42856744885 passed full-storage admission and completed-module join with
67route queries,16native searches and24query-cache hits. Placement measured
29.473ms on that runner; this is **not** a60FPS acceptance result. Earlier
nearest-feasible run42855896720 measured22.278ms, so the single observations
must not be presented as a controlled wall-time improvement from caching.

The full-state check explicitly prepopulated128legal cells with real Ledger
stock; it did not demonstrate128normal receipts. Expansion used the existing
explicit Instant Build command, not normal construction labour. Separate ordinary
receipt run42852556683 delivered288M02 at1x through actual workers, prepared
exactly one additional rack and left no promises or accounting discrepancy.
The navigation-affected receipt was rechecked in42856096688. All these are
unpublished source overlays on the recorded main base, with normalized source
hash manifests; a green main check alone is not candidate acceptance.

Initial PR validation42860686208 stopped before Godot because copied console
transcripts had extra blank lines at EOF. Their documentation copies now normalize
only those trailing blank lines; original artifact bytes/digests remain retained.
Publication must check the staged/base-to-head diff, including newly added files.
The native current-change check explicitly loads all changed production scripts,
so a subsequent documentation-only required job cannot imply unperformed source
validation.

The explicit remote visual demonstration prepares missing virtual-display/video
utilities on its GitHub runner only. This infrastructure setup is separate from
the unchanged45s outer/28s native-child deadlines. It opens no local game window
and makes no change to the human editor or mouse.

## Remaining delivery work

- Actual default-scene models, entrance/floor, lighting, roof camera modes and
  existing smoke preview passed scoped remote presentation. Joined native
  appearance and keyboard/E acceptance remain unverified.
- Engine-generated UID/import sidecars are retained. Exact-head technical/design
  review and required checks govern publication; human F5 acceptance is separate.
- Implement the separately diagrammed ordinary return/reload and finite staging
  recovery. Neither exists merely because its design is recorded.
- Implement genuine paired timber custody/handling; current legacy single-person
  receipt is not acceptance of the requested two-worker timber transport.
- Utility trips now reserve and collect actual packages from one connected
  warehouse, use exterior curbs and release each shelf face after pickup. The
  direct100kg trip/return and exact7kg fuel carry passed again after final
  claim-release/event-wait cleanup in run42876605327. Publication review is separate. Refuelling exposes
  an explicit20kg can limit and never silently clamps an API request.
- Finish the separate cargo truck/personnel/pickup integration and paused animation
  work under their own readiness records. Static exports are not human appearance
  approval or completed transport gameplay.
- Normal player acceptance and full-game60FPS remain open.

## Sources

- [Godot4.7 AStarGrid2D](https://docs.godotengine.org/en/4.7/classes/class_astargrid2d.html):
  native grid search, solid-region updates, uniform jump-search limitations and
  single-thread ownership.
- [Godot4.7 Area3D](https://docs.godotengine.org/en/4.7/classes/class_area3d.html):
  body entry/exit signals for actual occupancy.
- [Godot4.7 OmniLight3D](https://docs.godotengine.org/en/4.7/classes/class_omnilight3d.html)
  and [lights/shadows](https://docs.godotengine.org/en/4.7/tutorials/3d/lights_and_shadows.html):
  bounded influence and explicit shadow cost. Actual fixture coverage still needs
  rendering acceptance.
- Artist manifests under `game/warehousing/assets/`: exact metric exports,
  accepted static QA and provisional hand-contact limitations. Editable Blender
  sources are preserved beneath `source/.gdignore`, so opening the game imports
  explicit GLBs without launching Blender conversion.

## Current-change vehicle compatibility

The [pre-code adapter diagram](diagrams/warehouse_vehicle_compatibility.mmd)
preserves the existing utility-truck and fuel activities. Ledger claims are
reserved atomically per package; a worker collects them one at a time at actual
shelf faces and deposits into the same finite truck. Source access waits wake
from warehouse events. Walking geometry is compared only after those events;
vehicle clearance continues to exclude whole warehouse footprints.

Run42875849582 observed exact100kg delivery/return and7kg partial-can refuelling
at1x in349.001explicit simulated seconds, including explicit DEBUG office/fuel
setup. Its manifest identifies the source overlay. Run42875874141 at1223931
observed the configured native3D entry, open portal, floor and camera ceiling.
The reused shelf-smoke recording stages an existing worker at the preparation
point; actual worker travel is evidenced separately by the domain conversion
receipt. Neither result proves full-game60FPS or Dawson's player acceptance.

Run42876605327 repeats only the affected utility/fuel episode after final
claim-release deduplication and source-wait cleanup; all16assertions pass and
its retained manifest matches all25current changed production scripts exactly.
