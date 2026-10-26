# D02 cover fairness and route independence

Game Designer decision v0.1, 26 October 2026, applying to GDD v0.2 and its governing planning amendment. Authority: [adopted decision on D02 #43](https://github.com/TheInfinityIQ/Trencho_V4/issues/43#issuecomment-6410873350). Sections 1–4 and 6 record that contract; sections 5 and 6.1 make its reference examples reproducible. Numerical choices are concrete proposed balance defaults for explicit later revision and playtesting, not unapproved alternatives from the earlier engineering proposal.

D02 remains open until this canonical document and its worked fixtures are accepted and merged. [G10 #18](https://github.com/TheInfinityIQ/Trencho_V4/issues/18) must implement final-world validation and demonstrate A17/A18 afterward. No runtime collision, formation spacing, generator, storage architecture, presentation or performance decision is introduced.

## 1. What is being measured

Apply this check separately to ALL nine capture objectives in GDD 15.1: six Resource Objectives, two Route Hubs and the Observation Objective. At every objective, each army's approach side needs at least eight usable protected infantry places. If the capacities are A and B, both must be at least 8 and:

`(max(A,B) - min(A,B)) / min(A,B) <= 0.25`

The boundary is inclusive. Zero or a missing approach is a failure, never a balanced 0/0. Report minimum-capacity failure separately from percentage failure. Do not average objectives or allow good cover elsewhere to compensate for a failed objective. Positions may serve more than one nearby objective if valid for each, but report that sharing; those counts are not additive independent army capacity.

This is potential protected occupancy on the initial map. It is not a prediction of combat power or a guarantee that every occupant fires at the same target simultaneously. Runtime weapon range, friendly-fire withholding, formation spacing, occupancy and knowledge rules remain unchanged. Do not spawn imaginary occupants as new LOS blockers during the static reference measurement.

## 2. Approach sides and test directions

Use the completed initial world after final props, terrain, roads, garrisons and mandatory crossings. For each HQ, identify its fastest legal ordinary-infantry route to the objective using actual terrain/slope speeds. The local approach anchor is that route's last inward crossing of the 160 m horizontal circle around the objective before reaching it. For equal-time routes, compare the incoming vector from that anchor toward O with the direct vector from its own HQ toward O. Prefer the smallest unsigned angular difference in the range 0 to 180 degrees, wrapping across bearing zero; then choose lowest world x, then lowest world y. This specifies a reproducible result while leaving route-finding implementation to the engineer.

The two anchors must be distinct and support legal infantry approach. If their reference 1 m footprints overlap, or an anchor/route cannot be established, reject the approach pair rather than invent a facing. Let n be the UNIT vector from the northern-HQ anchor toward the southern-HQ anchor, n=(A_S-A_N)/distance(A_N,A_S); define u=(n.y,-n.x), so the north/south reference case uses map-east for u. The divider passes through the objective centre O, perpendicular to n. Negative projection on n is the northern-HQ side; positive is the southern-HQ side. A reference place whose footprint straddles or touches the divider is excluded, so it cannot belong to both sides. This follows actual local approaches, rather than assuming every forest or rock faces map-south.

The static contest probes are O and the four corners O plus/minus 5 m along u and n. Threat probes are O and O plus/minus 20 m along u. These lie inside the existing 25 m capture radius. Target reference height is local ground plus 1.7 m. Use an ordinary standing observer eye at local ground plus 1.7 m and W01 rifle muzzle at local ground plus 1.5 m. The fixture uses ordinary 220 m sight and 160 m rifle range, without binoculars, an observation-objective bonus, drones or transient smoke. These reference rays introduce no damage or headshot rule. A capture marker is an annotation, not hypothetical cover or an opaque obstruction in this reference measurement. Actual buildings, terrain and props remain in the final geometry. If the centre probe is not a legal standing contest position, reject or reposition the objective within its existing placement constraints rather than ignore that real obstruction.

## 3. When a place qualifies

A qualifying place must satisfy every following condition:

- Its centre is within 150 m horizontal distance of O and its whole reference footprint is on exactly one approach side.
- A reference 1 x 1 m horizontal occupancy square, aligned to the world metre grid, has legal physical support and clearance. An outdoor square cannot overlap a trunk, opaque solid prop, impassable footprint, deep water or forbidden slope in its interior. A garrison uses its declared interior person place and entry/window rules below, not the exterior building traversal mask. Boundary contact alone is not interior overlap. These are validator reference dimensions; they do not change runtime infantry collision or formation dimensions.
- It can be reached from its side's actual approach anchor and has a legal route back out under the initial infantry access rules. Do not assume an unbuilt bridge, destroyed prop or future engineer action. Shared entrances are reported as an access limitation; they do not multiply capacity.
- Against EACH of the three threat probes, either real opaque cover geometry blocks the incoming direct line, or the strongest valid direct-hit cover multiplier is at most 0.65. Use each incoming ray from probe ground plus 1.5 m to reference-place ground plus 1.7 m; out-of-range status alone is not protection. Account for physical shielding direction and height. No stacking. Light forest qualifies at 0.65 if otherwise usable; dense forest/rock cover 0.50 and rubble 0.60 can qualify; crop 0.80/farm 0.85 cannot. Raised roads and exposed bridge decks do not qualify. Blast protection is not an additional requirement of this metric.
- The centre AND at least two of the four contest corners have valid ordinary sight and valid W01 firing lines from the reference eye/muzzle. Use the same selected probes for both checks. Existing terrain height, opaque geometry, vegetation budget 100 and actual ranges apply. Seeing around a wall through a one-point keyhole is insufficient.

A rock only counts from the directions it actually protects. A usable building window must also be exposed to valid return fire with the normal garrison cover rule; an opaque room is not a protected firing place merely because it has an occupancy number.

## 4. Repeatable outdoor counting and garrisons

Use world metre-cell centres as outdoor reference locations: `(i+0.5,j+0.5)` for integer tile coordinates. Test four 2 m sampling phases, given by the even/odd parity of i and j. In each phase, candidate centres are at least 2 m apart. Check each candidate's 1 m square and the rules above. For each side, take the LARGEST qualifying outdoor count among the four phases; do not combine candidates from different phases into one inflated count. Each side may select its own best phase. Record all four counts and the chosen phase; tied phases are reported in fixed order even/even, even/odd, odd/even, odd/odd.

This is a conservative, reproducible reference capacity at the game's metre resolution, not continuous optimal packing or an instruction to place infantry on a grid. Testing all four phases avoids choosing only a favourable grid parity. Changing physical geometry, including fractional prop placement, can change the count and must be rechecked. Integer translation and quarter-turn calibration fixtures should preserve counts when the entire geometry/anchors are transformed consistently.

Garrisons contribute separately through their actual declared person places, rather than sampling their opaque footprint as outdoor ground. A counted garrison place must identify a distinct simultaneously occupiable 1 m reference square, a usable firing window and arc, legal entry/exit, and the same protection/view/range tests. Two declared places cannot use overlapping reference interiors. Multiple windows available to one person place still count as ONE place. Count no more than the building's declared 8 house or 12 barn places, and never invent a firing slot for an interior occupant without a usable window. Each declared place belongs to at most one approach side. The 2 m outdoor sampling interval does not create extra garrison slots or impose a new indoor formation rule.

For each side, capacity is its chosen outdoor-phase count plus qualifying declared garrison places. Outdoor reference interiors cannot overlap building/garrison interiors. A physical place is counted once even if terrain and structure both offer cover. Report outdoor and garrison subtotals, strongest-cover categories, exclusions and the combined result. Equal counts are the defined minimum opportunity test, not proof that a forest and a bunker have identical combat strength.

## 5. Reproducible cover calibrations

These synthetic local fixtures exercise the reference measurement, not production terrain appearance or executed gameplay. Metres use world x/east, y/south and ground z=0. The reference centre and approach anchors are O=(2000,3000), A_N=(2000,2840), A_S=(2000,3160). Legal initial ordinary-infantry approach/exit routes establish those anchors. Thus n=(0,1), u=(1,0).

Contest probe order is C0=O, C1=(1995,2995), C2=(2005,2995), C3=(1995,3005), C4=(2005,3005). Threat order is T−=(1980,3000), T0=O, T+=(2020,3000). All targets are ground+1.7m; outgoing eye/muzzle are +1.7/+1.5m; incoming threat muzzle is +1.5m. No hypothetical occupants obstruct these rays.

### 5.1 Outdoor phases, boundaries and transforms

For A, place isolated 1×1m TR05 patches at x=1992.5,1994.5,1996.5,1998.5,2000.5,2002.5,2004.5,2006.5 on both y=2920.5 (N1…N8) and y=3079.5 (S1…S8). Each patch fills its one reference square [x−0.5,x+0.5]×[y−0.5,y+0.5]; all other ground is TR01. Only those whole protected interiors qualify. Ground is flat, routes/clearance legal, and there are no opaque props, garrisons or other obstructions. TR05 supplies multiplier 0.65 against all three threats, not an opaque trunk; the short foliage intersection spends less than 100 sight budget. C0…C4 sight/fire rays are clear.

Phase vectors below are **[even/even, even/odd, odd/even, odd/odd]** for integer cell coordinates i=x−0.5, j=y−0.5. Every garrison subtotal is 0. Choose the maximum per side, never the sum.

| Fixture / exact change from A | North phases | South phases | Chosen outdoor N/S | Difference | Minimum / final |
| --- | --- | --- | --- | --- | --- |
| A: sixteen listed patches | [8,0,0,0] | [0,8,0,0] | 8/8 | 0% | Both≥8: PASS |
| B: S6,S7,S8 patches become TR01 | [8,0,0,0] | [0,5,0,0] | 8/5 | 3/5=60% | South<8 and ratio fail: FAIL |
| C: add north x=2008.5,2010.5 at y=2920.5 | [10,0,0,0] | [0,8,0,0] | 10/8 | 2/8=25% | Both≥8, inclusive boundary: PASS |
| D: C plus north x=2012.5 at y=2920.5 | [11,0,0,0] | [0,8,0,0] | 11/8 | 3/8=37.5% | Minimum passes, ratio fails: FAIL |
| E: opaque trunk interior overlaps N1 square, bounds x[1992.25,1992.75],y[2920.25,2920.75],z[0,3] | [7,0,0,0] | [0,8,0,0] | 7/8 | 1/7≈14.29% | Ratio passes, north<8: FAIL |
| F1: all north patches become TR01 | [0,0,0,0] | [0,8,0,0] | 0/8 | Undefined; no division | Minimum fails: FAIL |
| F2: all sixteen patches become TR01 | [0,0,0,0] | [0,0,0,0] | 0/0 | Undefined; no division | Minimum fails: FAIL |

A's maximum centre distance is sqrt(79.5²+7.5²)=79.852989925m; maximum contest-probe distance is sqrt(84.5²+12.5²)=85.419552797m. C/D maxima are centre 80.190398428/80.476704704m and probe 85.909836457/86.293105171m respectively. The original <80m/<86m bounds describe A; every extended fixture remains within 150m centre,220m sight and160m rifle limits.

| Consistent transform of A, including patches, ground, objective, anchors and probe basis | North phases | South phases | Capacity N/S |
| --- | --- | --- | --- |
| Integer translation +(1,1) | [0,0,0,8] | [0,0,8,0] | 8/8 |
| Quarter turn about O: (x,y)→(2000−(y−3000),3000+(x−2000)) | [0,0,8,0] | [8,0,0,0] | 8/8 |

Those transforms permute phases while preserving the result. A phase tie uses the stated fixed order; counts from different phases are not mixed.

### 5.2 Eight-place house, four qualifying firing places

Separate local calibration H uses the same O, anchors and probes, with no outdoor TR05 patches. A house occupies x[1996,2004],y[2917,2923], an 8×6m footprint with 8 declared places. Its interior ground is z=0; opaque boundary walls and an interior partition at y=2920 extend z[0,3]. North/south entrance openings and the partition doorway use x[1999.5,2000.5],z[0,2.2], at y=2917/2923/2920 respectively. They provide legal access/exit to both rooms via the central aisle. Windows below are apertures in the south wall y=2923, all with height z[1.4,2.0] and arcs covering the three threat and five contest probes through their openings. Roof/other opaque geometry does not intercept these horizontal/slightly rising reference rays.

Every listed place has its explicit square [x−0.5,x+0.5]×[y−0.5,y+0.5], with edges parallel to the world axes; interiors do not overlap. These are declared indoor places, not outdoor parity candidates. The exterior building traversal mask is not used to discard declared interior places.

| Place | Centre (x,y) | Square x bounds / y bounds | Declared candidate windows | C0…C4 paired sight+fire | Result |
| --- | --- | --- | --- | --- | --- |
| H1 | (1997,2922) | [1996.5,1997.5] / [2921.5,2922.5] | W1a and W1b | All five | Count1 |
| H2 | (1999,2922) | [1998.5,1999.5] / [2921.5,2922.5] | W2 | All five | Count1 |
| H3 | (2001,2922) | [2000.5,2001.5] / [2921.5,2922.5] | W3 | All five | Count1 |
| H4 | (2003,2922) | [2002.5,2003.5] / [2921.5,2922.5] | W4 | All five | Count1 |
| H5 | (1997,2918) | [1996.5,1997.5] / [2917.5,2918.5] | W1a/W1b, blocked by partition | None | Count0 |
| H6 | (1999,2918) | [1998.5,1999.5] / [2917.5,2918.5] | W2, blocked by partition | None | Count0 |
| H7 | (2001,2918) | [2000.5,2001.5] / [2917.5,2918.5] | W3, blocked by partition | None | Count0 |
| H8 | (2003,2918) | [2002.5,2003.5] / [2917.5,2918.5] | W4, blocked by partition | None | Count0 |

Window x intervals: W1a[1996.65,1997.0], W1b[1997.0,1997.35], W2[1998.65,1999.35], W3[2000.65,2001.35], W4[2002.65,2003.35]. H1's C0/C2/C4 rays use W1b; C1/C3 use W1a. Both apertures serve the same H1 place: five apertures give **four** qualifying people places, not five. H1 has centre plus two corners through W1b alone as well. H5–H8 cannot reuse those windows through the opaque partition.

Reproduction: for a ray from P to Q, at wall/partition coordinate y_w evaluate t=(y_w−P_y)/(Q_y−P_y), x_w=P_x+t(Q_x−P_x), z_w=P_z+t(Q_z−P_z). Check doorway/window intervals at each crossing. H1–H4's incoming lines from all three threats also pass through apertures, exposing the place to valid return fire; house cover 0.40 meets the protection threshold. H5–H8's opaque protection cannot compensate for absent centre/corner view. Legal doorway access remains available despite that sight obstruction.

All eight squares lie strictly on the north side and within 150m, with legal support/access and no overlap. Outdoor counts are [0,0,0,0] on both sides: outside TR01 is unprotected; the full-height house walls block reverse and outgoing sight/fire together outside the apertures. Garrison subtotals are N=4,S=0; combined 4/0 fails the minimum and avoids ratio division. H is a counting calibration, not a complete balanced objective. Adding any outdoor cover later requires measuring its phases with the final house present.

### 5.3 Direction, shielding, range and rejection controls

Use the same anchors/probe basis; other initial support/access is legal unless explicitly changed. These are individual qualification controls, not additional accepted whole objectives.

| Control / exact input | Observable reference result |
| --- | --- |
| Unit-basis control: anchors (1904,2872),(2128,3096), both 160m from O | n=(1/√2,1/√2),u=(1/√2,−1/√2); use these unit axes for 5m/20m probes. Do not multiply offsets by the unnormalised(224,224) vector. |
| Angular tie calibration | Relative angles use min(d,360°−d): direct bearing 359°, incoming 1° differs 2°, incoming 180° differs 179°. Equal angles then use world x, then y as specified; no clockwise-wrap preference. |
| Divider contact: square centred(2000.5,2999.5) in north/south case | Its y interval touches 3000: exclude. A centre on the north side alone is insufficient. |
| Direction failure at P=(2000.5,2920.5): no opaque shielding; valid multipliers(T−,T0,T+)=(.50,.50,1.0) | Reject: one threat remains unprotected. Reorienting the real cover so all three are .50 passes the protection subtest; the other qualification tests remain required. |
| Positive opaque-height control: TR01 at P=(2000.5,2920.5), opaque beam x[1999,2002],y[2924.45,2924.55],z[1.68,1.695], supports outside reference routes/rays | All incoming threat rays intersect it at z 1.689811…1.690063; outgoing eye rays are 1.7 and muzzle rays≈1.510, clearing it. With the other stated conditions this place qualifies through real opaque shielding. This synthetic beam only calibrates the specified ray heights. |
| Opaque-view rejection: replace that beam by a solid wall with same x/y extent and z[0,3] | Incoming shielding still exists, but centre sight/fire is blocked: reject. Protection alone does not imply a useful place. |
| Range/protection control: TR01 at P=(1850.5,2998.5), no opaque shelter | Centre 149.507524894m is within 150m, but T+ is169.506637038m away. That threat being beyond W01 range is not protection; multiplier1 still rejects the place. |
| Outside radius/range: P=(2000.5,2838.5) | More than150m from O and more than 160m from centre target: reject both violated tests. With a valid centre≤150m, every corner distance is≤150+5√2=157.071067812m; these defaults do not permit an isolated ordinary W01 corner-range failure inside the eligible disk. |
| Access/slope: one A patch is reachable only across deep water without an initial crossing, or its support slope is 41° | Exclude that place; future engineering cannot make it initially usable. A legal 20° infantry slope merely changes approach travel time/sight as applicable, not an automatic exclusion. |
| Final-prop mutation E | The given trunk overlaps N1's reference interior. Recount north 7 even though the terrain is still TR05; boundary contact without interior overlap would not itself remove the place. |
| Invalid centre probe | A solid building/ridge occupies O so it is not a legal standing contest point: reject/reposition the objective within GDD15.1 constraints. Do not omit C0. |

The directional multiplier tuple is a declared subtest input, not a new directional-cover algorithm. Static ray checks add no imaginary occupants. Runtime friendly-fire withholding and actual combat remain unchanged.

## 6. Route independence and endpoint exemptions

Adopt the existing 300 m safe-start circle around EACH HQ as the route-independence endpoint region. Common terminal/apron access is allowed only inside that region. This exemption does not waive dry/buildable safe-start terrain, legal exits, footprints, slopes, turning/tow clearance, bridge class/load or the ordinary gate-to-HQ access test. Each relevant movement class still needs two distinct valid exits across that perimeter and two independent corridors beyond it through the mandatory central crossing/pass regions separated by at least 800 m. There is no requirement for 800 m separation at every point.

The network check concerns those two independent HQ-to-central-contest corridors. It does not newly require two pairwise disjoint routes to every individual resource objective. Convergence for final access inside a particular objective's existing 25 m capture disk is also an endpoint exemption, but cannot excuse a common trunk/junction before that disk or connect both strategic corridors through an exempt disk. Each corridor must already reach its own distinct central crossing/pass region without that shared final approach.

A bridge failure test removes its entire traversable deck/connection. A junction failure test removes the complete physical road-intersection conflict footprint, including shared approaches until they become physically separate class-valid corridors, not just a graph marker. Production validation must report that footprint and surviving connection; splitting one physical intersection into several identifiers cannot turn it into independent roads. This is a connectivity stress test, not a new destructible-road or road-health mechanic. All surviving paths need their actual class, footprint, turn/tow and load clearance after final props. Alternate access must exist initially, without building an alternate bridge first.

Route fixture R1: HQs N=(2000,400), S=(2000,5600). North exits L=(1820,640), R=(2180,640); south exits L=(1820,5360), R=(2180,5360). Each exit lies exactly 300 m from its HQ. Separate legal corridors connect the corresponding exits through crossings L=(1000,3000), R=(3000,3000),2000 m apart. Shared apron stays inside the endpoint circles. Assume final class/load/clearance checks pass. Removing either complete crossing leaves the other connection: independence PASS, without claiming full-map A17/A18.

Route fixture R2: both northern corridors instead pass through one physical 16 x 16 m intersection centred on J=(2000,800), before splitting. J is 400 m from the north HQ and outside every endpoint exemption; removing that whole square blocks both. Independence FAIL despite 2000 m central crossing separation. If the common junction is instead entirely within the 300 m HQ circle (for example a 16 x 16 m square centred at(2000,650)), the common stem is allowed only if there are still two independent class-valid exits and corridors beyond the perimeter.

### 6.1 Explicit route masks and surviving connections

R1 reference corridor centre lines are:
- L: (1820,640)→(1000,2970)→(1000,3030)→(1820,5360).
- R: (2180,640)→(3000,2970)→(3000,3030)→(2180,5360).

The complete8×60m deck masks are L=[996,1004]×[2970,3030] and R=[2996,3004]×[2970,3030]. Their centres are 2000m apart. These masks remove each entire traversable deck, not a centre point. Corridor widths, support, curved turning transitions, load and class validity are declared inputs here, not inferred from these centre lines or demonstrated by this reference calculation.

For R2 insert the entire J square x[1992,2008]×y[792,808] in both north approaches: NL→J→L crossing and NR→J→R crossing, continuing to their corresponding south exits. J is the complete declared conflict footprint in this synthetic fixture; no unlisted bypass exists. A real longer shared approach must be included in its real conflict mask, rather than inheriting this artificial 16m size.

| Removed physical mask | R1 surviving corridors | R2 surviving corridors |
| --- | --- | --- |
| None | L,R | L,R |
| Entire L deck | R | R |
| Entire R deck | L | L |
| Entire J square | L,R (neither intersects J) | None: FAIL |
| Both decks (war outcome, not required single-failure survival) | None | None |

Each HQ exit radius is sqrt(180²+240²)=300m. J's nearest point is 392m from north HQ, outside the exemption. Moving the whole 16×16m square to(2000,650) gives bounds x[1992,2008],y[642,658], farthest corner sqrt(8²+258²)=258.124001209m: the entire common junction fits inside the exemption. It is allowed only with two distinct class-valid exits/corridors beyond 300m.

For objective convergence, use a 25m disk centred on each actual objective. A shared final branch may end inside that disk only after the two strategic corridors have reached their distinct central regions. An unavoidable common junction at O+(0,26) is outside the exemption, and moving only its centre inside while its complete conflict footprint extends out does not exempt the outside bottleneck. An objective disk cannot serve as a shared through-connection joining both strategic corridors. These are connectivity stress masks, not a road destruction/health mechanic.

## 7. Validation record and downstream ownership

Independent reference audit on 26 October 2026 recalculated the four-phase vectors, threshold/zero results, original and extended distances, translated/quarter-turned phase permutations, house ray/window/partition intersections, opaque-height example, range bound, complete bridge/junction mask intersections and HQ radii. A temporary Node.js arithmetic/declared-geometry audit produced 47 passing assertions; its script/output remain ignored under `.artifacts/validate_d02.mjs` and `.artifacts/d02-reference-validation.json` in the D02 worktree. The equations, coordinates and expected outputs above are the durable reproduction specification, without a runtime validator or new dependency. No contradiction with the adopted measurement was found.

Documentation checks resolved seven local links and one local heading anchor, passed `git diff --check`, and compared the pre-amendment GDD baseline unchanged against `origin/main`. Only its 23.2 D02 link and the design-decisions D02 row point to this contract; no competing 23.3 amendment is added. The repository check also passed with Steam Godot 4.7.2: import, retained G01 (14 cases/624 checks) and headless startup, without reported engine/script errors. Reference arithmetic and declared local geometry do not establish an executed full-world terrain result, visual quality, performance, production-map validation or A17/A18 gameplay.

D02 can close only after the Game Designer reviews and merges this canonical documentation PR. G10 still owns actual final-world validation, including all nine objectives, every required movement class, final props and full-size/family acceptance. D01 presentation and D03 population decisions remain separate. G02 PR #51 remains draft/unmerged with native verification pending; this documentation branch contains none of its unmerged implementation.
