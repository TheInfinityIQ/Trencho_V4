# Connected playable delivery

Updated 5 November 2026. Parent: [#83](https://github.com/TheInfinityIQ/Trencho_V4/issues/83). Current review: [PR #89](https://github.com/TheInfinityIQ/Trencho_V4/pull/89), `codex/gameplay-demo-integration`. Design: [current GDD](game_design_document.md). Developer publication/status: [team integration state](team_integration_state.json), [implemented features](implemented_features.json) and [prototype completion](prototype_completion.json).

## Intended experience

Start in the approved empty field as a controllable character. Buy workers and raw materials, place buildings, allocate jobs and produce useful goods. The Logistics Centre automatically fulfils actual army requests through physical loading, transport and HQ receipt. The autonomous army collects and uses supply, continues feasible resource operations and generates later needs in the same session.

Rear and battlefield keep their applicable work progressing while hidden. Waiting in one area must not silently halt the other. Pause allows inspection and management while stopping timed gameplay. The Developer owns the implementation of that behaviour.

## Next three gameplay outcomes

### 1. Self-sustaining factory — [#90](https://github.com/TheInfinityIQ/Trencho_V4/issues/90)

- From an ordinary new game, hire and receive workers, place facilities and allocate actual labour.
- Purchase ingredients and have eligible haulers supply staffed production automatically.
- Produce new Building Materials for further construction and usable military output.
- Show what changes when workers are reassigned and why input, labour or storage shortages stop work.
- Complete the sequence without diagnostic setup, grants, resets or a manual carry order for every routine load.

### 2. First useful automatic army supply — [#91](https://github.com/TheInfinityIQ/Trencho_V4/issues/91)

- A genuine army need identifies item, quantity, destination, priority and the capability waiting for it.
- The player can choose production and labour to address it; normal freight does not require a manual manifest or Depart command.
- Actual goods pass from the rear through physical loading, transport, HQ unloading, forward delivery and local issue.
- Withheld supply leaves a clear shortage. Received supply permits the recipient to regain the relevant actual capability when its other requirements are met.
- Distinguish newly manufactured supply from starting stock and HQ receipt from actual frontline use.

### 3. Continued operations and repeat replenishment — [#92](https://github.com/TheInfinityIQ/Trencho_V4/issues/92)

- The real transport returns and later genuine need can trigger another newly prepared physical shipment in the same session.
- Troops collect supply and resume their latest feasible acknowledged task; obsolete orders are not restored.
- Real objective capture, contest or loss changes ownership/income. A loss of personnel or capability remains a real limitation and may require replacement or withdrawal.
- Supply does not script a victory, create an enemy wave or bypass combat, route, crew and survival rules.

These are gameplay outcomes, not assertions that their whole ordinary path already works. The Developer maintains actual implementation/verification status and chooses bounded implementation tasks. Existing component results must not close these goals by themselves.

## What this demo does not wait for

The authored full-size Farmland scenario is sufficient. C30 manufacture-to-first-shot, a tank, the complete support roster, every procedural family, campaign and persistence remain wider requirements rather than prerequisites to the first connected demo. The [C30 child #87](https://github.com/TheInfinityIQ/Trencho_V4/issues/87) retains its own unfinished outcome.

The approved rear package and automatic shipping policy stand. Existing battlefield stocks, including 6,000 HQ rifle rounds, are unchanged. Any adjustment to when production becomes necessary is a separate explicit pacing decision with Dawson; do not manufacture urgency by silently removing stock or inventing consumption.

## Ownership and completion reporting

The Designer owns the intended experience, requirements and pacing choices. The Developer owns systems, implementation, testing, integration, the current review PR and a usable handoff. UI/UX owns presentation and interaction design in coordination with both. Historical B/C/Lead/Principle assignments do not activate new work; use the current roster.

Report Objective, Outcome and Next task, with exact published branch/commit and actual checks/limits. Publication is not gameplay acceptance. Keep foundation closure, connected implementation, observed ordinary gameplay and Dawson's feedback distinct.

Polishing, optimization and benchmark-driven work are paused. Keep known defects/performance results and the eventual 60 FPS target visible. Use brief direct checks of changed behaviour when needed; no routine full-suite or new test-infrastructure phase is introduced here. Living-map maintenance and current AGENTS.md still apply.
