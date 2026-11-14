# Supplier road ownership

Frozen before implementation: Receiving retains its existing activity clock and
physical truck identities. A composed SupplierRoad chooses a bounded straight
route or one south passing lane; it introduces no global navigation framework.
Material stop(132,200), personnel stop(100,200), passing centreY212. Queue and
spawn spacing is30m, leaving room for a truck-length turning approach. Different
service kinds can use their own stops concurrently; each kind keeps one berth.

Planning uses conservative4.3m body circles for moving vehicles and actual
protected rear work rectangles for stopped vehicles. Candidate motion is checked
against the time-overlap of every existing supplier segment, so a crossing route
cannot be accepted merely because its destination is clear. The conservative
circle includes the asymmetric crew root-to-rear extentZ3.98 and modest body sway on turns. Explicit external body updates
come from actual manager pose and owned-vehicle movement; they do not query
inventory or scan entities each rendered frame. An intrusion stops a route at
the last committed safe position; no pushing or teleporting the player.
Owned-hull obstacle radius includes its own canonical footprint diagonal;
the larger military vehicles are not assumed to have the supplier dimensions.

Blocked activities retain their exact destination and berth. They retry on
actual state/obstacle changes, never a one-second retry loop. Held vehicles have
no motion, wheel distance or travel fuel consumption. Supplier fuel ownership
remains external. Departure begins only after a clear route is committed.

Passing uses26m/32m smooth lateral transitions at4m/s, instead of the original
10m/16m transitions at12m/s. For the12m lane offset, a26m smoothstep transition
has a conservative minimum curvature radius around9.4m; the slower route avoids
an implausible high-speed sideways manoeuvre. Straight supplier road travel
retains12m/s. Temporal reservations use the actual committed route speed.
If an already moving route is obstructed, retain its exact remaining geometry
and speed while held; clearance resumes that route rather than snapping the
chassis into a newly planned turn. Start/brake pitch is a decaying cosmetic
impulse and steering derives from travelled curvature, independent of frame rate.

This is the scoped supplier road, not general vehicle contact recovery. Actual
native presentation, passenger rear clearance and the current-change driving
demonstration remain separate acceptance evidence.
