# G01 identity and accounting foundation

Scope: [G01 #9](https://github.com/TheInfinityIQ/Trencho_V4/issues/9), M0. Authority: GDD v0.2 sections 3, 4 and 7, with the governing section 23 v0.2.1 staged-acceptance amendment. This patch supplies foundation evidence for A01/A02 and ammunition accounting for A03. The complete incapacitation, dropped-weapon and recovery scenario remains G16.

## Run and inspect

Open `project.godot` with Godot 4.7.2 and press F5. The three tabs expose the accounting scenarios. Reset restores the same fixture identities and quantities; `+2s fixture time` advances the explicit simulation clock, including reservation ages, without performing work. Scroll an inspection panel when its details exceed the available space. Hover any stock row for owner, origin, position, mass and allocation blocker.

The fixture starts with three real person records, ten stock rifles plus one distinct personal rifle, sixty rounds (fifty loose and ten loaded), and five steel. The receiving holder and rear store share one physical handling point. The distant HQ is 2,000 metres away and cannot receive an immediate local transfer.

| Scenario | Reproduction and observable result |
| --- | --- |
| A01 safe handoff | Pick up five steel, then request training. `worker-01` stays in Rear Labour with Training pending and a safe-deposit blocker. Finish safe deposit: the same person becomes Training, the carry/pending fields clear, and all five steel remain at the rear store. No course progress is simulated. |
| A01 interruption | Before safe deposit, cancel the pending request. Current labour and carried goods remain; later deposit does not resurrect the cancelled training request. |
| A02 competing claims | Request ten rifles for A, then ten for B. Source stock stays at ten in the rear store. A reserves ten, B reserves zero, and B's ten unmet rifles and shortage reason remain inspectable. Reverse command order is also supported; this fixture is not a manifest priority scheduler. |
| Delivery and release | Load four using A's claim: the source becomes six and the supplier-owned, player-controlled carrier holds four purchaser-owned rifles (16 kg). Cancel A: cargo stays aboard, six source rifles become free. Retry B: reserve six with four still unmet. Cancellation does not teleport cargo back. |
| Remote location | Try the HQ transfer. The operation explains that physical travel must finish first and leaves stock unchanged. |
| A03 accounting only | In Ammunition, complete the local weapon handoff. `rifle-11` and its ten loaded rounds remain functional and move together to `person-03`; fifty loose rounds stay with `person-02`. Unload, then load ten local rounds: total E02 remains sixty. Loaded stock is actual inventory but is unavailable for loose-stock allocation. Attempting to reserve it explains the required unload. |

Buttons complete scripted accounting boundaries. Real route traversal, handling/reload/handoff durations, course admission/progress, military commitment, combat and casualties are not implemented here. Direct person buttons are review controls, not a change to the game's count-based staffing design.

## State ownership and transitions

`identity_demo.gd` owns one `identity_fixture.gd`, which owns one `identity_ledger.gd`. There is no global singleton. The ledger privately owns typed records from `identity_records.gd`; public inspection returns detached values. The UI refreshes after actions, not every frame. This small fixture model is not a whole-map storage or scheduling architecture.

- One namespace prevents duplicate entity/claim IDs. People retain identity, one holder, and one active assignment. A carrying person's new duty remains pending until a successful safe deposit; cancellation preserves duty and freight.
- Owner and controller are independent fields. Goods do not inherit their carrier's ownership. Supplier ownership is not an additional combat affiliation or a hostility rule.
- Counted goods have one holder. Transferring a stack portion creates a traceable portion ID and reduces its source atomically. Empty source records remain at origin, so unfilled demand does not silently follow the cargo. A durable weapon retains its own ID on transfer.
- Claims preserve source, claimant, purpose, creation time, requested/reserved/fulfilled counts and unmet demand. An explicit retry grants only what is currently available. Releasing a claim never moves stock; a matching physical transfer fulfills it once.
- Loaded rounds are child stock held by the weapon. Totals enumerate stock once, rather than adding an independent loaded counter. Unloading puts existing rounds at the weapon's current holder; the former operator retains only their own remaining loose rounds.
- Creation records the introduced count. Explicit consumption/loss records a count and cause. Physical stock plus consumed plus lost equals introduced stock for each type. These are accounting primitives, not manufacturing or combat behavior. Existing claims and carried/loaded commitments must be resolved by their owning activity before removal; no casualty reservation-arbitration policy is introduced.
- Commands validate before mutation and return a specific result/reason. Invalid operations leave all records and events unchanged. The ordinary carry fixture enforces the documented 25 kg/one-type rule; this is not implementation of the open D03 lifecycle membership/capacity matrix.

The demonstration deliberately omits general storage capacities, personal loadout eligibility, automatic selection/arbitration, stock-to-weapon issuance, courses and downstream lifecycles. Their systems must validate their own prerequisites before invoking accounting completion boundaries.

## Save/restore obligation

Inspection snapshots are not a save format. G32 must persist and validate stable IDs, holder relationships, person duties/pending requests/carry pointers, claim lifecycle/counts, origin/depleted records, loaded child stock, creation/consumption/loss totals, the portion-ID sequence, simulation timestamps and any required cause history. Restore must rebuild links without creating another physical copy, reject invalid relationships, and reconcile before resuming work. No save/load support or acceptance is claimed in G01.

## Verification evidence

Local engine: Steam Godot `4.7.2.stable.steam.ed1daf0bf`, Windows, Compatibility renderer. The repository check runs project import, thirteen regression cases (596 checks, including 250 fixed-seed mixed transitions), then main-scene startup. All passed with zero failures. The suite covers rejected-operation atomicity, carry cancellation/protection, overbooking, partial grants, foreign/mismatched claims, nested ammunition, explicit loss/consumption, remote transfers and detached inspections. CI runs the same suite on Linux; see the implementation PR's check result.

The native Godot window was exercised through its actual buttons at 960 by 540 with canvas scaling. Verified pickup, pending handoff and safe deposit; competing claims, carrier loading, release and retry; remote-transfer rejection; weapon handoff, unload, reload and loaded-reservation rejection. Populated inspection panels scroll while controls remain reachable. The small-window checks exposed and corrected clipping. These fixtures do not prove full-world presentation or performance.

Screenshots from the native walkthrough:

- [A01 pending safe handoff](evidence/g01/a01-pending-handoff.png)
- [A01 completed safe handoff](evidence/g01/a01-complete-handoff.png)
- [A02 competing requests](evidence/g01/a02-competing-requests.png)
- [A02 release and retry with physical cargo](evidence/g01/a02-release-and-retry.png)
- [A03 weapon handoff: accounting foundation only](evidence/g01/a03-accounting-weapon-handoff.png)
- [Loaded-round reservation rejection](evidence/g01/a03-accounting-loaded-reservation-blocked.png)

Not verified here: a live course/hauling scheduler; actual combat firing or weapon recovery; casualties; full-world movement, rendering or performance; persistence; D03 capacities. Complete A03 remains required under G16. Designer review and the implementation PR's checks remain prerequisites to merge.
