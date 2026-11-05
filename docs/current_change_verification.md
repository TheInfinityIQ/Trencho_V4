# Current-change verification

Updated 5 November 2026 under Dawson's current direction. Gameplay and feature
implementation take priority. Polishing, optimization, benchmark campaigns and
routine full-suite runs are paused. Preserve existing tests, known failures and
the eventual 60 FPS target; none is silently removed or reported as passed.

- Diagram each system before implementation, identify ownership/events and
  apply the relevant project lessons. Follow current AGENTS.md.
- Use a brief direct check of actual new or changed behaviour when needed.
  Exercise its meaningful physical result and report its exact scope. Do not
  expand this into unrelated regression, stress, profiling or coverage work.
- Direct local engine checks run headless by default. A minimized native run
  must also avoid desktop focus and OS cursor movement. Use explicit foreground
  input only when a reported issue requires it. The older blanket local-engine
  restriction is superseded by Dawson's later headless/minimized instruction.
- Syntax, handler receipts, source reachability, component stepping and diagrams
  establish different things. Record ordinary-play, native-input and rendering
  limits. A headless functional pass is not 60 FPS certification.
- Fixed worker acceptance remains protected. If a verifier has an unsupported
  assumption, stop its run, diagnose actual state, retain the failure and review
  a new contract. Do not change gameplay rules or performance ceilings to make
  an incorrect check pass.
- Keep required map/purpose/flowchart maintenance current. The manual objective
  controller alone owns worker continuation; the lead owns integration and may
  complete maintenance outside a stopped worker before verification resumes.

## GitHub and publication

The existing required workflow validates source maps/tooling and parses changed
production scripts; it does not run the deferred whole-game GdUnit suites.
Its optional direct demonstration remains scoped to the actual change. Required
repository checks are not disabled to bypass failures. Historical broad checks
remain preserved for later use.

Publish reviewed increments on `codex/gameplay-demo-integration` / PR #89 and
share the exact commit. Report Objective, Outcome and Next task, changed
behaviour, actual evidence and remaining limits. A published commit is not
whole-game or player-experience acceptance.

The Game Designer owns vision and player-facing requirements. The Developer
owns systems, verification, integration and technical policy. Later explicit
human instructions govern when older documents disagree.
