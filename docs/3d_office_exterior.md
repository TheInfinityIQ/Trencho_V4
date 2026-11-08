# Construction Office replacement: selected pre-code contract

**Selected candidate:** original Kenney City Kit Commercial2.1 `Models/GLB format/building-a.glb`, CC0. Baseline PR123 merge d44ecb10d28a252d911b0f1c262a84f68e1f8b67. Lead-approved bounded implementation on codex/3d-office-exterior. Runtime/visual acceptance remains pending; no local engine or old-flow checks. The merged Office proxy remains until a compatible replacement is integrated/reviewed. Rejected Industrial a/b/c/d findings remain in parent selection records.

## Original evidence and bounded search

Archive4096974bytes SHA256 f8b09b081c2bb88bcc126e2dec1cb40fd0dad7e7e591b6c26aaefe96fb35276b, supplied by Lead. Creator/version/license/source member hashes verified against its original bytes. Viewed the three supplied a/b/d thumbnails; inspected actual geometry only for a, selected its credible fit, and stopped. One mesh/primitive, no node TRS/matrix/animation; POSITION bounds include full roof projections. Door screening uses source POSITION/NORMAL/UV and its own original Commercial palette, not Industrial colors or a thumbnail assumption. Exact measurements/hashes will be retained in docs/3d_office_assets.json with implementation; [ownership](diagrams/3d_office_exterior.mmd) was recorded before code.

## Measured fit and entrance

Source bounds X[-0.441793919,0.441793978], Y[0,1.292999983], Z[-0.469999969,0.470000029]. Source-Z ground-level framed entrance/door bank includes right framed leaf X[0.101793945,0.341793954], Y[0,0.27], front frame Z-0.37/leaf plane-0.35, inset glass Y[0.02,0.25]. The full ground-level frame and top trim are measured separately from its glazing; no individual glass panel is asserted to be an enterable opening.

Uniform factor7.659574488 =7.2/max(sourceX,sourceZ), unchanged across both10×8 and8×10m reservations. Resulting shell X7.2×Y9.90383×Z6.76791m. Full entrance frame height2.06809m, width1.83830m; top frame underside1.91489m versus unchanged1.8m manager/0.8m capsule diameter. This clears the undersized Industrial rejection in both orientations. Actual appearance, trim/door interpretation and label readability still require a real manager reference.

Authored source-Z faces west with yaw+90; front_fraction0.248984882 along fitted world Z and front_inset0.10source units reaches measured outer frame behind roof overhang. Entrance offset≈(-2.83404,0,-1.69885)m. Keep actual row.door unchanged at local(-6,0) normal /(-5,0) quarter-turn; it is an outside service point, not a mesh-hole coordinate. Existing decorative cue connects it to the measured facade, reserved border stays clear. Same uniform fit leaves normal edge margins1.4/0.61605m and quarter margins0.4/1.61605m (X/Z). No blind90° extra turn or independent axis scaling.

Existing front-relative label rule yields anchor(-4.6,3.2,-1.69885)m, outside actual shell roof projection, with ordinary depth testing/bottom alignment. The nearly9.9m roof height is presentation only; preserve existing3m reserved movement collider and actual mesh layer4 picking/SpringArm with mask5. Manager mask1/actual dimensions remain unchanged. No interiors, walk-through door, climbing or elevated combat rule follows from this shell.

## Exact packaging and assigned narrow implementation

Proposed production files: `game/preview_3d/assets/commercial/building_a.glb`, `textures/colormap.png` under that same Commercial folder, and separate exact `license.txt`. Source GLB108936bytes SHA2565cf220f90ee3f21e7abe38055ca409a48aa8ef1d5ffab6e2deb99e5a5e1ed5e0. Apply only the existing documented JSON URI T→t case derivative at byte1366; file/chunk lengths and all binary geometry stay unchanged. Expected derived hash is recorded from memory-only calculation in the receipt, not claimed integrated yet.

Commercial palette11002bytes SHA256191bec3889aaaca5018380038fecc129ebb5c2182879a099b7b538b3fa050b5d is DIFFERENT from Industrial despite the same filename. Never overwrite/reuse the Industrial palette. Commercial license708bytes SHA256c38cee408d022e57e44e49f1cd655c2fe0dc881a07b881276b795215cdc0de69 stays exact original with appropriate .gitattributes. No archive/previews/research scripts/b/d/unrelated assets in production; no large binary/LFS need for these sizes.

C adds only the Complete construction mapping and explicit Commercial resource path, authored metadata/provenance/docs/purposes/maps. Cache scene resources by full path so equal vendor basenames cannot collide; keep the existing industrial defaults and semantics. Retire the Office-pending special case only for the compatible Complete mapping; unfinished/cancelled/recovery states retain their existing truthful representations. No backend/stock/labour/footprint/service-point changes, general asset framework or unrelated refactor.

Lead owns the two exact new isolated imports (Commercial GLB+its palette), actual generated sidecars, bounded remote engine parse/current-change observation, review and merge. A single later arranged Office+actual standing manager reference at the tighter quarter-turn footprint should confirm facade/cue/scale/label and actual roof occlusion, with normal-orientation fit supported by measured shared scale. Any unexercised orientation remains explicitly source-only evidence. No old gameplay loop, roster matrix, local engine, earned construction/native/FPS claim or higher limits. Actual visual rejection keeps Office pending; do not distort geometry to force approval.

**Next action:** C implements this selected contract and supplies the exact frozen source plus one ignored Office-only observation proposal. Lead owns workflow edits/imports/actual sidecars, bounded remote evidence, named reviews and merge. Actual visual rejection retains a truthful Office fallback.
