# Gameplay delivery roadmap

Updated 5 November 2026. [Vision and rules](game_design_document.md) · [Delivery outcomes](playable_delivery.md) · [Current ownership](team_workflow.md) · [Implementation inventory](implemented_features.json).

## Current source and priority

Current review is [PR #89](https://github.com/TheInfinityIQ/Trencho_V4/pull/89) on [`codex/gameplay-demo-integration`](https://github.com/TheInfinityIQ/Trencho_V4/tree/codex/gameplay-demo-integration). Use the exact published revision supplied by the Developer. Historical PR #86 and its branch preserve earlier work; neither an older PR nor `main` alone identifies the current review source.

[Delivery #83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83) remains the connected-demo parent. Complete these ordinary player outcomes in order:

| Goal | Player-visible outcome | Current status |
| --- | --- | --- |
| [Factory #90](https://github.com/TheInfinityIQ/Trencho_V4/issues/90) | Hire workers, construct and staff facilities, acquire ingredients and manufacture new building materials/military goods with physical automatic handling. | Active implementation; ordinary outcome not yet accepted. |
| [Useful supply #91](https://github.com/TheInfinityIQ/Trencho_V4/issues/91) | Real army need is understandable; player production reaches the recipient through automatic physical delivery and restores applicable capability. | Open; existing services/component results do not establish the whole ordinary path. |
| [Repeat replenishment #92](https://github.com/TheInfinityIQ/Trencho_V4/issues/92) | The same session and returning transport support later genuine need, another shipment and continuing feasible operations. | Open; full repeated causal loop remains unfinished. |

Polishing, optimization and benchmark-driven work are paused. Keep failures, state-corrupting defects, gameplay blockers and the eventual 60 FPS target visible. The Developer owns suitable brief current-change verification. A new benchmark phase or the entire wider catalogue is not a prerequisite to each feature increment.

## Wider game scope retained

The representative full-size authored Farmland scenario is sufficient for the first demo. The following existing milestone issues retain their wider outcomes and remain open until those outcomes are established:

| Milestone | Required playable outcome |
| --- | --- |
| [M0 / #1 — Rear economy and people](https://github.com/TheInfinityIQ/Trencho_V4/issues/1) | Acquisition, construction, manufacturing, training and worker management form a coherent ordinary rear game. |
| [M1 / #2 — Full procedural world](https://github.com/TheInfinityIQ/Trencho_V4/issues/2) | All four full-size map families provide coherent terrain and usable fair access. |
| [M2 / #3 — Operational transport](https://github.com/TheInfinityIQ/Trencho_V4/issues/3) | Real trucks, crew, loading, travel, HQ receipt and local issue connect rear and front through a complete cycle. |
| [M3 / #4 — Autonomous infantry engagement](https://github.com/TheInfinityIQ/Trencho_V4/issues/4) | Delivered orders/reports support sustained contested objectives, income, retreat and physical resupply. |
| [M4 / #5 — Engineering control of routes](https://github.com/TheInfinityIQ/Trencho_V4/issues/5) | Actual engineering and supply allow construction, denial, clearance, rerouting and restored access. |
| [M5 / #6 — Full vehicle combat](https://github.com/TheInfinityIQ/Trencho_V4/issues/6) | All vehicle roles, crews, weapons, support, damage, recovery and supply contribute to feasible operations, including an eligible HQ outcome. |
| [M6 / #7 — Supporting capabilities](https://github.com/TheInfinityIQ/Trencho_V4/issues/7) | Medical evacuation, indirect fire, reconnaissance, field service and enemy logistics work through actual people/equipment/supply. |
| [M7 / #8 — Full run and persistence](https://github.com/TheInfinityIQ/Trencho_V4/issues/8) | Campaign progression, capability access, rewards and complete save/load preserve the whole experience. |

The [C30 child #87](https://github.com/TheInfinityIQ/Trencho_V4/issues/87) keeps its unfinished manufactured-APC outcome. It does not gate the first infantry demo. Existing G01–G33/D01–D03 issue identities and the [project manifest](project_manifest.json) remain traceability references; their original full specification is preserved in the [historical reference](reference/gameplay_specification_v0_2.md).

## Reading status correctly

Closed foundation issues describe their accepted staged scope, not a completed ordinary game or full milestone. Parent child checklists should reflect actual child issue state while leaving unobserved milestone acceptance unchecked. Backend/standalone evidence remains useful but must be labelled honestly.

The Designer owns vision, meaningful choices and observable requisites. The Developer owns systems, testing, integration and the current review PR. Use [team integration state](team_integration_state.json) for current participants; old assignments do not reactivate automatically.

GitHub issues and the Developer's current records carry live status. The [Project #3 board](https://github.com/users/TheInfinityIQ/projects/3) was checked in the browser on 5 November: its description and README now carry these priorities and ownership, #83 and factory #90 are In Progress, and #91–#92 remain in Backlog. Other ready/blocked cards retain their existing status; readiness does not make them the next priority. All eight [GitHub milestones](https://github.com/TheInfinityIQ/Trencho_V4/milestones) remain open. The API sign-in lacks Projects scope; board updates were verified separately in the browser.
