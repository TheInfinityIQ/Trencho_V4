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
