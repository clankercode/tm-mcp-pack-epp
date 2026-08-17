# GetConnectResults probe findings (2026-08-17)

Probed live via `epp-vprepro` dev plugin against AutoSave18/testmap (TM editor, 2419 blocks).

## The API works and is the right foundation

`pmt.GetConnectResults(existingBlock, newBlockInfo)` fills `pmt.ConnectResults`
(`MwFastBuffer<CGameEditorPluginMapConnectResults@>` — `CanPlace bool`, `Coord int3`,
`Dir ECardinalDirections`). No placement side effects (map block count unchanged across calls).
`ConnectResults` does not accumulate across calls (each call replaces; Length=0 after empty result).

## Semantics learned

1. **Result rows = valid placement options for the NEW block** that attach it to the existing block:
   absolute map coord + the dir the NEW block must face. Example — DecoWallBasePillar @ <16,30,30> dir=2,
   candidate pillar: 4 rows, one per neighbor cell (<16,30,29>/N, <17,30,30>/E, <16,30,31>/S, <15,30,30>/W).
2. **Per (coord × dir) options**: candidate RoadTechStraight vs the same pillar gave 8 rows — 4 cells ×
   2 orientations (straights along the face tangent). Candidate RoadTechCurve1: 8 rows (4 cells × 2 curve chiralities).
3. **`CanPlace` was true on all rows** in all probes — including cells confirmed EMPTY via
   `CanPlaceBlock_NoDestruction`. Whether it flips false on occupied cells is UNVERIFIED here
   (no occupied-connector case on the test map). Implementation must treat `CanPlace` as
   "connection geometry valid", and use explicit `CanPlaceBlock(_NoDestruction)` per row for the
   "fits in available space" question — exactly the plan's `fits`/`fitsNoDestruction` split.
4. **Symmetric blocks collapse**: pillar→pillar returns 1 row per cell (dir = away from source);
   non-symmetric candidates return multiple dirs per cell.

## CRITICAL pitfalls (do not regress)

- **`GetConnectResults(block, null)` CRASHES THE GAME** (confirmed: hard crash at 13:49, TM restart).
  Never call with a null candidate. Guard every resolution.
- **Road blocks returned 0 results** in every combination probed (RoadTechStart→RoadTech*,
  RoadTechCurve1→RoadTech*, GateFinish→RoadTech*). Road connectivity is NOT exposed through this API
  (roads connect via frontier/matching logic, not clips). Tools must surface `results: []` honestly —
  empty does not mean "error", it means "no clip-based connections". Pillar/deco blocks DO return results.
- **Free blocks**: source free block → 0 results (free blocks have sentinel coord x/z=0xFFFFFFFF
  and no grid attachment). Reject free source blocks with a clear error.
- **Inventory gaps**: `DecoWallBasePillar` blocks exist on the map but the model is NOT in
  `pmt.BlockModels` (exact IdName lookup fails). Candidate enumeration covers only inventory models;
  resolution of a specific name should also try matching against placed blocks' BlockInfo as a fallback.

## CanPlaceBlock verified behavior

- occupied coord (42,24,28 = RoadTechStart): `CanPlaceBlock` false, `CanPlaceBlock_NoDestruction` false.
- empty ground coord: true; empty air coord (OnGround=false): true.
- Safe to call freely, no side effects. This is the fits-in-space oracle.

## Clip-list bonus discovery

`pmt.CreateFixedClipList()` + `SetClipListFromBlockOnly(model)` exposes a model's connector clips:
RoadTechStraight → 2 clips, both `RoadTechFC`, at coord <0,0,1> dir=North and <0,0,-1> dir=South,
`GetConnectableCoord()` = <0,0,0> (the block's own cell). This is a **pure, map-free** way to answer
"which sides does block model X connect on" (general mode) WITHOUT a temp block. It does not by itself
say which OTHER models fit those clips (no compatibility pairing exposed), but combined with
per-candidate `CanPlaceBlock` at the implied neighbor cells it can power general mode for clip-bearing
blocks without map mutation. Temp-block GetConnectResults remains the fallback for richer answers.
