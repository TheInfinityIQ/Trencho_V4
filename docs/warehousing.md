# Physical Supply Depot warehouse

Current implementation belongs to `codex/materials-warehouse-loop`, based on
`1d7ae006e123861c6138ac0ec2ee0cfdd967acea`. It is not yet the human checkout's
playable default. [Accepted design](supply_depot_warehouse_design.md),
[pre-code plans](feature_plans/warehouse_v9.json) and the
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

## Remaining delivery work

- Verify the actual imported models, default F5 scene, native entrance/collision,
  lighting, joined appearance and reused smoke in Godot on GitHub.
- Retain engine-generated UID/import sidecars and finish exact-head review before
  publishing/adopting a playable default.
- Implement the separately diagrammed ordinary return/reload and finite staging
  recovery. Neither exists merely because its design is recorded.
- Implement genuine paired timber custody/handling; current legacy single-person
  receipt is not acceptance of the requested two-worker timber transport.
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
