# Current-change verification

Effective 31 October 2026. Dawson directed the team to stop writing regression tests and running tests until the main game is complete, except to check that the actual code just written works. This overrides earlier regression, suite, oracle-matrix, failure-injection and broad-observation instructions.

- Build the main game first. Do not create or extend regression coverage, comprehensive matrices or testing frameworks.
- Use only a short direct check of the new or changed action when needed. Do not rerun old gameplay scenarios, stress, profiling or suites unless they directly demonstrate that current code change. Renaming a regression does not change its scope.
- Keep existing tests and the old workflow source for later. Do not delete tests or weaken gameplay rules to avoid verification.
- Keep the human computer protected. No local engine/native run is allowed under the active resource restriction; necessary heavier direct checks run briefly on GitHub.
- Record what changed, exactly what was exercised, the result and what remains unknown. Do not imply full-game or responsiveness acceptance from syntax checking.

## GitHub

The required `validate` job checks the update's changed production GDScript for syntax. A first PR publication uses its base/head merge-base so all local commits in the proposed game-loop block are included. A later synchronize/push uses the previous head when supplied, so a metadata-only update after an already checked source does not unnecessarily reparse the whole PR. A non-PR event without a previous head falls back to the head's parent. Dependencies and declared assets may be imported/parsed, but no regression runner is invoked. Updates whose selected range contains only documentation/workflow changes do not download or launch Godot.

The retained GDUnit4 suites are paused; neither local unit tests nor a full remote suite run automatically. One playable game-loop block is the normal PR boundary, with local checkpoint commits before its first push. Only the current block's necessary brief demonstrations are dispatched; repeated checking requires an affected change, a failure or an unresolved concern.

The optional `direct_check` manual input supplies one brief Godot script for the actual change. It is written only into ignored CI output and has a 45-second process deadline; it is not a committed regression fixture. Use it only for a concrete changed behavior, not an old suite or broad scenario. The direct check must exit nonzero when the changed action fails and must describe what it exercised. No direct demonstration runs automatically.

The former full workflow is preserved at `.github/deferred_validation.yml`, outside the active workflows directory. The old `tools/check.ps1` and regression files remain in the repository but are not part of current execution. Broad testing stays deferred until the main game is complete or Dawson changes the instruction.

Game Designer owns observable gameplay and experience; Lead and Principle Engineer own technical design and implementation. Technical suggestions do not create additional designer approval gates. Existing physical conservation, real supply, hierarchy and scope still apply.
