# Developer onboarding

Effective 30 October 2026. Previous scoped assignments and archived-chat reporting routes are superseded by [team_workflow.md](team_workflow.md).
Read AGENTS.md, [design brief](design_brief.md), [playable delivery](playable_delivery.md), [handoff](team_handoff.md), then relevant GDD/foundation sections.

Baseline main ecac1f16dc77f81191aa30f1d32fd9fad0015046 contains PRs #77, #80, #81 and #82. Root is deliberately stale with a human project.godot edit: never reset, stash or overwrite it. Use your own isolated checkout from current main.

Lead assigns work under [#83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83), owns engineering and merges. Designer owns intended behavior. Historical tasks do not automatically resume.
First work is a bounded playable/diagnostic/missing-connections inventory, then the shortest runnable increment. Reuse existing identity, clock, dispatch, organization, combat and other services. Do not rebuild the project.
Before shared changes, identify state owner, transitions, affected callers and meaningful interaction coverage. Holder/seat, work commitment and movement must agree. Damage resolves once; motion respects interruptions.

Use ./tools/check.ps1 with pinned Godot 4.7.2 and current verification policy. Report actual interaction and unverified behavior. Headless startup alone is insufficient.
Report readiness/blockers to lead and material gameplay ambiguity to designer with a recommendation. Continue independent work where possible and leave a compact factual handoff.
