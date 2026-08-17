# Block Connectivity Tools Implementation Plan

> **For Hermes:** Use subagent-driven-development skill to implement this plan task-by-task.

**Goal:** Give MCP agent models a way to ask "what blocks can connect to this block / to block type X, on which side, at which coord/dir — and which actually fit in the available space?"

**Architecture:** The game engine already exposes its own connection solver to AngelScript: `CGameEditorPluginMap::GetConnectResults(CGameCtnBlock@ ExistingBlock, CGameCtnBlockInfo@ NewBlock)` fills `pmt.ConnectResults` (`MwFastBuffer<CGameEditorPluginMapConnectResults@>` — each has `CanPlace: bool`, `Coord: int3`, `Dir: ECardinalDirections`). For an *existing* map block, this is exactly "these are the valid ways NewBlock can attach to ExistingBlock". For the *general* ("block X → side → connecting block") mode there is no block-context-free engine query — no live instance to pass — so we synthesize one: place the source block in a far empty corner as a tagged temp block, run GetConnectResults against it per candidate model, then delete it. Space-fitting ("only show those which fit") filters via `CanPlaceBlock` (engine's full validity incl. collision) and additionally `CanPlaceBlock_NoDestruction` (no existing-block destruction) so the model can distinguish "fits" from "fits only by overwriting".

**Tech Stack:** AngelScript on Openplanet Next, tm-mcp-pack-epp tool pack (registers into tm-control-mcp via `TmMcp::ToolPackBuilder`), engine `CGameEditorPluginMap` API. No new E++ imports needed (GetConnectResults is a plain game-class method, callable directly).

---

## Current context / assumptions

- Pack pattern (verified in `src/Main.as`, `src/Tools.as`): tool impls live in `src/*.as` under `namespace TmMcpPackEpp`, return `Ok(o)` / `Err(msg[, code])`; `Ok`/`Err` defined in `src/Json.as`. Each tool needs 3 edits: impl, `Dispatch` line, `Add(b, ...)` registration, plus the `ListCoverage` names array in `src/Tools.as:239`.
- `GetEditor()` / `NeedEditor()` helpers already exist (used everywhere in Tools.as).
- `ResolveBlockModel(editor.PluginMapType, name, out isTerrain)` at `src/NamedMacroblocks.as:829` resolves a name against `pmt.BlockModels` + `pmt.TerrainBlockModels` — reuse it for both source and candidate resolution.
- `ModelToJson(blockInfo, isTerrain)` at `src/Helpers.as:245` — reuse for candidate metadata rows.
- Engine API confirmed in `~/OpenplanetNext/OpenplanetNext.json`:
  - `pmt.GetConnectResults(CGameCtnBlock@, CGameCtnBlockInfo@) -> void` (member index 177); results land in `pmt.ConnectResults`.
  - Sibling variants `GetConnectResultsBlockToMacroBlock` / `MacroBlockToBlock` / `MacroBlockToMacroBlock` exist — **out of scope** for this plan (macroblock connectivity is a follow-up).
  - `pmt.CanPlaceBlock(BlockModel, int3 Coord, ECardinalDirections Dir, bool OnGround, uint VariantIndex) -> bool` (index 98); `CanPlaceBlock_NoDestruction` same signature (index 102).
  - `CGameEditorPluginMapConnectResults`: `CanPlace bool`, `Coord int3`, `Dir ECardinalDirections`.
  - `ECardinalDirections` values: `["North","East","South","West"]` (index = int).
- **Assumption to validate during implementation:** calling `GetConnectResults` mutates only `pmt.ConnectResults` (no placement side effects). E++ itself never calls it, so there is no in-repo precedent — this is the main unknown and is why Task 2 is a standalone probe before building the tools on top.
- **Free blocks caveat:** `GetConnectResults` semantics for freeform blocks (no grid coord) are unknown; likely grid-based only. Plan handles this by returning a clear error when the source block is a free block (`Editor::IsBlockFree`), rather than guessing.
- Temp synthetic block placement uses existing pack placement (`Editor::PlaceBlocks` with a spec — see `PlaceBlock` in `src/Tools.as:492`) and deletion via `Editor::DeleteBlocksAndItems` (see `src/Tools.as:72`). Temp block goes to coord (0,0,0)-adjacent empty region found by scanning `editor.Challenge.Blocks` occupancy, or — simpler and safer — placed with `addUndo=false` and removed immediately in a `try`/`finally`-style guard (AngelScript has no finally; use explicit cleanup on every return path via a small helper).
- Build/deploy: `./build.sh dev` stages to `~/OpenplanetNext/Plugins/tm-mcp-pack-epp` and RemoteBuild-loads (host 10.100.1.3). Live smoke via `python3 ../tm-control-mcp/tools/call.py tm-mcp-pack-epp.Ping`.

## Proposed tools (public names `tm-mcp-pack-epp.<Name>`)

### Tool 1: `GetBlockConnections` — per-instance mode
Input: `index` (map block index) OR `coord` (`x,y,z` int3). Optional: `newBlockName` (restrict to one candidate), `onlyPlaceable` (default false → return all CanPlace=false rows too), `fitsSpace` (default false → when true, annotate/filter by CanPlaceBlock check at each result coord).
Output: `{ block: {index, name, coord, dir}, candidates: [ { name, idName, results: [ { coord: int3, dir: "North"|"East"|"South"|"West", dirIndex, canConnect, fits, fitsNoDestruction } ] } ], scanned, truncated }`.

Behavior:
1. Resolve the existing block from `editor.Challenge.Blocks` (by index, or by matching `block.Coord` for non-free blocks).
2. Reject free blocks with a clear error (grid connectivity only).
3. Candidate set: single model if `newBlockName`, else iterate `pmt.BlockModels` (non-terrain). Terrain models skipped (they terraform, not connect).
4. Per candidate: call `pmt.GetConnectResults(block, candidateInfo)`, read/drain `pmt.ConnectResults` into JSON rows.
5. If `fitsSpace`: per row also call `pmt.CanPlaceBlock(candidateInfo, coord, dir, /*OnGround*/ true, 0)` and `CanPlaceBlock_NoDestruction`; when `onlyPlaceable` also true, drop rows where `fitsNoDestruction` is false.
6. Cap total rows (`limit`, default 200) with `truncated` flag.

Note the engine's `CanPlace` flag on each result already says whether the *connection* is valid; `fits`/`fitsNoDestruction` answer the separate "space available" question the user asked for. `OnGround=true` for the CanPlaceBlock probe: connection results from ground/air blocks are both reported against ground variants; if probing proves air-variant answers matter, add `onGround` input later (YAGNI for now).

### Tool 2: `FindConnectingBlocks` — general mode
Input: `blockName` (source model), optional `dir` ("North"|"East"|"South"|"West" — source block's facing when synthesized; default North), optional `query` (substring filter on candidate names), `onlyPlaceable`, `limit`.
Output: `{ source: {name, dir}, candidates: [ { name, idName, results: [ { coord, dir, dirIndex, canConnect } ] } ], scanned, note }`.

Behavior:
1. Resolve source model via `ResolveBlockModel` (terrain → error).
2. Find a temp placement coord: scan map bounds for an empty 4x4 cell region (reuse `WorldPosInsideMap` + an occupancy set built from `editor.Challenge.Blocks[].Coord`; helper `FindEmptyCoord(editor)`), fallback coord (size.x-2, 0, size.z-2) corner.
3. Place source block as temp (grid spec via `Editor::MakeBlockSpec(info, pos, rot)` from `coord*32` world pos, NOT free; `addUndo=false`), remembering its new index (`editor.Challenge.Blocks.Length - 1` after place, or re-find by coord).
4. Run the same per-candidate GetConnectResults loop as Tool 1 against the temp block.
5. Delete the temp block (`Editor::DeleteBlocksAndItems` on a spec made from it, `addUndo=false`) on **every** exit path (extract steps 4 between place/delete into a helper that returns Json so cleanup is linear code).
6. Return results. `note` records the temp-block coord/dir used (coords in results are absolute map coords relative to the temp placement — model must subtract; include `tempCoord` + `sourceCoord` so deltas are computable).

Both tools share a `CollectConnectResults(pmt, block, candidates[], opts)` helper in a new file.

### Tool 3: `PlaceGridBlock` — normal (non-free) block placement
The pack's `PlaceBlock` and `PlaceNamedMacroblock` always produce **free blocks** (`spec.SetFree()` — see `src/Tools.as:511` and `src/NamedMacroblocks.as:127`), so agents currently cannot place ordinary grid-aligned blocks that participate in the editor's connection model. This tool fills that gap.

Input: `blockName`, `coord` (`[x,y,z]` int3 block-unit grid coord), `dir` ("North"|"East"|"South"|"West", default North), `variant` (default 0), `onGround` (default true — selects ground vs air variant for the CanPlace check), `noDestruction` (default true → use `PlaceBlock_NoDestruction`; false → `PlaceBlock` which may overwrite), `ghost` (default false → `PlaceGhostBlock` for ghost blocks), `tag` (optional agent tag), `autofocus`.
Output: `{ placed, coord, dir, dirIndex, blockName, ghost, canPlace, note }` with `placed:false` + `canPlace:false` when the engine refuses (pre-checked via `CanPlaceBlock` / `CanPlaceBlock_NoDestruction` so we can report why without side effects).

Implementation: direct engine calls `pmt.CanPlaceBlock(_NoDestruction)(info, coord, dir, onGround, variant)` then `pmt.PlaceBlock(_NoDestruction)(info, coord, dir)` (or `PlaceGhostBlock`). Precedent in E++ itself: `Components/Inventory/NextPlacement.as:133-136` uses exactly this pair. `DirFromString` helper already exists at `src/Helpers.as:27`. World-pos convenience: accept optional `x,y,z` meters and convert via the PosToCoord formula already in `CoordConvert` (`src/Tools.as:438`).

## Step-by-step plan

### Task 1: Probe `GetConnectResults` semantics in a dev script

**Objective:** Confirm the method is callable, has no side effects, and learn result shape on a real map before writing pack code.

**Files:**
- Create: `research/getconnectresults-probe.as` (throwaway probe plugin source, not shipped)

**Steps:**
1. Write a minimal standalone probe plugin (separate folder under `~/OpenplanetNext/Plugins/epp-vprepro`-style dev plugin, or a `void Main()` + hotkey in an existing dev plugin): get editor, pick `editor.Challenge.Blocks[0]`, call `editor.PluginMapType.GetConnectResults(block, someRoadBlockInfo)`, dump `pmt.ConnectResults.Length` and each row's `CanPlace/Coord/Dir` via `print()`. Try 2-3 candidate models (a road, a platform, a decoration).
2. Stage + load via RemoteBuild (host 10.100.1.3) with TM running in a map editor with some blocks down.
3. Record in `research/getconnectresults-findings.md`: result counts, whether results include only-placeable or all-4-sides, whether Coord is absolute, behavior with a null/invalid candidate, behavior on terrain blocks, whether ConnectResults persists between calls (drain needed?), any log errors.
4. **Gate:** if GetConnectResults turns out to require specific editor state (e.g. Place mode active) or crashes, fall back in the plan to the pure-heuristic implementation (coord adjacency + `CanPlaceBlock` brute force over the 4 neighbor cells per candidate) and record why.

### Task 2: Shared connectivity helper module

**Objective:** One tested helper both tools call.

**Files:**
- Create: `src/BlockConnections.as`

**Contents (TDD-ish; verification is live smoke since there is no unit test harness in this repo):**
1. `string DirName(CGameEditorPluginMap::ECardinalDirections dir)` — index into `{"North","East","South","West"}`.
2. `Json::Value ConnectResultRow(int3 coord, dir, bool canConnect)` — row shape `{coord, dir, dirIndex, canConnect}`.
3. `void DrainConnectResults(CGameEditorPluginMap@ pmt, Json::Value@ rows, int limit, int &inout scanned, bool &out truncated)` — iterate `pmt.ConnectResults`, append rows until limit.
4. `Json::Value@ RunCandidate(CGameEditorPluginMap@ pmt, CGameCtnBlock@ block, CGameCtnBlockInfo@ candidate, bool fitsSpace, bool onlyPlaceable, int limit, ...)` — calls GetConnectResults, drains, optionally annotates `fits`/`fitsNoDestruction` via CanPlaceBlock / CanPlaceBlock_NoDestruction.
5. `CGameCtnBlock@ FindBlockByCoord(CGameCtnChallenge@ map, nat3 coord)` — linear scan, skip free blocks.
6. `bool FindEmptyCoord(CGameCtnEditorFree@ editor, nat3 &out coord)` — occupancy set from `map.Blocks[].Coord`; search from a corner inward (simple nested loop, map sizes ≤ 48x40x48 — bounded).
7. Compile-check via `./build.sh dev` (RemoteBuild load fails loudly on compile errors in Openplanet.log / remote-build output).

### Task 3: `GetBlockConnections` tool

**Files:**
- Modify: `src/BlockConnections.as` (add tool fn `Json::Value@ GetBlockConnections(Json::Value &in input)`)
- Modify: `src/Main.as` — Dispatch line after `AssertPlacement`; `Add(b, "GetBlockConnections", ...)` registration
- Modify: `src/Tools.as:239` — add name to ListCoverage array

**Schema:**
```json
{"type":"object","properties":{"index":{"type":"integer"},"coord":{"type":"array"},"newBlockName":{"type":"string"},"query":{"type":"string"},"onlyPlaceable":{"type":"boolean"},"fitsSpace":{"type":"boolean"},"limit":{"type":"integer"}},"additionalProperties":false}
```
(require index XOR coord — validate in code, `Err("pass index or coord")`.)

**Steps:**
1. Implement per "Tool 1" above. Reject free blocks: `Editor::IsBlockFree(block)` → `Err("free blocks have no grid connectivity", "free_block")`.
2. `query` substring filter (reuse `ModelMatchesQuery` from Helpers.as:237) to keep responses small when no `newBlockName`.
3. `./build.sh dev`, then live smoke:
   - `python3 ../tm-control-mcp/tools/call.py tm-mcp-pack-epp.GetBlockConnections '{"index":0,"newBlockName":"RoadTech"}'` → expect candidates[0].results non-empty with canConnect rows.
   - Same with `"onlyPlaceable":true,"fitsSpace":true`.
   - Error paths: bad index, free block index, unknown newBlockName.
4. Commit: `feat: GetBlockConnections — engine connection results per existing block`

### Task 4: `FindConnectingBlocks` tool (synthetic temp block)

**Files:**
- Modify: `src/BlockConnections.as` (add `Json::Value@ FindConnectingBlocks(Json::Value &in input)` + temp place/delete helpers)
- Modify: `src/Main.as` + `src/Tools.as` ListCoverage (same 3-edit pattern)

**Schema:**
```json
{"type":"object","properties":{"blockName":{"type":"string"},"dir":{"type":"string"},"query":{"type":"string"},"onlyPlaceable":{"type":"boolean"},"limit":{"type":"integer"}},"required":["blockName"],"additionalProperties":false}
```

**Steps:**
1. Implement per "Tool 2" above. Temp block: non-free spec (`Editor::MakeBlockSpec` without `SetFree()`), placed with `addUndo=false` at `FindEmptyCoord`; capture placed block via `FindBlockByCoord` at that coord after place.
2. Cleanup discipline: place → `Json::Value@ result = RunAllCandidates(...)` → delete temp → return result. Any early `Err` return after placement must delete first (structure code so the only early returns happen before placement).
3. Verify map unchanged: smoke with `SummarizeMap` block count before/after.
4. `./build.sh dev` + live smoke:
   - `...FindConnectingBlocks '{"blockName":"RoadTech","query":"Road","limit":50}'` → list of road models with connect rows; `tempCoord` present.
   - Verify `nbBlocks` in output `mapBefore == mapAfter`.
5. Commit: `feat: FindConnectingBlocks — what connects to a block model (synthetic probe)`

### Task 5: `PlaceGridBlock` tool

**Files:**
- Modify: `src/Tools.as` (add `Json::Value@ PlaceGridBlock(Json::Value &in input)`)
- Modify: `src/Main.as` — Dispatch line + `Add(b, "PlaceGridBlock", ...)` registration
- Modify: `src/Tools.as` ListCoverage array

**Schema:**
```json
{"type":"object","properties":{"blockName":{"type":"string"},"coord":{"type":"array"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"dir":{"type":"string"},"variant":{"type":"integer"},"onGround":{"type":"boolean"},"noDestruction":{"type":"boolean"},"ghost":{"type":"boolean"},"autofocus":{"type":"boolean"},"tag":{"type":"string"}},"required":["blockName"],"additionalProperties":false}
```
(coord as int3 array OR x,y,z world meters — validate exactly one form in code.)

**Steps:**
1. Implement per "Tool 3" above. Pre-check `CanPlaceBlock(_NoDestruction)` and include its result in output even when refusing to place. On successful place, find the new block (scan by coord) and register `tag` via the existing SetAgentTag/tag-index machinery if provided.
2. `./build.sh dev`, live smoke:
   - Place a road block next to an existing road on a test map; verify it appears in `SummarizeMap` **without** `isFree` (i.e. absent from the free-block anomaly note) and that `GetBlockConnections` on a neighbor now lists connections to it.
   - Refusal path: occupied coord with `noDestruction:true` → `placed:false, canPlace:false`, map unchanged.
   - Ghost path: `ghost:true` → `IsGhostBlock()` true in `GetBlockLocation`/SummarizeMap.
3. Commit: `feat: PlaceGridBlock — engine grid/ghost block placement (non-free)`

### Task 6: Docs + coverage

**Files:**
- Modify: `AGENTS.md` (one-liner under Project Notes if it has a tools list — check; keep minimal)
- Modify: `README.md` if it enumerates tools (check first)

**Steps:**
1. Add the three tools to any tool list in README/AGENTS.md.
2. Final smoke: `python3 ../tm-control-mcp/tools/call.py tm-mcp-pack-epp.ListCoverage` shows all new names; `python3 ../tm-control-mcp/tools/call.py ListToolPacks` still healthy.
3. Commit: `docs: block connectivity + grid placement tools`

## Tests / validation

No unit test harness exists in this repo — validation is compile + live smoke against the running game (consistent with how previous tools landed, e.g. CheckCheckpoints, GetDialog):

1. `./build.sh dev` stages + RemoteBuild-loads; check output for compile errors.
2. `python3 ../tm-control-mcp/tools/call.py tm-mcp-pack-epp.Ping` — pack alive.
3. Tool-specific smokes listed per task (Tasks 3, 4), including error paths and the map-unchanged invariant for the temp-block tool.
4. Openplanet.log trace lines (`TM Control MCP pack start/done tm-mcp-pack-epp.<Tool>`) confirm dispatch.

## Risks, tradeoffs, open questions

- **R1 (main unknown):** `GetConnectResults` preconditions/side effects are undocumented; nobody in the local corpus calls it. Mitigated by Task 1 probe with an explicit fallback (brute-force CanPlaceBlock over adjacent cells) if it misbehaves.
- **R2:** Temp-block placement in general mode mutates the map briefly. If TM crashes mid-call, a stray block remains (no undo entry since addUndo=false). Acceptable: corner placement, and user can delete; we also return `tempCoord` in errors after placement. Alternative (pure CanPlaceBlock sweep with no temp block) cannot answer "connects" — only "fits" — so temp-block is required for real connectivity info.
- **R3:** `CanPlace` on results may already incorporate collision (making `fitsSpace` partly redundant) — keep both; the probe will clarify.
- **R4:** Scanning all ~hundreds of BlockModels × GetConnectResults could be slow (engine call per candidate). Mitigate: `query` filter, `limit`, and measure during smoke; if slow, add candidate `type`/category filter later (YAGNI now).
- **R5 (out of scope):** Macroblock connectivity (`GetConnectResultsBlockToMacroBlock` etc.) and per-side frontier shape data (CGameCtnBlockInfoFrontier exposes nothing script-side). Follow-up if models ask for macroblock answers.
- **Open question for the user:** is the synthetic-temp-block approach acceptable for the general mode (brief map mutation), or do you want general mode restricted to candidates against an *existing* block only (i.e. require an anchor block in the map)? Default in this plan: temp block, flagged in output.
