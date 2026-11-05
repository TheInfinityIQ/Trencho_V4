# Developer onboarding

Updated 5 November 2026. Read AGENTS.md, [design brief](design_brief.md), [GDD](game_design_document.md), [playable delivery](playable_delivery.md), [team workflow](team_workflow.md) and [current integration state](team_integration_state.json).

The Developer owns systems, technical decisions, testing, integration and publication. The Game Designer owns vision and player-facing requirements. Consult UI/UX for interaction/menu flow and the Artist for sourced assets. Historical team rosters and assignments do not reactivate automatically.

Work from the dedicated published review source and exact revision identified by the current Developer. `main` alone may be older. Inspect and preserve unrelated local changes; do not reset, clean, stash or switch the shared checkout to solve a task. Coordinate ownership before editing shared files.

The current outcomes are the ordinary self-sustaining factory, first useful automatic army supply and repeat replenishment. Build on existing services and identify the actual missing connection. A catalogue entry or a passing standalone component is not the connected outcome.

Use [agent workflow](agent_workflow.md) for a bounded objective and current AGENTS.md for planned diagrams, applicable engineering lessons, living-map queries/purpose reviews and UI-flow maintenance. The Designer specifies the intended behaviour rather than the architecture or test framework.

Gameplay features take priority. Polishing, optimization and benchmark-driven work are paused; keep known defects and performance limits visible. Use brief direct checks of changed behaviour when needed, without routine full suites or new coverage infrastructure. Routine checks must not take desktop focus or move the OS cursor. Fix state corruption and defects that block the current gameplay increment.

Publish authorized work to the dedicated review branch and hand back Objective, Outcome and Next task, exact branch/commit, checks and honest limits. Only the Developer integrates and manages the current review PR; a published commit is not gameplay acceptance.
