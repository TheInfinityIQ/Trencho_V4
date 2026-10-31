# Rifle ammunition collection

## Accepted outcome and plan — 31 October 2026

An urgently depleted forward Rifle squad physically collects real ammunition at its declared safe rendezvous, waits for the remaining eligible carriers to hold 60 actual E02 each and their handling to clear, then follows its latest acknowledged feasible operation. The existing squad average below 15 starts routine collection; individual requests below 30 remain early local demand. Loaded and loose rounds count once. Insufficient stock keeps the current shortage open; one refilled member never completes the squad.

Immediate survival and actual HQ emergency defence override routine collection. Such reassignment interrupts collection rather than completing it. Death, incapacitation or departure removes an ineligible person without transferring or crediting their goods. Lost weapons, casualty minimums, leadership, morale, cohesion, route safety and applicable transport rules retain their own requirements. Sixty is a restock target, not a continuous combat cutoff or the distinct 90-round HQ-assault package.

Implementation ownership:

- OpeningPolicy supplies an explicit rendezvous in its owned forwarded Rifle intent. New parent commands remain authoritative.
- SquadExecution owns collection, waiting and resumption. It uses existing safe foot movement and physical activity exclusions, allows empty rifles to travel for supply, and never restores a saved obsolete objective.
- OpeningResupply owns named squad requests/status through its existing per-person requests and actual ForwardSupply couriers. The ledger remains the sole inventory owner; interrupted carry retains its physical identity and claim.
- Ordinary inspection shows collection reason, destination, actual aboard ammunition, outstanding need and courier commitments.

Acceptance is one current-action flow: actual urgent cohort arrival, real Engineer issue, honest waiting with partial supply, no early departure, and resumption under the current valid acknowledged operation. No regression fixtures, broad scenarios or local engine runs. Necessary direct demonstration stays brief on GitHub; compilation alone does not establish the behavior.

The first connected case is a short safe foot journey to the declared blue-delivery rendezvous. Supply and return motions retain the actual acknowledged intent, person duty and delivered-fire checks. A changed or pending order stops that owned motion; resumption reads the current acknowledged destination.

The greater-than-600-metre rule is conditional. The follow-up [collection travel connection](rifle_collection_travel.md) now compares measured safe foot travel with eligible same-company T02 pickup, boarding, loaded travel and dismount. Real parent acknowledgement and physical transport apply to both collection and current-operation return. Its supported cohort/route boundaries and remaining broader transport allocation are explicit; the first short-foot flow below was not replayed. Existing indivisible costs and desktop responsiveness remain unverified.

General Red logistics, predictive supply planning, HQ-assault preparation and other vehicles' physical supply remain unfinished main-game requirements.

## Integration corrections

Focused source review found that a person already at the rendezvous could retain an old Advance/return leg while the squad waited for ammunition. Collection now stops that superseded execution motion after the existing busy, Pinned and Broken priority branches. This is separate from respecting a replacement command, where only the collection's owned movements are stopped.

Loaded ammunition remains real E02 stock nested under its weapon: `load_rounds` splits and moves stock, rather than replacing it with a separate authoritative counter. The ledger's global `total_stock("E02")` therefore already includes those portions. Per-carrier targets use `military._rounds`; adding a weapon's loaded-round display to the global stock total would count it twice.

The first gameplay attempt reached the rendezvous and exposed a courier route refusal despite its facing being derived from the very same lane endpoints. Two people had 60 rounds, two had 10, and a real Engineer retained 50 rounds; no target completion was fabricated. Both synchronous and incremental terrain route calculations now recognize equality with the exact endpoint-derived angle before the existing normalized-cross alignment check. Other headings retain the prior tolerance and turn refusal, and all footprint, obstacle, surface, load and timing checks remain. Godot documents the [32-bit Vector2 / 64-bit GDScript float distinction](https://docs.godotengine.org/en/4.7/classes/class_vector2.html); the exact failed cross-product value was not reconstructed from full-precision handler geometry. This is a correction to the observed rejection, not a measured claim about every numerical operation.

The handoff also exposed a runtime typed-array error: an empty array selected through a conditional expression did not retain `Array[String]`. An explicit typed initialization followed by conditional assignment preserves the intended type. The script-error check correctly rejected the run even though its observed people later reached their destination. A successful gameplay observation with an engine error is not a passed check.

## Current direct evidence

Production `8f6c55e63dc02d118888f7d4c1dcc83eee331778` passed [the brief new Rifle flow on GitHub](https://github.com/TheInfinityIQ/Trencho_V4/actions/runs/41200801511), with no script errors: 1,500 returned frames, 150 simulation seconds and 14.720 seconds of demonstration wall time. This was one current-action flow, corrected and repeated only after the failures above; no old opening, regression suite, matrix, local engine or profiler ran. The first attempt stopped before gameplay because the Lead's demonstration double-counted loaded stock; a later demonstration assertion incorrectly treated the newly admitted return walk as uncleared courier work. Correcting those observations did not change production rules.

Declared starting people, equipment, inventory and short safe places established the context. A real acknowledged parent operation preceded accounted use of 20 loose rounds per Rifle carrier, leaving 10 loaded each. The four actual people walked about 100 m to supply. Engineers physically issued the 150 local rounds; at simulation time 60.5 three carriers had 60 and one had 10, with 50 still needed and the same collection unreleased despite its higher average. Withholding more stock retained that shortage.

A real replacement parent order was acknowledged at time 63 while the same incomplete cycle remained. A real T01 then loaded, transported and unloaded the existing 50 HQ rounds and returned. Actual Engineer issue brought every carrier to 60 and completed the courier jobs; release admitted new tactical movement at time 92. Current all-work status can correctly become busy again because that new return walk has begun. At time 150 the same four people physically reached the latest operation's place within its normal arrival tolerance, with the current intent and state Operating. The old objective was not restored. All 440 declared E02 were accounted for as 80 consumed and 360 still physical, including loaded portions.

This demonstrates the new short-foot collection/refill/current-order return connection using controlled ledger consumption. It does not establish natural combat depletion, emergency/casualty behavior, the unfinished longer-distance transport comparison, the full opening, native Windows responsiveness, rendered interaction, requested-speed throughput or main-game completion. The Principle Engineer reviewed the source boundaries, confirmed the hold and exact-heading fixes, and found no remaining actionable issue in that focused review.
