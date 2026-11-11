# AI-assisted 3D asset workflow

Updated 10 November 2026 under Dawson's explicit request in Workflow Master
chat `01a1b3e9-a21c-7e62-855a-8d369f305b83`, human turn
`01a1c6f0-38b2-79f3-93b7-54aabbd090c5`, verified by Lead readback.
This supersedes external-mesh-foundation guidance for new assets under this
workflow; preserve prior approved concepts and delivered work, not a restart.

The 9 November workflow was authorized after the
equipped faceted soldier's four-view T-pose concept was generated. This document
guides art production; it does not change gameplay, integrated assets or the
Lead's engineering ownership. Follow [team ownership](team_workflow.md), the
[design brief](design_brief.md) and [current verification policy](current_change_verification.md).

## Current asset sequence

Scoped resumption, 10 November: in Lead chat
`01a199a0-f08e-7f23-947f-62655a9ed233`, turn
`01a1c6fc-6bab-7db2-af11-a090b04ffabb`, Dawson explicitly answered
“Resume animations for these vehicles” to the materials-truck unloading and
troop-transport passenger-exit question. New authoring for those two supplier
vehicles is authorized. Other animation authoring remains paused; references to
the earlier blanket pause below are superseded only within this scope.


Later timber resumption: Dawson selected **Resume with that carrying layout**
for existing2m planks,50kg maximum bundle and roughly1.3m worker separation.
This lifts the narrower item-hauling pause for this supplier/warehouse task.
Reuse the existing synchronized bend; no new pickup/bend clip. Artist fits
actual arm/hand contacts, validates reachable separate shelf revisions and
provides a full normal-speed video before human appearance approval.

[Process diagram](diagrams/asset_reference_workflow.mmd).

1. **Artist asks Lead first:** supply the new asset's purpose, accepted dimensions
   and fit, moving parts, delivery stage and faceted style references. Lead resolves
   engineering details; ask Designer only about material gameplay/style
   contradictions. This adds no routine Dawson approval gate.
2. **Faceted 2D concept before external 3D search:** coherent front/back/left/right
   views, a useful three-quarter view, and top/bottom where shape requires them.
   Keep equipment/proportions consistent and accepted dimensions distinct from
   image estimates. Resolve contradictory views before modeling. Reuse compliant
   approved concepts; do not reset already delivered work to repeat these steps.
3. **Artist invokes the on-demand Luna scout:** pass the accepted brief, coherent
   concept and existing project reference pointers. Scout inspects project
   references first, then one bounded external search for up to 3-5 viewing
   references. It returns source URLs/known creators, visual and functional fit,
   useful views, mismatches and unknowns, or one honest no-good-match result.
   No repeated search loops or topology/rig claims based on thumbnails.
4. **Viewing references only:** do not filter by licence or perform licensing
   research for this shortlist. Never download asset/paid files, purchase,
   import, re-sculpt, trace, modify/retexture a candidate mesh, or incorporate its
   geometry/textures. Source identification is still retained. This is not
   permission to use an unlicensed asset in the game.
5. **Artist selects useful references and authors the original model** from the
   accepted brief/concept. Search need not produce a match and never blocks
   original modeling. Historical permission to use an external character base
   is not permission to adopt a new third-party mesh in this workflow.
6. **Proportionate existing QA/export:** retain editable source and the intended
   export, measured dimensions, orientation/pivot, scoped actual checks, readiness
   and limits. Keep concept/static/animated/integrated claims separate. The two
   supplier vehicles have the explicit scoped resumption recorded above;
   other animation authoring stays paused.
7. **Lead integrates:** use existing permitted current-change checks and required
   exact-head Designer review. No local engine, broader test campaign, new
   controller or routine human approval is introduced.

## Scout configuration and dispatch

Project role: `.codex/agents/asset_scout.toml`, name `asset_scout`, permanently
`gpt-6-luna`. Effort is deliberately not pinned in the TOML. On a real accepted
task use **High** for reference search, **Low** for exact catalogue lookup.
The Artist selects references; the scout does not model, edit files or integrate.

Current host exposes explicit spawn model/effort controls but no custom-role
selector, so automatic TOML discovery is unverified. The supported alternative
is to read this role's `developer_instructions`, then call the existing
`spawn_agent(task_name="asset_scout", model="gpt-6-luna",
reasoning_effort="high", fork_turns="none", message=...)`, substituting `low`
only for a narrow catalogue lookup. Pass the instructions, accepted brief,
concept views/pointers and bounded result contract in the message. This is an
explicit new Luna scout, never an inherited Sol parent or a model change to an
existing role. If the host cannot run explicit Luna, report that limit; do not
silently substitute another model. No actual scout invocation/search occurred
in this configuration turn. No standing sidebar chat, job or controller is added.

The [official custom-agent schema](https://learn.chatgpt.com/docs/agent-configuration/subagents#custom-agents)
documents project TOML roles and configuration precedence. Our host's exposed
spawn schema supplies the explicit model/effort fallback. Configuration presence
and successful TOML parsing do not prove runtime loading or search quality.
For fixed-model reasoning choices see [team workflow](team_workflow.md).

## Local tools and resource envelope

- Dawson reports 12 GB of GPU VRAM. Blender installed through Steam is the
  established modeling route; start it through Steam when authorized work needs
  the application. The earlier soldier records Blender 5.2.3 LTS, not a live
  environment check for every later task.
- Continue using Blender operations driven by small scripts, editable source
  files and actual Blender renders. Community instructions assist execution;
  their example budgets and automatic recipes are not proof of asset quality.
- No local neural image-to-3D generator is required or installed by this change.
  Do not make the workflow depend on a model requiring more VRAM than available.
  This does not imply that all 3D generators require more than 12 GB.
- Inspect one asset at a time. Prefer a modest EEVEE preview, initially around
  768-1024 pixels, before expensive rendering. Use final-resolution images only
  when the current art decision needs them. These are working defaults, not
  measured hardware limits or a performance guarantee.
- Affinity is optional for palette sheets, decals and texture cleanup. Confirm
  its connection when actually needed; do not treat the installed instructions
  as evidence of a currently working application connection.

The existing restriction on local engine/native runs remains in force. This
document grants no new launch permission, background worker, benchmarking task
or automatic retry loop. Preserve the human editor and unrelated applications.

## Historical foundation guidance — 9 November, superseded for new assets

The following records earlier external-base advice and provenance. It is not
the current acquisition/modeling sequence. Existing delivered assets and their
licence records remain preserved; new references obey the viewing-only rule above.

For people, first inspect the project's existing licensed character and source
record in [opening assets](3d_opening_assets.json). Assess proportions, neutral
pose, joint topology, skeleton, materials and reuse restrictions for the actual
new task. Its presence or an old idle observation does not prove suitability for
this soldier or additional animation.

If it is unsuitable, build one original reusable neutral-pose body or inspect a
specific permissively licensed base. Record the exact source, edition, files,
license and modifications before using an external asset. Do not acquire several
overlapping character libraries by default. Quaternius and MakeHuman are
candidates from the research, not selected or newly verified dependencies.

For props and modular environments, direct parametric construction is a useful
default when dimensions and repeated components dominate. Use high-to-low baking
only where the required surface detail justifies it. Neural meshes, if later
introduced, are candidate source geometry requiring inspection and preparation.

## Retained modeling, QA and export details

1. **Preconditions:** complete the Lead brief, coherent concept and bounded scout
   sequence above. Include actual viewing distance and attachments; distinguish
   proposed/image measurements from accepted dimensions. Do not add gameplay needs.
2. **Body or functional blockout:** establish silhouette and proportions before
   equipment/detail. A deforming human starts in a consistent neutral A/T pose,
   rather than a weapon-holding presentation pose. Keep working geometry editable.
3. **Inspect and correct:** render the actual current mesh from front, left, back
   and right at a common orthographic scale, plus a useful three-quarter view.
   Inspect silhouette and material appearance; inspect wireframe when geometry
   changes. Address the specific visible problem and retain a recoverable prior
   version. Do not repeatedly rebuild a whole asset to fix one local feature.
4. **Equipment and surfaces:** keep meaningful moving/replaceable parts separate.
   Check hands, straps, clearances and equipment contacts. Share materials where
   appropriate. Vertex colors are valid for a faceted asset; UVs are required
   when the chosen texture/baking work needs them, not merely to satisfy a generic
   checklist. Keep supported PBR arrangements or explicitly bake/recreate effects.
5. **Character movement, when requested:** establish a clean deforming hierarchy,
   suitable joint geometry, intentional weights and attachment transforms. Use
   the Blender control rig for authoring and export a deliberately prepared
   skeleton/animation. Automatic retopology and weighting are starting operations,
   not completion evidence. Inspect the particular bends and short clip needed
   for this increment before expanding the animation library. The Lead owns the
   movement/root-motion interface and game integration.
6. **Publish:** save editable source and export only the intended collection or
   objects. Exclude studio lights, cameras, reference images and duplicate source
   meshes. Use a repeatable Godot glTF/GLB configuration; do not copy a Unity or
   Unreal skeleton preset from a generic recipe without adaptation. Record
   dimensions, exported triangles/vertices, material surfaces, texture resources,
   skins and clips as applicable. Flat shading can increase exported vertex count.
7. **Direct handoff check:** inspect the exported current asset, use format
   validation when applicable, and have the Lead arrange only the permitted
   brief current-change engine demonstration. Record what was actually observed.
   No regression suites, broad pose matrices, crowds, profiling or FPS campaign
   are introduced by this workflow.

Generated turnaround art is a design reference, not a geometric specification.
Check inconsistent views, ambiguous attachment sides and hidden construction
before modeling. Later views rendered from one Blender mesh are the definitive
geometric turnaround. Neither generated concept images nor source-mesh checks
establish exported appearance or deformation.

For a faceted character, use deliberate planar surfaces and shading. Joining
closed segments into one object does not weld a deforming body. Do not rely on
disconnected elbows/shoulders to define the style, or blindly decimate an
animation-friendly base to achieve a low triangle count. Likewise, open surfaces,
intentional UV overlaps and rigid equipment are evaluated according to purpose;
they are not universally defects.

## Delivery language and evidence

| Stage | What it establishes | What remains separate |
| --- | --- | --- |
| Concept reference | Intended appearance and equipment | Actual mesh, dimensions, rig, export |
| Static asset | Saved model, scoped geometry/material review, inspected static export | Deformation and animation |
| Animated asset | Scoped rig/weights/clip evidence in the actual export | Game integration and runtime behavior |
| Integrated asset | The Lead's specific observation in the current game build | Unexercised behavior and performance targets |

For each delivered increment, record source/export paths, provenance, measurements,
actual checks, accepted warnings and unverified behavior. A file merely existing,
a recipe finishing or a pleasing studio render is insufficient for a later-stage
claim. Do not report universal polygon budgets or performance savings without
appropriate evidence. Preserve the previous soldier as a static style prototype.

The active next character specification is the
[faceted soldier brief](art/faceted_soldier/brief.md). This update prepares that
work; it does not claim a new body, rig, animation or integrated replacement.

## Animation approval videos —10 November correction

An approval video must visibly show the actual action, not merely contain the
right number of frames or moving animation channels. Use a fixed camera that
clearly frames the body, hands and relevant prop; disclose any staged cutaway.
Show the complete action at1x. For short loops, show several complete cycles.
Decode and visually inspect quarter, middle and three-quarter phases of EACH
action in the final encoded file. Set the intended frame rate BEFORE animation
import, or map the actual imported frame span to the source clip seconds; an
encoded30fps label does not establish normal-speed action sampling. Loop endpoints/holds can be identical and
are not evidence of movement. Camera orbit, turntable motion, changing titles
or render noise do not establish an animated action. Label static model reviews
as static. The Lead inspects the actual delivered mid-cycle frames before
sharing a video for human approval; appearance approval remains the human's.

Driver video v01 is rejected: its wide cab/windscreen framing obscures the
small motion, and the original sampled frames were endpoints/holds. Preserve
the original assets; Artist is producing a versioned visible-motion correction
within the two resumed supplier vehicles. This does not resume unrelated clips.

## Research supporting these choices

- [Blender Python API](https://docs.blender.org/api/current/info_quickstart.html):
  programmatic scene, mesh, material and animation access.
- [BlenderAlchemy, ECCV 2024](https://arxiv.org/html/2404.17672v3): visually guided
  editing and retaining/reverting candidates; evidence for iteration on its
  studied tasks, not proof of unattended game-character completion.
- [Blender Studio's Blender/Godot workflow](https://studio.blender.org/blog/our-workflow-with-blender-and-godot/):
  deliberate collection exports and separation of working/published data; its
  custom pipeline is project-specific, not a required installation.
- [DOGWALK rigging retrospective](https://studio.blender.org/blog/character-rigging-for-project-dogwalk/):
  hierarchy, attachment and scale issues encountered in a real game production.
- [Blender glTF manual](https://docs.blender.org/manual/en/5.2/addons/scene_gltf2.html)
  and [Godot import documentation](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html):
  exported geometry/material behavior and supported interchange.
- [Godot retargeting](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html):
  bone names alone do not establish animation compatibility.
- [Khronos glTF Validator](https://github.com/KhronosGroup/glTF-Validator): format
  checks complement, rather than replace, visual and functional inspection.

These primary sources were researched in this art chat. The process choices
above are project-local applications of that evidence, not claimed universal
studio rules. No new tool service or asset package was installed.
