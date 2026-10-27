# D01 overhead presentation evaluation

Related [D01 issue 42 assignment](https://github.com/TheInfinityIQ/Trencho_V4/issues/42#issuecomment-6429738909). The human chose clear 2D overhead with explicit height cues for the first evaluation, and Windows first for later native validation. This implements only that limited evaluation on accepted main `d3e2d69`; it does not select a production renderer or establish hardware/performance targets.

## Sample and presentation

Open the optional `game/overhead_evaluation/overhead_evaluation.tscn` scene. It is not the main entry. The authored sample has a full 4,000 × 6,000 m coordinate extent; only three friendly reference objects and sparse terrain/crossing shapes are drawn. Their physical coordinates, dimensions and declared supplies are fixed across Close (12 px/m), Intermediate (1 px/m) and 6 km overview(fit to full extent).

- `sample-person-01`:1×1m square from D02's validator reference. This is not a production person hitbox, art width or node from an army simulation.
- `sample-t02-01`: GDD9 T02 footprint6.8×2.5m, declared at(1017,3010)m carrying100M01.
- `sample-f04-01`: GDD8 F04 footprint16×12m, declared at(1000,3000)m. These sample positions do not relocate an authoritative rear base.

Ground+2m, bridge deck+8m/6m separation, ridge+12m and a10m rise over50m(11.3°) are explicit authored demonstration assumptions. The2D line/plan cues and inspection key communicate levels without implementing G08 height/sight/pathfinding, bridge construction or layered navigation. The river/crossing outline has no gameplay permission or transport capability. Grid and scale bars use metres. Overview badges, leaders and selection outlines are screen-space aids, separate from the real footprint rectangles; no enemies exist or become known by zooming. Stable identity/coordinates/supply appear in the linked inspection.

The prototype uses one Control to draw the sample instead of a node per tile or a general rendering framework. It has no per-frame simulation loop, generated terrain, forces, production, movement or persistence. No unmerged G03/G08 runtime is imported.

## Reproduce and inspect

The default check remains headless and explicitly excludes display-input/render evidence:

```powershell
./tools/check.ps1 -GodotPath '<Godot 4.7.2 standard executable>'
```

On Linux with an existing Xvfb/X display, after that setup/import:

```powershell
$env:EVALUATION_HEAD = (git rev-parse HEAD).Trim()
xvfb-run -a pwsh -NoProfile -File ./tools/run_gdunit4.ps1 -GodotPath '<godot>' -Suite Input
```

CI executes the retained G02 input pilot and the new named evaluation case, uses the exact submitted SHA for metadata and retains the existing deliberately-failing/restored G02 control. The generic named-case runner is reused from bounded-reviewed PR54 head `1c7d56c`; its G03 cases/runtime are not dependencies. Missing or skipped required cases fail the runner.

The new test clicks the T02 footprint via actual SceneRunner mouse input, then clicks view and100% / 150% text controls. It asserts stable selected identity and physical data, full-overview bounds and a nonblank rendered viewport. After processed frames and `RenderingServer.frame_post_draw`, Godot exports six 1600 × 1000 PNGs under `.artifacts/d01-overhead/`: `close_100`, `intermediate_100`, `overview_100`, and the corresponding `_150` files. `views.json` records SHA, engine, image/pixel hash, camera centre/px-per-metre, canvas rectangle, selection, text scale, exact sample positions/dimensions/supplies and authored heights for each image. Generated images and reports are CI artifacts, not committed source or native screenshots. Individual CI pixel hashes are provenance, not a promise of cross-driver bit identity.

## Evaluation limits

The source and metadata provide an auditable comparison of scale, labels, selection linkage and authored height cues. The Designer reviews the actual rendered artifacts and their corresponding metadata. Sparse samples cannot establish dense-label readability, selection accuracy with crowds, animation/art quality, battlefield visibility, full-map population/simulation performance or input latency. These are Linux software-rendered CI images, not Windows native screenshots or benchmarks. Windows native behavior/readability and minimum/reference hardware, renderer/art pipeline, FPS/loading/RAM/VRAM budgets and D01 closure remain unresolved. No manual QA is assigned to the human.

The first six genuine CI images were visually inspected. They exposed leader lines crossing wider-view text and crowding near the selected truck at150% text; callouts were moved outside their leader paths, and the close slope cue gained a directional rise arrow with+2/+12m endpoints. The final PR links regenerated images for inspection rather than relabelling the initial captures. This is a sparse layout evaluation, not a conclusion about dense gameplay readability.

The added visible-control bounds check caught a four-pixel container overflow at150% text with a selected sample. Reducing the outer row spacing from14px to12px keeps the complete layout within1600×1000; the regression checks every visible Control in all six views.
