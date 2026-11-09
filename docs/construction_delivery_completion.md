# Construction delivery and completion follow-up

Dawson reported construction goods not reaching the building even with some
workers left in Hauling, and a large completion hitch. The requested presentation
is now1.5seconds of faceted smoke/scissor emergence, then2seconds of cutting.
Tape falls after that3.5second point; later ground-contact pylon cleanup remains.
Actual facility use still starts at real paid construction completion.

[Pre-code plan](feature_plans/construction_delivery_completion_v1.json) and
[integration diagram](diagrams/construction_delivery_completion.mmd) record the
scope. The Game Designer approved builders fetching actual materials for their
own site when unable to build. They retain one assignment and one activity:
pickup/carry/drop/reporting workers do not contribute construction work.
They use the existing25kg foot-haul claims, access/capacity, finite movement and
safe cancellation/reassignment. Builders do not take unrelated haul jobs or
operate utility trucks under another duty. Common haulers retain those roles.

The selected-site menu separates actual haul deliveries, material physically
being carried here and the current handling/blocker. Reservations/uncollected
demand are not delivered materials. These facts are projected only through the
existing menu refresh, not a new polling loop. Missing materials/access remain
real blockers. The unchanged normal live opening starts1x.

## Observed baseline and limits

Two GitHub-only observations at mergedd5100e9 retain the actual distinction:

- 42709239630: four assigned builders left no common haulers; automatic demand
  delivered0/60M11 and earned0/80work by70explicit model seconds.
- 42709920555: with two builders and two common haulers,35/60M11 physically
  arrived and was consumed by70model seconds. The other25was in a real Carry
  phase, with an actual finite route still in progress. That case was not stuck.

The all-builders fallback fixes a real separate usability deadlock; it does not
prove the cause of Dawson's clarified session. No injected site stock or
cancelled automatic demand was used for these delivery observations. A separately
labelled debug completion measured its relevant CPU/render boundary.

The first baseline completed the synchronous command in16.316ms, refreshed
geometry in1.002ms, then took1225.686ms for the next rendered frame, compared
with steady software-rendered frames around81–95ms. This implicates first-use
rendering more strongly than the command alone; it does not isolate a particular
GPU-driver cost or certify native60FPS. The initial hologram draw also had a cold
first-use spike and remains distinct from steady-state/complete-game performance.

## Engineering change

Completed exteriors retain their already rendered reveal material at full height,
with original albedo/texture/vertex colour and roughness/metallic factors. The
unused orange outline pass and ghost are removed; completion no longer swaps to
an unseen StandardMaterial. Work-state/completion events do not rebuild unchanged
reserved geometry. Finite scissors/smoke use zero-alpha submitted meshes while a
site is unfinished so their actual skin/fade variants can render before use.
This targets the measured completion boundary, not a global renderer rewrite.

Godot's [shader-stutter documentation](https://docs.godotengine.org/en/4.7/tutorials/performance/pipeline_compilations.html)
explicitly distinguishes OpenGL Compatibility: low-level precompilation features
for newer renderers do not apply, and first-view drawing is needed for warming.
Source preparation alone is not proof a driver has compiled a variant; the
current-change check must retain observed before/after frame timings and limits.

The Artist's original404-triangle, one-material smoke puff has no emitter,
textures, rig or custom shader. It remains a unit-scale sibling of the3x
scissors. Existing0.4s snip plays at0.2x, giving2.0s cutting and contact at2.5s
overall. Tape release is intentionally later, at3.5s phase end. Existing Pause/
1x/2x scales both the finite tweens and authored clip base rate. Finite tween
references retire with the effect owner; cancellation has no self-capturing
tween callback or completion celebration.

Current-source/runtime receipts and actual captures follow in the feature PR.
No local engine, regression suite, full-loop/native acceptance or60FPS claim.

## Loading boundary refinement

First candidate915d9d5 passed the current-change real-source delivery and finite
sequence check. Completion rendered in90.035ms, matching its88–96ms llvmpipe
steady frames; cold first-site draw still took2160.278ms. That first-use cost
belongs behind loading. A small scene-owned startup cover now draws the actual
construction shader/skin/fade variants once in the real camera before controls
are enabled, using the shared appearance recipe. Read-only geometry is never a
gameplay site, no stock/people or physics are created, temporary nodes clear with
the draw/scene lifetime, and the model pauses only behind this cover, restoring normal1x before input. Headless entry skips
GPU preparation rather than waiting for an unavailable rendered frame.


## Final direct evidence

The [receipt index](evidence/construction_delivery_completion/receipt.json) retains
each exact source/run/digest, including the failed fixed-delay visual probe.
Real-source model cases with four builders and with two builders/common haulers
both physically delivered/consumed60M11, retained440of the original500, completed
80work and passed custody audit. These used explicit model intervals, not normal
wall-clock waiting. No grant or cancelled automatic demand supplied these cases.

The final normal-main observation42717474748 at `afec36f` repeated only the
affected natural office completion: two builders/common haulers, original500M11,
actual60delivered/consumed, complete at98.1explicit model seconds, real utility
truck registered and presented, no debug completion, audit clean. First completion
frame46.860ms matched43–49ms software-rendered steady frames. At the prior head,
this actual truck path had581.934ms first-use latency despite the debug-only
visual check passing. Startup preparation now draws the actual truck too and
retains actual resource references for the scene lifetime. Completion stage CPU
times were2.737ms builder release,2.327ms activation,0.192ms visual event and
0.649ms truck registration. The22.135ms explicit one-second model step includes
other services and is not a normal-frame completion-only cost.

Actual final visual images at `6c79b05` show the loading cover, visible faceted
smoke, cut, fallen tape and cleanup. Native Tween boundaries were approximately
1.517s and3.551s (frame granularity); four authored snips ran at0.2x. Pause/resume
and cleanup passed. Startup model pause prevents unseen loading-time progression;
normal interactive opening remains1x. No local engine was run.

Dawson clarified that haulers never picked up materials. The reproduced baseline
with remaining haulers did deliver, so this exact report is not diagnosed by the
all-builders fix. The menu now distinguishes no accessible source, no unreserved
stock, no idle carrier, actual collection/carry and transport blockers; requesting
already outstanding demand no longer misleadingly implies that goods arrived.
That projection uses the existing selected-menu refresh only. Source inspection
confirms reassignment already releases uncollected pickup claims before reporting.
The next player check is the original site at1x, using its displayed blocker if
pickup still fails. Stages1/2, full-loop, native input and60FPS acceptance stay open.

Godot's [server guidance](https://docs.godotengine.org/en/4.7/tutorials/performance/using_servers.html)
also supports retaining resource lifetime explicitly. This implementation uses
scene-owned high-level resources, not a global cache or manual RID framework.
