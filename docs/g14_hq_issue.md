# G14 HQ issue boundary

The shared identity ledger owns each HQ stock stack, weapon, person, hull, fuel unit, and reservation. Dispatch unloads manifests through its existing berth handling into `hq-stock` and `hq-reserve`; arrival or an issue claim leaves recipients unchanged. The HQ service only reserves owned stock already in `hq-stock` and issues it after a named local handler's timed pickup and drop. Reserve personnel walk to stock and back before their issue job completes. Vehicle ammunition must match the same stopped military hull's rack capacity at the HQ berth, while M08 fuel enters only its actual tank. Cancelled active carries return physically to HQ stock before releasing the remaining claim.

The four logistics staff among the five fixed HQ people are exclusive across dispatch unloading and issue jobs. The fifth remains the Commander. HQ stock remains limited to 20,000 kg and the reserve to 96 people; the two receiving berths and military fleet/population admissions still belong to dispatch. The new HQ Issue panel shows available and reserved local quantities, per-job progress, and blockers.

A24 is an explicit boundary: unloading E25 shells at HQ cannot refill a T05 two kilometres away. Only the same tank at the HQ berth may receive a local rack handoff. Remote delivery and local battlefield transfer are G23/G26, and save/restore is G32.

Verification: `tools/check.ps1` includes `game/hq/tests/hq_regression.gd`; `tools/gdunit4_tests.json` names the interactive HQ panel case. Headless startup alone does not establish visual or gameplay correctness.
