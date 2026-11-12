# T03 battlefield presentation handoff

The opening includes friendly T03 technicals. The existing 3D view presents them as generic cubes. This component supplies a provisional 5.2 × 2.1 m stand-in using the existing vehicle footprint; it is not approved art.

```mermaid
flowchart LR
    A[Shared session and player information policy] --> B[Permitted marker rows]
    B --> C[T03 presenter]
    D[Ledger movement and hull events] --> C
    C --> E[Existing marker selection and inspector]
```

Integrated field adapter (Lead review pending): instantiate under the field marker root; bind with the ledger, `world.ground`, and a callable invoking `BattlefieldPresentation.inspect(rear, id)`. Reconcile the same current `Policy.markers` rows after each existing field refresh. Connect `changed` and `removing` using the existing T01 registration pattern; map each anchor into `world.markers` and suppress its generic cube. Existing screen picking and inspector remain the authority. Reconcile also handles admission/removal and parent movement; direct hull events refresh already admitted IDs only. Rebind when replacing the world. No new state or tick is created.

Acceptance: only permitted T03 carriers outside the existing rear cutoff appear, update from current identity position/facing, and disappear on policy removal. Selection retains existing inspection and enemy reports remain reports. Existing T01/T02, people, objectives, camera, 2D fallback and pause are unchanged. The stand-in is non-colliding. Current-change GitHub demonstration and integrated visual review remain required.
