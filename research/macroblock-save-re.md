# RE: Saving macroblocks (native `.Macroblock.Gbx` + inventory pickup)

Date: 2026-08-16 · Binary: Trackmania.exe (tm2020-headless Ghidra project on x-left, `tm2020-headless.gpr`)
Tools: ghidra-mcp HTTP endpoint (see "Session access" below). All functions below are renamed + plate-commented
in the Ghidra DB so future RE starts from named symbols.

## TL;DR — feasibility

**YES — saving a native macroblock from a plugin is practical.** There is a public ManiaScript
method on `CGameEditorPluginMap`:

```
void CGameEditorPluginMap::SaveMacroblock(CGameCtnMacroBlockInfo@ MacroblockModel)   // member index 139
```

It is registered in `InitializeCGameEditorPluginMapReflectionDescriptors` (string `141c9fbb8`,
descriptor `_DAT_141f1de00/…de28`, handler `EditorPluginMap_SaveMacroblock_MSMethod` @ `140f9ac30`).
It appears in the Openplanet API dump (`tm-scripts/OpenplanetNext.json` →
`ns/Game/CGameEditorPluginMap/m[139]`, `"m": 1` like every other MS member).

**Callability from Openplanet plugins is effectively proven**: E++ already calls the sibling MS
method `pmt.SaveMap(fileName)` (`tm-editor-plus-plus/src/Editor/Map.as:82`). `SaveMacroblock` has
the same shape (public method on the same class, `m:1`), so `pmt.SaveMacroblock(mb)` should bind
the same way. Needs a live smoke test (see "Open questions").

## The save pipeline (RE'd)

### 1. MS entry: `EditorPluginMap_SaveMacroblock_MSMethod` @ 140f9ac30
- Pulls the last typed script-call argument, must be a nod of class `CGameCtnMacroBlockInfo`
  (class-id checked via `FUN_140ba9e70`; mismatch logs `"Parameter is not a CGameCtnMacroBlockInfo."`).
- Calls `EditorPluginMap_SaveMacroblock_Entry` @ 140f9acf0: sets `pmt+0xdd0 = mb`
  ("current save macroblock" slot), then → `EditorPluginMap_SaveMacroblock_Impl`.

### 2. Impl: `EditorPluginMap_SaveMacroblock_Impl` @ 140fbe9f0
Args `(pmt, nameStr, descStr, pathStr?)`:
- Writes name → `mb+0x28`, description → `mb+0x38` and a second string at `mb+0x58`.
- Calls `MacroBlock_SaveToFid_WithAutoName(pmt, mb)` (the core).
- On success: `EditorInventory_TreeInsertOrUpdate(pmt+0x620, &name, 0, 2, 0, 0xb)`
  (inventory tree entry for the new name) and clears `pmt+0xdd0`.

### 3. Core writer: `MacroBlock_SaveToFid_WithAutoName` @ 140fbe800
1. Saves `mb->Fid` (`mb+0x28`) to stack, then sets it to `0xFFFFFFFF` (forces re-resolution).
2. Builds filename: string at `mb+0x28` (the name) + `".Macroblock.Gbx"` (`141c2d708`).
3. `FUN_140924760(DAT_141fbbf58 /*system fids root*/ +0x278, 0x16, &path, 1)` → creates/finds
   target **Fid** for user dir class **0x16 = MacroBlocks** (`Documents/Trackmania/MacroBlocks/`).
   If the Fid already points at a different nod (overwrite), old nod is detached (`FUN_1408fb560`).
4. `GbxArchive_SerializeNodToFid(fid, mb, 10)` — writes the GBX file (10 = serialization
   purpose/flags, passed through to `GbxArchive_SerializeNodConfigured`).
5. Restores `mb->Fid`.
6. On success (and old-nod ≠ new): `InventoryMgr_AddOrRefreshEntry_ByFid(DAT_141fbc828, fid,
   DAT_141fbbf58, 0x16)` → inventory entry; then `EditorPluginMap_OnInventoryAdded(pmt, entry+0x20)`.

### 4. Inventory pickup: `EditorPluginMap_OnInventoryAdded` @ 140fc0290
- If the new entry's class id equals the environment class id →
  `EditorPluginMap_OnInventoryAdded_RefreshAll(pmt, 1)` @ 140fc02c0 → for each sub-editor calls
  `CGameEditorPluginMap::FillMacroblockModels` @ 140f8fe00, which re-queries the inventory
  manager for class `0x310d000` (CGameCtnMacroBlockInfo family) and **rebuilds
  `pmt.MacroblockModels`**. That is exactly the array our `SelectMacroblockModel` /
  `InspectMacroblockModel` / `ListMacroblockInstances` tools already read.

So: save once via the MS method → file on disk + inventory entry + `MacroblockModels` refresh all
happen inside the engine. No manual file writing, no manual tree surgery.

## Directory ids (file dialog setter `CGameFileDialog_SetFileType_MSSetting` @ 1411dfd90)
| enum | ext | dirId |
|---|---|---|
| Map | `.Map.Gbx` | 0x0 |
| Item | `.Item.Gbx` | 0x19 |
| **Macroblock** | **`.Macroblock.Gbx`** | **0x16** |
| Script | `.Script.txt` | 0x15 |
| Pack | `.Pack.Gbx` | 0x17 |

User dir 0x16 lands in `Documents/Trackmania/MacroBlocks/` (folder auto-created on first save;
didn't exist yet on the local install).

## Content-installer path (for completeness)
`ContentInstaller_Install_Zip_Entry` @ 140b24900 handles ZIP pack installs
(`install_item` / `install_block` / `install_macroblock` / `install_pack` / `install_script`);
`install_macroblock` uses class 0x16 + `.Macroblock.Gbx` → `FUN_140b26880`. Not needed for our
use case (in-process save), but relevant if we ever want to import `.Macroblock.Gbx` files a user
drops on disk.

## Game-script usage (proof the method is the "real" save)
`tm-scripts/.../TMConsole/MapEditor/Macroblock.Script.txt:837` — `SaveMetadata()` calls
`SaveMacroblock(_MacroblockModel)` (gamepad editor flow). The PC editor UI flow
(`FUN_140ea8fb0`, title "Save macroblock") additionally sets up a snap-camera thumbnail scene
before calling the same `EditorPluginMap_SaveMacroblock_Impl`. **The thumbnail is UI-only — the
MS method path skips it entirely** (that's why saved-via-script MBs have no custom icon, they get
the default). Also note the game script stores `K_GamepadEditorMetadata` via `SetMetadata` —
irrelevant for the PC inventory picker.

## Proposed plugin flow (tm-mcp-pack-epp once E++#39 ships)

```
1. MacroblockRecorder::StartRecording()          (E++ export, issue #39)
2. ... place blocks/items via existing tools ...
3. MacroblockRecorder::StopRecording(false)      → recordedMB in E++, ends up as
                                                    editor.CopyPasteMacroBlockInfo
4. pmt.SaveMacroblock(mb)                        ← direct MS call, no dialog
   (mb = editor.CopyPasteMacroBlockInfo or recorder's GetRecordingMB-derived nod)
5. Verify: pmt.MacroblockModels grew / ListSavedNamedMacroblocks-style check,
   file exists under Documents/Trackmania/MacroBlocks/
```

Naming: `SaveMacroblock` uses the **name string at mb+0x28** for the filename. E++ recorder's
`MacroblockSpecPriv` has a `Name`-ish field only when constructing via its own flow; we may need
to set `mb.Name` (MwId-based `Name` + `IdName`) before saving — verify what the name field
actually is on the wire (`name`/`nameId` pair per E++ `Macroblocks.xtoml`).

## Open questions / next RE steps
1. **Live smoke**: does `pmt.SaveMacroblock(mb)` bind from AngelScript? (Expect yes, cf. SaveMap.)
2. Where exactly does the *display name* come from — `mb+0x28` is used both as filename stem and
   (probably) inventory display name. The `CGameCtnMacroBlockInfo::Name` property is an MwId
   (`name`/`nameId` in E++ xtoml) — confirm OP can set it (write to `.Name` via the class prop).
3. `EditorInventory_TreeInsertOrUpdate` arg `0xb` — probably "root category: macroblocks" id;
   fine to leave as the engine handles it.
4. Overwrite semantics: same-name save replaces the file (old nod detached) — verify the
   inventory entry refreshes rather than dupes (the RefreshAll path suggests it rebuilds fully).

## Session access (for next time)
- Ghidra GUI + ghidra-mcp plugin run on **x-left**; project `~/re/tm2020-headless/tm2020-headless.gpr`
  with Trackmania.exe + TrackmaniaServer loaded.
- HTTP endpoint binds 127.0.0.1 on 8089 or first free fallback (check
  `GET /mcp/instance_info`, field `tcp_port`); currently **18742**.
- From this box: `ssh -N -L 18089:127.0.0.1:<tcp_port> x-left` then plain HTTP to
  `http://127.0.0.1:18089` (endpoints at root, e.g. `/search_functions?name_pattern=…`,
  `/decompile_function?address=…`, `/rename_function_by_address`, `/set_plate_comment`).
- Schema: `GET /mcp/schema` (222 tools). Client helper: `/tmp/re_lib.py` (recreate if gone).
- Save-all after a session: `POST /save_all_programs` — do this before closing Ghidra.

## Renamed/commented functions (this session)
| addr | name |
|---|---|
| 140f9ac30 | EditorPluginMap_SaveMacroblock_MSMethod |
| 140f9acf0 | EditorPluginMap_SaveMacroblock_Entry |
| 140fbe9f0 | EditorPluginMap_SaveMacroblock_Impl |
| 140fbe800 | MacroBlock_SaveToFid_WithAutoName |
| 140fbeae0 | EditorPluginMap_FinishSaveCurrentMacroblock |
| 140fbeac0 | EditorPluginMap_SetCurrentSaveMacroblock |
| 140f8fe00 | CGameEditorPluginMap_FillMacroblockModels |
| 140fc02c0 | EditorPluginMap_OnInventoryAdded_RefreshAll |
| 140fc0290 | EditorPluginMap_OnInventoryAdded |
| 1411dfd90 | CGameFileDialog_SetFileType_MSSetting |
| 140b24900 | ContentInstaller_Install_Zip_Entry |
| 140be14d0 | InventoryMgr_AddOrRefreshEntry_ByFid |
| 140fb4440 | EditorInventory_TreeInsertOrUpdate |
