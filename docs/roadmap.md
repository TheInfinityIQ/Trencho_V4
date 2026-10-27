# Delivery roadmap

[GitHub project](https://github.com/users/TheInfinityIQ/projects/3) · [Milestones](https://github.com/TheInfinityIQ/Trencho_V4/milestones) · [Design](game_design_document.md) · [Developer onboarding](developer_onboarding.md) · [Team workflow](team_workflow.md)

The full target includes all five vehicles, engineering and four procedural map families. Milestones sequence playable evidence; they do not remove current scope. Battlefield acceptance uses the full 4 km × 6 km world. No dates or effort estimates have been invented.

Project views: [Workflow](https://github.com/users/TheInfinityIQ/projects/3/views/1), [Milestones](https://github.com/users/TheInfinityIQ/projects/3/views/2), [Ready to start](https://github.com/users/TheInfinityIQ/projects/3/views/3), and [Design decisions](https://github.com/users/TheInfinityIQ/projects/3/views/4). Status progresses through Backlog, Ready, In Progress, Blocked, Review and Done. An issue in Blocked may still permit the preparatory work expressly described in its body.

GDD v0.2 plus the dated v0.2.1 planning amendment governs this backlog. Gameplay values remain proposed defaults for review and playtests. GitHub issues are the execution record; the machine-readable [manifest](project_manifest.json) maps stable design IDs to issue URLs.

## Start here

### Status snapshot — 26 October 2026

This is a dated summary, not a live task board. Check the linked [GitHub issues](https://github.com/TheInfinityIQ/Trencho_V4/issues), [pull requests](https://github.com/TheInfinityIQ/Trencho_V4/pulls), [milestones](https://github.com/TheInfinityIQ/Trencho_V4/milestones), and [project views](https://github.com/users/TheInfinityIQ/projects/3) for current status. GDD section 23 and [design decisions](design_decisions.md) govern sequencing and retained integration obligations.

- [G01 #9](https://github.com/TheInfinityIQ/Trencho_V4/issues/9) / [PR #50](https://github.com/TheInfinityIQ/Trencho_V4/pull/50) and [G02 #10](https://github.com/TheInfinityIQ/Trencho_V4/issues/10) / [PR #51](https://github.com/TheInfinityIQ/Trencho_V4/pull/51) are accepted and merged. G01's full casualty/recovery integration remains with G16; G02 does not close later intake/capacity obligations.
- D02 #43 / [PR #52](https://github.com/TheInfinityIQ/Trencho_V4/pull/52) and D03 #44 / [PR #53](https://github.com/TheInfinityIQ/Trencho_V4/pull/53) have accepted, merged definitions. Their downstream gameplay evidence remains with the owning issues. [D01 #42](https://github.com/TheInfinityIQ/Trencho_V4/issues/42) remains open; production world presentation, platform, and full-map performance expectations are undecided.
- [G03 #11 / PR #54](https://github.com/TheInfinityIQ/Trencho_V4/pull/54) remains draft and unmerged pending native verification. Code-correction review is not final acceptance. Its current head is c0f0c6ed2dd69ee58a8cbd09f63a653e500143bd.
- [G08 #16 / PR #55](https://github.com/TheInfinityIQ/Trencho_V4/pull/55) remains draft. The [Game Designer decision dated 26 October 2026](https://github.com/TheInfinityIQ/Trencho_V4/issues/16#issuecomment-6424028116) resolves natural blast-cover classification; native acceptance remains pending. The linked PR records the current revision and CI evidence.
- G01/G02/G03/G08 review fixtures and reference tables are bounded evidence. They are not a playable rear-base logistics area, completion of M0, full-map proof, or proof of native gameplay. Visible rear-base orders, arrivals, assignments, hauling, and manufacture remain outstanding. Continue the recorded milestone sequence and gates without inferring a production presentation choice or a new feature assignment.

For assignment, work isolation, review ownership, and reporting, see [team workflow](team_workflow.md). Every substantive task still needs a short plan, observable acceptance, issue link, actual checks, and honest limits.

## Milestone exits

| Milestone | Playable result and evidence | Tracking |
| --- | --- | --- |
| [M0 — Rear economy and people](https://github.com/TheInfinityIQ/Trencho_V4/milestone/1) | Acquire, haul, manufacture, train, and assign actual people. Exact inventories; no doubled reservations, manufactured crew, or hidden local inputs | [Epic #1](https://github.com/TheInfinityIQ/Trencho_V4/issues/1) |
| [M1 — Full procedural world](https://github.com/TheInfinityIQ/Trencho_V4/milestone/2) | Generate all four families at required dimensions with valid terrain and routes. Accepted-map report for each seed and movement class; deliberate invalid candidates reject; full-sized fallback is validated; one validated full-size fallback for EACH of the four families | [Epic #2](https://github.com/TheInfinityIQ/Trencho_V4/issues/2) |
| [M2 — Operational transport](https://github.com/TheInfinityIQ/Trencho_V4/milestone/3) | T01 and T02 connect rear, HQ, and a real front. Payload, seats, crew, gross load, fuel, boarding, unloading, and local issue survive a complete cycle | [Epic #3](https://github.com/TheInfinityIQ/Trencho_V4/issues/3) |
| [M3 — Autonomous infantry engagement](https://github.com/TheInfinityIQ/Trencho_V4/milestone/4) | Command contests objectives and returns requisition. Downward intent, upward reports, coordinated squads, sustained contested objectives with requisition feedback, physical resupply and retreat on the full map. HQ victory is reserved for M5 onward; the assault capability rules are unchanged. | [Epic #4](https://github.com/TheInfinityIQ/Trencho_V4/issues/4) |
| [M4 — Engineering control of routes](https://github.com/TheInfinityIQ/Trencho_V4/milestone/5) | Build defences, depot, roads, bridges, mines, and charges. A convoy is blocked, cleared or rerouted, a crossing is denied, and engineers restore access using actual materials | [Epic #5](https://github.com/TheInfinityIQ/Trencho_V4/issues/5) |
| [M5 — Full vehicle combat](https://github.com/TheInfinityIQ/Trencho_V4/milestone/6) | Technical, APC, and tank join the economy and command chain. Real crew stations; armour interaction; one-squad APC load; combined arms; damage, recovery, and fuel constraints; demonstrate an HQ result using a genuinely eligible assault capability under section 16.3 | [Epic #6](https://github.com/TheInfinityIQ/Trencho_V4/issues/6) |
| [M6 — Supporting capabilities](https://github.com/TheInfinityIQ/Trencho_V4/milestone/7) | Medical, mortar, field gun, marksman, and drone systems integrate. Complete people-equipment-supply pairs; safe fire; actual evacuation; useful observation and counter-support | [Epic #7](https://github.com/TheInfinityIQ/Trencho_V4/issues/7) |
| [M7 — Full run and persistence](https://github.com/TheInfinityIQ/Trencho_V4/milestone/8) | Campaign, bundled cards, rewards, save and load, and whole-loop playtest. All prior systems remain coherent across generation, battle, result, and next engagement | [Epic #8](https://github.com/TheInfinityIQ/Trencho_V4/issues/8) |

M3 ends with contested objectives, income feedback, resupply and retreat; an HQ result requires an eligible assault capability and is demonstrated from M5 onward. Early foundation issues preserve later integration tests instead of creating circular dependencies.

## Work index

| Design ID | GitHub issue | Milestone | Completion dependencies |
| --- | --- | --- | --- |
| G01 | [[G01] Physical identity and ownership](https://github.com/TheInfinityIQ/Trencho_V4/issues/9) | M0 | None |
| G02 | [[G02] Procurement and receiving](https://github.com/TheInfinityIQ/Trencho_V4/issues/10) | M0 | [G01](https://github.com/TheInfinityIQ/Trencho_V4/issues/9) |
| G03 | [[G03] Rear staffing and hauling](https://github.com/TheInfinityIQ/Trencho_V4/issues/11) | M0 | [G01](https://github.com/TheInfinityIQ/Trencho_V4/issues/9) |
| G04 | [[G04] Recipes and essential material chains](https://github.com/TheInfinityIQ/Trencho_V4/issues/12) | M0 | [G02](https://github.com/TheInfinityIQ/Trencho_V4/issues/10), [G03](https://github.com/TheInfinityIQ/Trencho_V4/issues/11) |
| G05 | [[G05] Rear construction and placement](https://github.com/TheInfinityIQ/Trencho_V4/issues/13) | M0 | [G03](https://github.com/TheInfinityIQ/Trencho_V4/issues/11), [G04](https://github.com/TheInfinityIQ/Trencho_V4/issues/12) |
| G06 | [[G06] Basic and specialist courses](https://github.com/TheInfinityIQ/Trencho_V4/issues/14) | M0 | [G03](https://github.com/TheInfinityIQ/Trencho_V4/issues/11) |
| G07 | [[G07] Vehicle assembly and crew stations](https://github.com/TheInfinityIQ/Trencho_V4/issues/15) | M2 | [G04](https://github.com/TheInfinityIQ/Trencho_V4/issues/12), [G06](https://github.com/TheInfinityIQ/Trencho_V4/issues/14) |
| G08 | [[G08] Terrain movement and sight contract](https://github.com/TheInfinityIQ/Trencho_V4/issues/16) | M1 | None |
| G09 | [[G09] Broad landforms and natural terrain](https://github.com/TheInfinityIQ/Trencho_V4/issues/17) | M1 | [G08](https://github.com/TheInfinityIQ/Trencho_V4/issues/16), [D01](https://github.com/TheInfinityIQ/Trencho_V4/issues/42) |
| G10 | [[G10] Scenario anchors and validation](https://github.com/TheInfinityIQ/Trencho_V4/issues/18) | M1 | [G09](https://github.com/TheInfinityIQ/Trencho_V4/issues/17), [D02](https://github.com/TheInfinityIQ/Trencho_V4/issues/43) |
| G11 | [[G11] Generation repeatability and fallback](https://github.com/TheInfinityIQ/Trencho_V4/issues/19) | M1 | [G10](https://github.com/TheInfinityIQ/Trencho_V4/issues/18) |
| G12 | [[G12] Dispatch manifests and modes](https://github.com/TheInfinityIQ/Trencho_V4/issues/20) | M2 | [G03](https://github.com/TheInfinityIQ/Trencho_V4/issues/11), [G07](https://github.com/TheInfinityIQ/Trencho_V4/issues/15), [D03](https://github.com/TheInfinityIQ/Trencho_V4/issues/44) |
| G13 | [[G13] Routes fuel and gross load](https://github.com/TheInfinityIQ/Trencho_V4/issues/21) | M2 | [G08](https://github.com/TheInfinityIQ/Trencho_V4/issues/16), [G12](https://github.com/TheInfinityIQ/Trencho_V4/issues/20) |
| G14 | [[G14] HQ unloading and actual issue](https://github.com/TheInfinityIQ/Trencho_V4/issues/22) | M2 | [G13](https://github.com/TheInfinityIQ/Trencho_V4/issues/21) |
| G15 | [[G15] Military organization](https://github.com/TheInfinityIQ/Trencho_V4/issues/23) | M3 | [G06](https://github.com/TheInfinityIQ/Trencho_V4/issues/14), [G14](https://github.com/TheInfinityIQ/Trencho_V4/issues/22), [D03](https://github.com/TheInfinityIQ/Trencho_V4/issues/44) |
| G16 | [[G16] Combat wounds and morale](https://github.com/TheInfinityIQ/Trencho_V4/issues/24) | M3 | [G08](https://github.com/TheInfinityIQ/Trencho_V4/issues/16), [G15](https://github.com/TheInfinityIQ/Trencho_V4/issues/23) |
| G17 | [[G17] Hierarchical orders and information](https://github.com/TheInfinityIQ/Trencho_V4/issues/25) | M3 | [G15](https://github.com/TheInfinityIQ/Trencho_V4/issues/23), [G16](https://github.com/TheInfinityIQ/Trencho_V4/issues/24) |
| G18 | [[G18] Objectives and income](https://github.com/TheInfinityIQ/Trencho_V4/issues/26) | M3 | [G17](https://github.com/TheInfinityIQ/Trencho_V4/issues/25) |
| G19 | [[G19] Field structures and roads](https://github.com/TheInfinityIQ/Trencho_V4/issues/27) | M4 | [G04](https://github.com/TheInfinityIQ/Trencho_V4/issues/12), [G17](https://github.com/TheInfinityIQ/Trencho_V4/issues/25) |
| G20 | [[G20] Bridge construction and traversal](https://github.com/TheInfinityIQ/Trencho_V4/issues/28) | M4 | [G13](https://github.com/TheInfinityIQ/Trencho_V4/issues/21), [G19](https://github.com/TheInfinityIQ/Trencho_V4/issues/27) |
| G21 | [[G21] Bridge repair upgrade and demolition](https://github.com/TheInfinityIQ/Trencho_V4/issues/29) | M4 | [G20](https://github.com/TheInfinityIQ/Trencho_V4/issues/28) |
| G22 | [[G22] Mines IEDs and clearance](https://github.com/TheInfinityIQ/Trencho_V4/issues/30) | M4 | [G16](https://github.com/TheInfinityIQ/Trencho_V4/issues/24), [G19](https://github.com/TheInfinityIQ/Trencho_V4/issues/27) |
| G23 | [[G23] Vehicle armour and weapons](https://github.com/TheInfinityIQ/Trencho_V4/issues/31) | M5 | [G07](https://github.com/TheInfinityIQ/Trencho_V4/issues/15), [G16](https://github.com/TheInfinityIQ/Trencho_V4/issues/24) |
| G24 | [[G24] Vehicle destruction and recovery](https://github.com/TheInfinityIQ/Trencho_V4/issues/32) | M5 | [G20](https://github.com/TheInfinityIQ/Trencho_V4/issues/28), [G23](https://github.com/TheInfinityIQ/Trencho_V4/issues/31) |
| G25 | [[G25] Combined-arms transport AI](https://github.com/TheInfinityIQ/Trencho_V4/issues/33) | M5 | [G17](https://github.com/TheInfinityIQ/Trencho_V4/issues/25), [G23](https://github.com/TheInfinityIQ/Trencho_V4/issues/31) |
| G26 | [[G26] Forward supply and service teams](https://github.com/TheInfinityIQ/Trencho_V4/issues/34) | M6 | [G26a](https://github.com/TheInfinityIQ/Trencho_V4/issues/45), [G26b](https://github.com/TheInfinityIQ/Trencho_V4/issues/46) |
| G27 | [[G27] Medical evacuation and care](https://github.com/TheInfinityIQ/Trencho_V4/issues/35) | M6 | [G16](https://github.com/TheInfinityIQ/Trencho_V4/issues/24), [G26](https://github.com/TheInfinityIQ/Trencho_V4/issues/34) |
| G28 | [[G28] Indirect fire and reconnaissance](https://github.com/TheInfinityIQ/Trencho_V4/issues/36) | M6 | [G17](https://github.com/TheInfinityIQ/Trencho_V4/issues/25), [G26](https://github.com/TheInfinityIQ/Trencho_V4/issues/34) |
| G29 | [[G29] Enemy package economy](https://github.com/TheInfinityIQ/Trencho_V4/issues/37) | M6 | [G29a](https://github.com/TheInfinityIQ/Trencho_V4/issues/47), [G29b](https://github.com/TheInfinityIQ/Trencho_V4/issues/48), [G27](https://github.com/TheInfinityIQ/Trencho_V4/issues/35), [G28](https://github.com/TheInfinityIQ/Trencho_V4/issues/36) |
| G30 | [[G30] UI explanations and large-map controls](https://github.com/TheInfinityIQ/Trencho_V4/issues/38) | M7 | [D01](https://github.com/TheInfinityIQ/Trencho_V4/issues/42) |
| G31 | [[G31] Campaign and bundled access](https://github.com/TheInfinityIQ/Trencho_V4/issues/39) | M7 | [G04](https://github.com/TheInfinityIQ/Trencho_V4/issues/12), [G29](https://github.com/TheInfinityIQ/Trencho_V4/issues/37) |
| G32 | [[G32] Complete save and load](https://github.com/TheInfinityIQ/Trencho_V4/issues/40) | M7 | [G11](https://github.com/TheInfinityIQ/Trencho_V4/issues/19), [G21](https://github.com/TheInfinityIQ/Trencho_V4/issues/29), [G22](https://github.com/TheInfinityIQ/Trencho_V4/issues/30), [G24](https://github.com/TheInfinityIQ/Trencho_V4/issues/32), [G27](https://github.com/TheInfinityIQ/Trencho_V4/issues/35), [G28](https://github.com/TheInfinityIQ/Trencho_V4/issues/36), [G31](https://github.com/TheInfinityIQ/Trencho_V4/issues/39), [G30](https://github.com/TheInfinityIQ/Trencho_V4/issues/38) |
| G33 | [[G33] Integrated pacing and fairness trial](https://github.com/TheInfinityIQ/Trencho_V4/issues/41) | M7 | All G01–G32; see the native dependency list in [G33 #41](https://github.com/TheInfinityIQ/Trencho_V4/issues/41) |
| D01 | [[D01] Decide presentation, platform and measurable full-map targets](https://github.com/TheInfinityIQ/Trencho_V4/issues/42) | M1 | None |
| D02 | [[D02] Define repeatable cover-capacity fairness fixtures](https://github.com/TheInfinityIQ/Trencho_V4/issues/43) | M1 | None |
| D03 | [[D03] Approve people and capacity across transfer lifecycles](https://github.com/TheInfinityIQ/Trencho_V4/issues/44) | M0 | None |
| G26a | [[G26a] Forward depot delivery and consumption forecast](https://github.com/TheInfinityIQ/Trencho_V4/issues/45) | M4 | [G14](https://github.com/TheInfinityIQ/Trencho_V4/issues/22), [G19](https://github.com/TheInfinityIQ/Trencho_V4/issues/27) |
| G26b | [[G26b] Vehicle field service and physical replenishment](https://github.com/TheInfinityIQ/Trencho_V4/issues/46) | M5 | [G26a](https://github.com/TheInfinityIQ/Trencho_V4/issues/45), [G24](https://github.com/TheInfinityIQ/Trencho_V4/issues/32) |
| G29a | [[G29a] Opponent infantry purchases and actual delivery](https://github.com/TheInfinityIQ/Trencho_V4/issues/47) | M3 | [G14](https://github.com/TheInfinityIQ/Trencho_V4/issues/22), [G16](https://github.com/TheInfinityIQ/Trencho_V4/issues/24), [G18](https://github.com/TheInfinityIQ/Trencho_V4/issues/26) |
| G29b | [[G29b] Opponent vehicle packages and armour availability](https://github.com/TheInfinityIQ/Trencho_V4/issues/48) | M5 | [G29a](https://github.com/TheInfinityIQ/Trencho_V4/issues/47), [G23](https://github.com/TheInfinityIQ/Trencho_V4/issues/31), [G25](https://github.com/TheInfinityIQ/Trencho_V4/issues/33) |

## Tracking rules

- Native issue parents track milestone/feature scope; native blocked-by relationships track completion dependencies. Supply and opponent phase children have their own milestone while their parents integrate at M6.
- Labels record type, gameplay area, relative priority, role owner and planning readiness. `owner:software-developer` identifies the executing chat role without assigning an uninvolved human account.
- `status:ready` means no unresolved completion prerequisite; `status:blocked` means linked prerequisites remain; `status:backlog` covers umbrella or safe preparatory work; `status:in-progress` identifies active execution. Update labels and native Project Status together when work or dependencies change. The dated status snapshot above records verified public issue/PR state; the GitHub labels and project are the live tracking sources.
- Close G04 on material/recipe evidence; G31 completes C31 bundled unlock acceptance. Close G01 on identity/holding invariants; G16 completes casualty recovery. G07 establishes station readiness; G23 completes real firing. G20 repeats live bridge tests after G13 fixtures.
- Every feature includes A50 inspection and save-relevant state review; G30 and G32 perform final cross-system audits. Four validated full-sized authored map fallbacks are required, one per family.
- Scenarios in issues are requirements, not claims of executed gameplay tests. Close milestones only after linked behavior and integrated exit evidence have been reviewed.
