# T04 battlefield presentation

A friendly T04 APC uses the existing permitted carrier identity, shared position and facing, and unchanged inspector. The provisional non-colliding silhouette matches the canonical 7.5 × 3 metre footprint; it is not approved vehicle art.

```mermaid
flowchart LR
    A[Shared session and player information policy] --> B[Permitted carrier rows]
    B --> C[T04 presenter]
    D[Existing ledger events] --> C
    C --> E[Existing marker picking and inspection]
```

The new presenter subclasses the existing T03 presentation lifecycle and changes T04 admission and stand-in geometry; it depends on the revised T03 base inspecting admitted rows for their actual facing before integration. Integrated field-only adapter (Lead review pending): bind it with the ledger, terrain ground callable and existing permitted-inspection callable; reconcile the same carrier rows; register `anchors[id]` on `changed` and erase only the matching anchor on `removing`; skip the generic proxy while represented. Retain the existing selection and inspection path.

Acceptance: a permitted friendly T04 outside the current rear cutoff is selectable, follows its own existing position and facing events, and is removed when no longer permitted. Enemy reports stay reports. No new entity, cargo, order, simulation or clock is created. Parent-only motion triggering reconciliation remains unverified; integrated action, visual review and performance are also unverified.
