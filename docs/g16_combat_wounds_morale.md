# G16 combat, wounds and morale

Implemented from GDD v0.2 §§6, 12 and 17 and issue #24. This release uses the actual G01 ledger, G08 sight/cover contract, G15 formation records and the existing rear event clock. `game/combat/` owns direct-fire decisions, cadence, local reload commitments, suppression/morale, field care and the controlled review. The ledger owns the person lifecycle, loaded and loose ammunition, equipment holders and conservation counters. No replacement inventory or global autoload exists.

## Fire and physical stock

An active dismounted holder of E01, E05 or E19 can fire at a currently visible hostile person within the weapon's range and an unobstructed muzzle line. E19 requires P07, E05 requires P04, and E05 without a nearby active assistant uses its slower cadence and reload. G08 supplies range, visibility and directional cover. Training, movement, suppression, cover and range multiply the listed direct-hit chance, clamped only after eligibility. A friendly person or vehicle on the line withholds the shot. The target receives directed suppression even on a miss. Direct small-arms injury is reduced by worn E03/E04, then rounded up. One actual loaded E02 portion is consumed at release; a miss consumes it too. Reloading holds an explicit claim on matching loose rounds carried by that holder, takes the listed work time, and moves those same rounds into the weapon on completion. Interrupting a reload releases its claim. Empty weapons identify owned, unreserved remote loose stock by holder and position; loaded or enemy stock cannot fill that demand.

An allocated E13 field gun needs an active Artillery squad, four living P05 at the actual gun, a 20-second setup and an allocated local E14 shell. Its direct 60–650-metre shot consumes one shell, observes G08 sight and cover, uses ten-second cadence and applies its defined direct/blast maximum once per person. Mounted vehicle fire, armour penetration and full station behaviour belong to G23; indirect fire and scatter belong to G28.

## Casualties, cohesion and care

At zero health a person enters Wounded with an exact 60-second bleed deadline. Further positive injury or deadline expiry enters Dead once. Wounds retain the G15 roster place but suspend living capability; death releases the roster and military admission once. Worn protection remains on the body until death. Other personal gear and loose stock move to a recoverable place at the actual person position, or stay inside an occupied carrier. Loaded rounds stay inside the same intact, functional dropped weapon and can be recovered without double-counting. A dead or incapacitated occupant stays in the physical station pending extraction; G23/G24 will handle vehicle injury and ejection.

Directed suppression, nearby casualty morale loss, safe recovery rates and Pinned/Broken thresholds use the GDD values. Cohesion counts active dismounted members within 30 metres of the actual leader; a fully boarded squad is coherent but cannot fight as dismounted infantry. An actual member movement, casualty or leader change starts or clears the low-cohesion timer; inspection is read-only. Below half, offensive coordination is blocked for regrouping; after ten seconds it reports Dispersed. G17 owns the future movement, fallback and order response.

The A27 controlled fixture requires a living P03 with an E11 kit within two metres and one local unreserved E12 pack. Starting care consumes one pack; active work holds the patient's remaining bleed time, and ten cumulative active seconds stabilize at 35 health and Recovery assignment. Interruption preserves progress and resumes the remaining bleed timer. Another qualified kit holder can resume without another pack. Cancellation discards the committed pack and work. G27 retains evacuation, staffed HQ/aid-post recovery and capacity. The fixture does not claim those later behaviours.

## Inspection and later persistence

Dispatch inspection shows actual casualties, locations, stress, cohesion, supply blockers and care commitment. The G16 review scene exposes real people, holders, loaded/loose rounds, available/reserved counts, bleed and care work through mouse input at 960×540. The owner of each value is the live service or ledger, not display state.

G32 save/restore must serialize ledger person health/assignment/bleed deadline/loss flag, physical dropped places and holders, stock portions and claims, and combat RNG state, cooldowns, reload claims, gun setup, care commitments, stress timestamps, cohesion deadlines, death records, terrain references and event clock. On restore, reconcile each combat commitment with the same actual ledger identity before resuming. No free gear, rounds, patient recovery or duplicate death may be created.

Focused G16 regression covers A03, A26, A27, direct-fire gates, deployed W04, casualty morale and formation cohesion. The full `tools/check.ps1` suite and rendered input evidence are release gates.
