# Representative Farmland and Towns layout

`game/battlefield/farmland_scenario.gd` supplies the recorded layout for delivery#83. `apply(world)` installs a4,000×6,000 metre base on the existing TerrainWorld; explicit cell mutations remain authoritative above the authored regions. This is one authored representative layout, not completion of the four-family procedural generator or GDD15.4 acceptance.

The layout exports the six Resource, two Route Hub and central Observation sites from GDD15.1. HQ centres remain(2000,400)/(2000,5600). The lead owns their ledger registration and army setup. Dry320m square half-extents cover each300m safe-start circle. Two heavy-access north/south roads atx1000/3000 provide separated central corridors; their junctions widen for turns. Roads never substitute unsupported water/swamp crossings.

`waypoints()` exports service berths at centre+(0,50), troop staging toward the centre at y620/5380, dismount stops at y2300/3700, nearby delivery stops, and service/staging/front polylines. Berth routes bypass the24×24m HQ footprint eastward. Runtime drivers must execute actual turns and revalidate current obstacles; these polylines do not authorize teleportation or ignore damage. The lead owns transport and command consumers.

BattlefieldView draws these authoritative terrain regions and physical town-shell obstacles. House/barn garrison and destruction services are absent; the static opaque shells are a declared early-map limitation and do not establish full GDD14.4 town gameplay. Armour/infantry access, observation and natural terrain cover still use the existing terrain service.

The focused map regression counts exact areas across all rectangle edges, checks dominant budgets and road proportion, dry anchors/safe starts, class support and obstacle clearance along authored lanes, actual road speed/fuel, pond/forest restrictions, town opacity and runtime override precedence. Render probes capture1280×720 overview and central zoom. These checks do not establish a complete generated-world fairness report or an observed engagement.
