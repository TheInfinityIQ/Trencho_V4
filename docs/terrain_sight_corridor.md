# Bounded sight corridor certificate

31 October 2026. Engineering optimization for the existing `TerrainWorld.probe`
semantics; no changes to authored terrain, vegetation, role ranges or observation
cadence. Lead authorized this isolated candidate for remote validation and profiling.

## Eligibility and work bound

The private `_probe_corridor_clear` helper accepts only the canonical production
script, an empty explicit `cells` dictionary, and at most 256 current base regions.
Derived scripts retain their virtual traversal and lookup behavior. It builds no
ray, candidate array, dictionary snapshot or persistent index/cache. Every call
re-reads current raw regions; revision numbers are not a validity certificate.

Require finite start/finish, native differences, and computed Vector2/Vector3 lerp
endpoints. Compute the integer corridor from the **Vector2** lerp endpoints and
height clearance from the separate **Vector3** lerp endpoints. The height lower
bound must be strictly positive. Integer origins, positive sizes and exclusive
ends must fit signed 32-bit storage before constructing the corridor Rect2i.

Each base region must have an ordinary positive Rect2i with nonoverflowing ends.
Unknown, malformed, fractional, empty, negative and wrapped areas reject the
certificate. For every region intersecting the conservative cell corridor, its
tile must be a Dictionary without `height`, `gradient`, `overlay` or
`vegetation_height` keys. Even valid zero-valued/custom fields reject it. Unsafe
shadowed tiles reject it too; no precedence resolution is needed when every
possible winner is independently safe. The unrestricted TR01 default has these
same absent-key defaults. Any explicit cell triggers immediate fallback.

## Numeric and packet proof

Pinned Godot standard build `ed1daf0bf` implements both
[Vector2 lerp](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/vector2.h#L255-L259)
and [Vector3 lerp](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/vector3.h#L253-L259)
by applying [Math lerp](https://github.com/godotengine/godot/blob/ed1daf0bf/core/math/math_funcs.h#L315-L320)
componentwise. Each component computes `from + (to-from)*weight` in `real_t`.
For a fixed finite rounded difference, multiplication by a weight in [0,1] is
monotone (decreasing for a negative difference); rounding and adding a fixed
finite value preserve that order. Contracting the multiply/add preserves
monotonicity too. Finite differences and endpoint values exclude overflow/NaN
holes. Bounds use the actual computed endpoints, not an assumption that lerp at
weight 1 equals the supplied target. For example, native float32 interpolation
from 33554432 to 1 at weight 1 yields 0; a target of 3 instead yields 4.

The original `ray_cells` accepts additional cuts only strictly within [0,1],
then sorts them. Consecutive-cut midpoints and their native weight conversions
stay within that interval. Every computed Vector2 midpoint therefore lies within
the computed endpoint bounds, and its floored cell is inside the inclusive
integer corridor. Actual endpoint cells are included conservatively too. This
also covers negative coordinates, grid edges, zero length, duplicate cuts and
near-EPS cuts without reproducing or changing the ray traversal.

For every possible raw tile, the absent keys mean base 0, gradient Vector2.ZERO,
no overlay and vegetation top 0. All computed xyz components are finite. Zero
gradient dot products are zero, and the computed z lower bound is strictly
positive, so the original low/high are positive. Each original segment would
reach `minf(low,high) >= top` and continue before canopy, surface cost, metres,
budget or contributing segments. Terrain labels do not supply implicit heights.

The original obstacle loop runs first without changes. A positive certificate
skips only ray/candidate/tile/body work and reaches the original common packet
finalizer. Existing opaque stop/reason/blocker/tie priority, block point/distance,
distance/range, budget 0 and empty segments are preserved exactly. Failure runs
the original traversal/body unchanged, including budget breaks and final terrain
block-cell lookup. No new errors or coercions are introduced for uncertain data.
Internal lookup calls are intentionally absent on certified paths; derived
lookups and all fallback traces retain their original ordering.

## Scenario fit and verification boundary

Source-derived Farmland authoring has 143 base regions and no explicit cells:
65 background/broad/stepped regions, 14 crop regions and 64 subsequent regions.
Authored tiles use terrain plus cover-group/road metadata, so their current probe
height/gradient/vegetation defaults are zero even for forest/crop terrain labels.
Initial defences update shields/effects rather than explicit terrain cells.
Runtime construction/restore/mutation must still pass fresh guards or fall back.

The regression addition uses actual production World objects against the complete
retained independent LegacySightWorld. It covers full probe/observe packet bytes,
clear/opaque ties, ordinary/drone/muzzle behavior, cancellation, zero/grid rays,
touching and overlapping areas, region cap, malformed helper inputs, explicit
overrides, and same-world mutations. Derived instrumentation and custom lookup
cases retain the fallback. Huge-coordinate/invalid-input guard cases call only
the bounded helper, avoiding huge ray allocation or intentional legacy errors.

No local engine/import/tests/profiling are authorized for this contribution.
Static text comparisons verify the retained legacy oracle, original obstacle
prefix, common finalizer and fallback body (apart from one enclosing indentation)
remain unchanged. Engine assertions, integrated checks and speed benefit require
remote validation on the exact candidate; source review is not performance or
gameplay acceptance evidence.
