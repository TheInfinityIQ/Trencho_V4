# D01 measured presentation options

Engineering decision packet, 26 October 2026, for [D01 #42](https://github.com/TheInfinityIQ/Trencho_V4/issues/42). **Recommendation and bounded evidence; production presentation, platforms, hardware and performance targets remain the Game Designer's decision.** Base is accepted main `857675783a21587b41fdbfa6bd1d3cdaae460d00`. G03/G08 remain separate draft/native-gated work; their runtime is neither copied nor changed here.

## Recommendation and comparison

My engineering recommendation is to evaluate **2D overhead with explicit height cues first**, retaining **oblique orthographic 3D** if visible modeled elevation is essential to the art/interaction brief. Management, cargo inspection and route diagnosis favor a stable plan view; this is a judgment about information design, not a measured rendering advantage. Validate Windows first using the available machine if approved; that is a proposed validation order, not a supported-platform or minimum-hardware commitment.

| Decision aspect | 2D overhead with height-aware simulation | Oblique orthographic 3D |
| --- | --- | --- |
| People, trucks, buildings | Ground-plan silhouettes, direction and linked person/cargo inspection; height must be communicated explicitly | Models communicate vehicle/building volume and facing; projected overlap can hide people, cargo and entrances |
| Close inspection → 6 km overview | Stable plan coordinates; zoom-dependent markers/labels must replace subpixel objects without changing their real footprint | Same need for overview markers; camera angle, roofs and tall props introduce picking/occlusion work |
| Ridge, slope, bridge | Contours, slope arrows, explicit bridge deck/ground distinction and sight-line probes need deliberate visual language | Visible mesh height can explain ridge/deck separation, but self-occlusion and selecting the correct crossing level need validation |
| Art/content effort | Consistent silhouettes, directional states and height transitions; possible sprite variants and sorting work | Meshes/materials/animation plus terrain transitions, occlusion treatment and label anchoring; reuse across angles is a potential benefit |
| Engineering risks | Visual height cues may disagree with actual support/sight; stacked passages need explicit semantics | Visual mesh/collision/query data can disagree; camera/picking/label and near/far precision need tests |
| What to measure | Selection accuracy, blocked-cause comprehension, label density, draw cost and transitions at agreed zoom/text scales | Same interaction measures plus occlusion, camera/picking stability, mesh/detail and GPU/VRAM cost |

Both approaches can preserve the full metre-scale simulation. Godot provides [TileMapLayer drawing groups](https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilemaps.html) and [orthographic Camera3D projection](https://docs.godotengine.org/en/4.7/classes/class_camera3d.html), whose apparent size does not vary with depth. Those are viable prototype tools, not evidence that either handles this complete world. Any instancing experiment must account for [MultiMesh's whole-object visibility rather than individual-instance culling](https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html); that guide warns its 4.7 update is incomplete. No rendering/streaming framework is selected. [Large-world precision guidance](https://docs.godotengine.org/en/4.7/tutorials/physics/large_world_coordinates.html) also leaves actual close-view stability at map edges to verification, not this array probe.

### Scale calculation, not a rendered prototype

For illustration, assume **720 vertical pixels available to the map**, with no UI deduction. This is an upper-bound geometric example, not an approved resolution, zoom range or screenshot. A 6,000 m overview has 0.12 px/m; a 60 m close view has 12 px/m. An oblique camera additionally foreshortens the ground axes.

| Reference geometry | Full 6 km overview | Illustrative 60 m close view |
| --- | ---: | ---: |
| 1 m person reference square | 0.12 px per edge | 12 px per edge |
| Actual T02 footprint, 6.8 × 2.5 m | 0.816 × 0.300 px | 81.6 × 30 px |
| Actual F04 footprint, 16 × 12 m | 1.92 × 1.44 px | 192 × 144 px |

The person square comes from [D02's validator reference](d02_cover_fairness.md), not an invented runtime person hitbox/art width. GDD specifies standing eye at ground+1.7 m and real individual identity; native art/picking dimensions still need approval and observation. GDD9/8 supply the actual truck/building dimensions. At overview, geometry alone cannot make an individual truck or person legible: linked markers, selection disambiguation and truthful quantities are necessary in either approach. Marker size must not enlarge physical occupancy or grant enemy knowledge. At close view, test distinct actual people, goods, crew and entrances; a table-only fixture does not implement the outstanding playable logistics area.

## Bounded full-size data/query evidence

Plan/acceptance: reuse the existing allocation evidence; allocate all 4,000 × 6,000 one-metre cells; verify actual contents/bounds, repeat deterministic queries and memory observations; retain entry behavior/checks and publish limits. This is one small calibration probe, not a generator, accepted map or production storage decision.

The earlier ignored 25 October `d01_storage_probe.gd`, its JSON, log and recommendation were inspected before new work. It allocated/fill-checked uniform terrain/height/flag arrays three times: 48.232/51.396/52.606 ms allocation/fill, engine static delta 144,000,192 bytes. It did not check nonzero height contents or queries, record RAM/OS build, or measure process residency. The new [feature-local probe](../game/world_probe/full_size_probe.gd) reuses that three-field layout and adds checks/query evidence. The old artifacts remain preserved; these different workloads are not a performance before/after comparison or optimization claim.

**What actually allocates:** 24,000,000 terrain bytes + 24,000,000 float32 heights (96,000,000 bytes) + 24,000,000 flag bytes = **144,000,000 bytes / 137.329 MiB raw payload**. Arrays are resized and filled, not sparse placeholders. A further 200,000 int32 query indices use 800,000 raw bytes. Engine/script overhead is additional.

Default data is TR01 byte 1, height 0, flags 0. Twelve disjoint authored 64 × 64 squares carry TR02–TR13 bytes, exact plateau heights 2–24 m, and flags 1/2/4. Their starts are `(50+900*((k-1)%4),100+1800*floor((k-1)/4))`, k 1–12. The remaining 23,950,848 cells stay default. These isolated calibration plateaux do not satisfy terrain-generation, slope, ford, props, HQ, route or fairness rules.

Each run performs 94 sanity checks: full per-value terrain/height/flag counts, world corners and row stride, patch inside/outside boundaries, rejected negative/outside coordinates without wrapping, deliberate one-field corruption detection/restoration, and actual query checksum versus an independent rectangle oracle. The 200,000-query workload uses fixed LCG seed `0x13579bdf`; 25% deliberately hit patches, 75% select full-extent indices. Oracle/workload preparation is timed **separately** from indexed array reads/checksum. This measures this synthetic access pattern, not navigation, sight integration or AI throughput. All three fresh-process runs returned checksum **805938108** and 94 checks/zero failures.

### Measured machine and repeated observations

Steam standard/tools Godot `4.7.2.stable.steam.ed1daf0bf`, `--headless`, Windows 11 Home 10.0.26200 / build 26200, Intel Core i7-13700F, 16 GiB installed RAM (OS-reported physical 15.758 GiB), NVIDIA GeForce RTX 4070 Ti, driver 32.0.16.2101. The GPU is not exercised by this probe. This available desktop is **not approved reference/minimum hardware**. Background desktop apps were running; no controlled load isolation, release-build calibration or statistical population claim is made.

After an initial instrumentation trial (retained separately), the final runner measured one empty-script baseline and three fresh full-probe processes in order:

| Run | Allocate/fill ms | Paint ms | Full content/sanity ms | Workload/oracle build ms | 200k indexed reads/checksum ms | Observed peak working set MiB | Sampled max private MiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 50.295 | 2.333 | 202.772 | 411.563 | 53.051 | 237.996 | 178.980 |
| 2 | 51.562 | 2.197 | 205.555 | 429.573 | 53.519 | 238.168 | 179.023 |
| 3 | 50.824 | 2.285 | 209.686 | 412.248 | 54.597 | 237.801 | 178.680 |

Median allocation/fill 50.824 ms; median indexed queries 53.519 ms. These are stage observations, not generation/load/frame-time budgets. Empty-script process baseline observed peak working set 100.840 MiB and sampled private 41.316 MiB. All three payload-phase engine static deltas were **144,000,096 bytes**. These are different memory instruments, not interchangeable totals: [Godot static counters](https://docs.godotengine.org/en/stable/classes/class_os.html#class-os-method-get-static-memory-usage) work in debug builds; [.NET peak working set](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.peakworkingset64) reports the process lifetime physical-memory peak, and [private memory](https://learn.microsoft.com/en-us/dotnet/api/system.diagnostics.process.privatememorysize64) records nonshared allocation. The runner samples at 10 ms intervals and retains the largest observed values. An empty baseline is a separate process, so subtracting it is only a rough context comparison, not an exact per-field process delta. GPU memory is unmeasured.

The narrow result: on this machine, this complete 144 MB calibration payload allocates, its checked bounds/values survive, and its synthetic queries repeat. This supports continuing full-size feasibility work without shrinking the map. It establishes **no** GPU frame rate, usable native visuals, agreed hardware pass, final 384-person battle performance, world generation/load/save time, complete memory budget, production architecture or A17/A50/A55 acceptance. Actual roads/props/structures, occupancy, route data, knowledge, simulation and visuals would add memory/work absent here.

## Reproduce and verification

From the repository root in PowerShell 7 on Windows:

```powershell
./game/world_probe/run_probe.ps1 -GodotPath '<Godot 4.7.2 executable>'
```

The runner starts hidden **headless** processes, reads sanitized CPU/RAM/GPU/OS fields, records an empty baseline plus three full trials and validates agreement. Raw JSON/logs are ignored under `.artifacts/d01/`; no large binary/map data is committed. Source and commands, not a serialized world, reproduce the data.

On any supported test host, run the probe directly with the pinned engine:

```text
godot --headless --path . --script res://game/world_probe/full_size_probe.gd
```

`./tools/check.ps1` keeps the accepted import, G01/G02/UI and main-scene startup checks and adds this same probe's correctness run, with **no timing/memory performance threshold**. Local Steam 4.7.2 passed import/startup and **1,750 checks**: G01 624, G02 842 / UI 190, probe 94; no engine/script errors. This validates data behavior and retained entry behavior, not native interaction. Current-head CI is reported separately on the PR.

The probe owns only its temporary arrays/workload and writes measurements; it touches no authoritative people, goods, clock or accepted engagement. A failed probe reports errors/exits; rerunning initializes new calibration data. It implements no save/restore. G32 still owns persistence of an actual accepted world, IDs and state; reconstructing this calibration pattern is not restoring an engagement. G03/G08 evidence and the human root checkout remain untouched.

## Concrete decisions still needed

1. **Presentation and art/interaction brief:** choose the preferred direction to test, and whether oblique modeled elevation/roofs are essential or explicit plan-view height cues are acceptable. Approve close-selection/overview expectations before an art pipeline is committed.
2. **Supported platforms and reference/minimum hardware:** select desktop OS coverage, named CPU/GPU/RAM/VRAM reference configurations, resolutions/window conditions and UI scaling. Current Windows observations make no Linux/macOS or low-end support promise. GDD 150% text and pause/1x/2x remain requirements.
3. **Measured acceptance budgets:** agree frame-time/hitch, input-to-inspection latency, generation/load-to-paused-inspection, total process/GPU memory and simulation-backlog limits with a repeatable workload. This packet supplies evidence, not invented pass/fail FPS/load/RAM targets.

After a working native condition and focused authorization, compare both approaches on the same declared people/truck/building and ridge/bridge scenes, same camera path and metric scale; inspect selections/blocked causes at close and full 6 km overview and 150% text. Later use accepted full-size Lake District/Highland Passes and all four validated family fallbacks with actual initial forces, then both armies' governed limits, 1x/2x/pause/view changes and representative supplies/observation/combat. Record frame-time distributions/hitches, selection/readability failures, process/VRAM peaks, generation/rejection/fallback and save/load separately. Those later measurements are unverified. The current SendInput 122 condition has not changed; no native game-input attempt, new native game session or offscreen/headless image is presented as native proof.

The Designer records the reviewed production decision/rationale and downstream references before D01 is resolved. D02/D03 definitions are accepted but downstream evidence remains; D01/M1 and A17/A50/A55 remain open. This packet neither implements the visible rear-base logistics area nor releases G04 gameplay.
