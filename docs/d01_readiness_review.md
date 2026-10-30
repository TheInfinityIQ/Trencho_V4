# D01 presentation and full-map readiness review

Engineering recommendation for [D01 #42](https://github.com/TheInfinityIQ/Trencho_V4/issues/42), 30 October 2026. The Game Designer and human retain the production decision. This review uses accepted G20 source `7d450ad3f56c51b2cf9af15c8aa2705c1dd7b062`, the existing [2D evaluation](d01_overhead_evaluation.md), and the existing [full-size data probe](d01_measured_options.md). The human selected clear 2D overhead with explicit height cues for evaluation and Windows first. Neither selection approves a production renderer, art pipeline, hardware floor or performance budget.

## Recommendation for decision

Proceed with **2D overhead, explicit height and crossing-level cues** as the proposed production direction, subject to native readability and dense full-world measurements below. Keep physical world positions, occupancy, knowledge and selection identity independent from screen-space badges. Use the authored evaluation's ground/deck/ridge key as a visual language to test, not as an assertion that sight, roads or bridge traversal work. The earlier [2D versus oblique 3D comparison](d01_measured_options.md#recommendation-and-comparison) explains the art, occlusion, picking and height tradeoffs. This is an engineering judgment: no renderer throughput comparison has been measured.

The optional scene `game/overhead_evaluation/overhead_evaluation.tscn` is a sparse authored sample inside the fixed 4,000 × 6,000 m extent. Its person is D02's 1 × 1 m validator reference, not final art or a person hitbox; T02 is the GDD's 6.8 × 2.5 m footprint and F04 is 16 × 12 m. The same IDs, positions, dimensions and declared 100 M01 on the T02 persist through close, intermediate and full 6 km overview, with 100% and 150% text. Ground +2 m, deck +8 m, 6 m crossing separation, ridge +12 m and the 10 m/50 m slope are declared illustration data. Overview badges are fixed-size visual aids and grant no new enemy knowledge. The [engine-input test](../game/overhead_evaluation/tests/overhead_input_test.gd) clicks the T02 and view/text controls, checks physical snapshots and selection after each transition, bounds visible controls, and captures actual rendered frames with metadata. These samples cannot demonstrate dense crowds, all 384 people, final terrain or GPU frame rates.

## Repeatable observations on the available Windows machine

The current machine is Windows 11 Home build 26200, Intel Core i7-13700F, 16 GiB installed RAM, NVIDIA GeForce RTX 4070 Ti (driver 32.0.16.2101), and Godot 4.7.2 stable Steam tools. These are hardware descriptors, not a reference/minimum specification or private machine identifier. Background applications were uncontrolled. `game/world_probe/run_probe.ps1` started one empty baseline and three fresh headless Godot processes. Each allocated 24,000,000 one-metre cells in three packed fields: 24 MB terrain, 96 MB float32 height, 24 MB flags, for 144 MB raw payload. Twelve distinct 64 × 64 plateaux checked actual non-default values. All three runs passed 94 content, boundary, corruption-detection and independent-oracle checks and 200,000 indexed queries with checksum `805938108`. The baseline's lifetime peak working set was 89.87 MiB; it is a separate process, so subtraction is only context, not an exact allocation delta.

| Trial | Allocate/fill | Query | Peak working set | Sampled max private |
| --- | ---: | ---: | ---: | ---: |
| 1 | 59.462 ms | 75.679 ms | 227.24 MiB | 178.98 MiB |
| 2 | 57.214 ms | 62.951 ms | 227.34 MiB | 179.09 MiB |
| 3 | 52.182 ms | 68.872 ms | 227.79 MiB | 179.52 MiB |

Each engine static payload delta was 144,000,096 bytes. The median allocation/fill was 57.214 ms and median query workload 68.872 ms; the query workload is a synthetic mix of 25% authored patch hits and 75% seeded full-extent indices. The separate oracle/workload build and whole-content verification are not included in the query number. These observations establish that this machine can hold and query this calibration payload. They do not measure a generated or validated map, render frames, GPU/VRAM use, save/load, live route/sight/AI work, or the final 384-person battle. No target hardware pass is claimed.

## Proposed acceptance contract for Designer and human review

All numbers in this table are **proposals, not approved targets or measured passes**. The available Windows machine above is a proposed *reference test machine only*. The minimum machine, supported Windows versions, renderer/backend and art density still require an explicit choice. Hold the full 4,000 × 6,000 m extent in every test; do not solve a budget by reducing the world or ranges.

| Area | Proposed threshold on the reference machine | Reproducible measurement needed |
| --- | --- | --- |
| Readability and input | At 1600 × 1000 and both 100%/150% text, all visible controls fit; a selected person/T02/F04, actual quantity, ground/deck level and blocked cause remain legible at close, intermediate and 6 km overview. 95th percentile input-to-updated-inspection ≤ 100 ms. | Native Windows OS pointer/keyboard and physical display review, including crowded selections and zoom; log input and inspection timestamps. |
| Running view | At 1× and 2× with full accepted initial forces and a representative 384-person battle, 95th percentile frame time ≤ 16.7 ms and 99th ≤ 33.3 ms during a ten-minute camera/inspection route; no frame > 100 ms. | Godot profiler/frame traces at close, intermediate and overview, with moving forces, routes, knowledge and active logistics. Record CPU/GPU separately. |
| Startup/load | From launching a validated full-size seed or restoring a saved battle to a responsive paused inspection ≤ 15 s at the 95th percentile of five cold starts. | Time complete generation/rejection/fallback and load/restore separately; retain seed and exact build. A calibration array fill is not this workload. |
| Memory | Peak process working set ≤ 4 GiB and dedicated GPU memory ≤ 2 GiB during the same ten-minute scenario, including zoom and load transition. | OS process peak plus graphics API/driver VRAM telemetry; record background load and hardware. |

These are deliberately testable starting values, not deductions from the CPU/data probe. Designer/human should confirm or revise the reference and minimum hardware, resolution, text conditions, scenario/seed, percentile windows and thresholds before they become gates. If the proposed 60-frame/s reference target is too costly for the intended content, change it explicitly rather than silently trimming the 6 km world or removing physical reports.

## Gates and ownership

The [recorded supported Windows click](game_design_document.md#235-g03-foundation-verification-path---26-october-2026) failed `SendInput 0/1`, error 122, on clean revision `1c7d56c`; its capture remained at t0. There is no verified supported-tool recovery. Godot SceneRunner input and Godot-rendered viewport exports exercise engine input and renderer, **not Windows OS input or native readability**. Do not mark the Windows-first M0/D01 milestone gate passed until a supported OS input path works and native review is recorded. No unsupported injection workaround or repeated unchanged attempt is part of this packet.

D01's remaining decision is the production presentation, Windows coverage and reference/minimum hardware, and measurable accepted thresholds. G09/G10/G11 must still build and validate the generated world and four full-size fallbacks; A17/A50/A55 remain live acceptance cases. G32 owns exact save/restore of the actual world, seed, identities, cargo, knowledge, progression and fixed choices. This authored scene and synthetic probe have no authoritative people, commitments, event clock or save format; rebuilding them is not restoring a battle. The Designer records any approved D01 decision with rationale before closing #42 or releasing G09's production presentation.
