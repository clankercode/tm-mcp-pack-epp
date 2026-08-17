string g_PackId = "";

void Main() { TmMcpPackEpp::RegisterPack(); }
void OnEnabled() { TmMcpPackEpp::RegisterPack(); }
void OnDisabled() { TmMcpPackEpp::UnregisterPack(); }
void OnDestroyed() { TmMcpPackEpp::UnregisterPack(); }

namespace TmMcpPackEpp {
    Json::Value@ Dispatch(const string &in name, Json::Value &in input) {
        if (name == "Ping") return Ping(input);
        if (name == "PlaceBlock") return PlaceBlock(input);
        if (name == "PlaceItem") return PlaceItem(input);
        if (name == "DeleteRecentBlocks") return DeleteRecentBlocks(input);
        if (name == "DeleteRecentItems") return DeleteRecentItems(input);
        if (name == "PlaceBlocksAndItems") return PlaceBlocksAndItems(input);
        if (name == "DeleteBlocksAndItems") return DeleteBlocksAndItems(input);
        if (name == "ConvertBlockToFree") return ConvertBlockToFree(input);
        if (name == "GetMapAsMacroblock") return GetMapAsMacroblock(input);
        if (name == "GetMapTerrainGrid") return GetMapTerrainGrid(input);
        if (name == "PlaceMacroblockModelNative") return PlaceMacroblockModelNative(input);
        if (name == "PlaceMacroblockModelViaEppSpec") return PlaceMacroblockModelViaEppSpec(input);
        if (name == "SetMacroblockAutoTerrainLen") return SetMacroblockAutoTerrainLen(input);
        if (name == "SetMapEmbeddedColors") return SetMapEmbeddedColors(input);
        if (name == "ControlItemSkins") return ControlItemSkins(input);
        if (name == "ControlPlacementMode") return ControlPlacementMode(input);
        if (name == "ControlPivot") return ControlPivot(input);
        if (name == "FindInventory") return FindInventory(input);
        if (name == "RefreshInventory") return RefreshInventory(input);
        if (name == "GetInventorySummary") return GetInventorySummary(input);
        if (name == "ControlInventory") return ControlInventory(input);
        if (name == "FocusCamera") return FocusCamera(input);
        if (name == "MoveCursorToWorld") return MoveCursorToWorld(input);
        if (name == "SetCamGoTo") return SetCamGoTo(input);
        if (name == "ControlMapObjectives") return ControlMapObjectives(input);
        if (name == "ControlEditMode") return ControlEditMode(input);
        if (name == "GetEditorSelectionState") return GetEditorSelectionState(input);
        if (name == "SelectBlock") return SelectBlock(input);
        if (name == "SelectItem") return SelectItem(input);
        if (name == "SetAirMode") return SetAirMode(input);
        if (name == "ControlItemEditor") return ControlItemEditor(input);
        if (name == "GetBlockLocation") return GetBlockLocation(input);
        if (name == "CoordConvert") return CoordConvert(input);
        if (name == "GetNodPointer") return GetNodPointer(input);
        if (name == "RefreshMapCache") return RefreshMapCache(input);
        if (name == "IsGizmoActive") return IsGizmoActiveTool(input);
        if (name == "RunGizmoApplyBlock") return RunGizmoApplyBlock(input);
        if (name == "SelectBlockModel") return SelectBlockModel(input);
        if (name == "SetCursorBlock") return SetCursorBlock(input);
        if (name == "SelectItemModel") return SelectItemModel(input);
        if (name == "SelectMacroblockModel") return SelectMacroblockModel(input);
        if (name == "CreateNamedMacroblock") return CreateNamedMacroblock(input);
        if (name == "ListNamedMacroblocks") return ListNamedMacroblocks(input);
        if (name == "GetNamedMacroblock") return GetNamedMacroblockTool(input);
        if (name == "ClearNamedMacroblock") return ClearNamedMacroblock(input);
        if (name == "AddBlockToNamedMacroblock") return AddBlockToNamedMacroblock(input);
        if (name == "AddBlocksToNamedMacroblock") return AddBlocksToNamedMacroblock(input);
        if (name == "AddItemToNamedMacroblock") return AddItemToNamedMacroblock(input);
        if (name == "AddItemsToNamedMacroblock") return AddItemsToNamedMacroblock(input);
        if (name == "PlaceNamedMacroblock") return PlaceNamedMacroblock(input);
        if (name == "PreflightNamedMacroblockPlacement") return PreflightNamedMacroblockPlacement(input);
        if (name == "SaveNamedMacroblock") return SaveNamedMacroblock(input);
        if (name == "LoadNamedMacroblock") return LoadNamedMacroblock(input);
        if (name == "SaveMacroblockFile") return SaveMacroblockFile(input);
        if (name == "GetDialog") return GetDialog(input);
        if (name == "RespondDialog") return RespondDialog(input);
        if (name == "SummarizeMap") return SummarizeMap(input);
        if (name == "ZoomRegion") return ZoomRegion(input);
        if (name == "CheckCheckpoints") return CheckCheckpoints(input);
        if (name == "ImportMacroblockModelToNamed") return ImportMacroblockModelToNamed(input);
        if (name == "ListSavedNamedMacroblocks") return ListSavedNamedMacroblocks(input);
        if (name == "RemoveBlocksByIndex") return RemoveBlocksByIndex(input);
        if (name == "RemoveItemsByIndex") return RemoveItemsByIndex(input);
        if (name == "InspectMacroblockModel") return InspectMacroblockModel(input);
        if (name == "ControlMacroblockRecorder") return ControlMacroblockRecorder(input);
        if (name == "GetRecordedMacroblockSpec") return GetRecordedMacroblockSpec(input);
        if (name == "DismissDialogs") return DismissDialogs(input);
        if (name == "ListMacroblockInstances") return ListMacroblockInstances(input);
        if (name == "SetAgentTag") return SetAgentTag(input);
        if (name == "ListTagged") return ListTagged(input);
        if (name == "RemoveByTag") return RemoveByTag(input);
        if (name == "ClearTagIndex") return ClearTagIndex(input);
        if (name == "AssertPlacement") return AssertPlacement(input);
        if (name == "GetBlockConnections") return GetBlockConnections(input);
        if (name == "FindConnectingBlocks") return FindConnectingBlocks(input);
        if (name == "PlaceGridBlock") return PlaceGridBlock(input);
        if (name == "ListCoverage") return ListCoverage(input);
        return Err("unknown pack tool: " + name, "unknown_tool");
    }

    void Add(TmMcp::ToolPackBuilder@ b, const string &in name, const string &in desc, const string &in schema) {
        b.AddTool(name, desc, schema);
    }

    void RegisterPack() {
        auto plugin = Meta::ExecutingPlugin();
        if (plugin is null) {
            warn("tm-mcp-pack-epp: no executing plugin");
            return;
        }
        g_PackId = plugin.ID;
        auto b = TmMcp::ToolPackBuilder();
        Add(b, "Ping", "Pack liveness.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "PlaceBlock", "E++ PlaceBlocks freeblock. blockName,x,y,z (world meters; on-grid stadium spans roughly +/-768m XZ, ground top y=8); optional pitch/yaw/roll/variant/addUndo/autofocus/tag. Freshly placed free blocks delete only via RemoveByTag/RemoveBlocksByIndex (plain engine delete no-ops).", '{"type":"object","properties":{"blockName":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"variant":{"type":"integer"},"addUndo":{"type":"boolean"},"autofocus":{"type":"boolean"},"tag":{"type":"string"}},"required":["blockName","x","y","z"],"additionalProperties":false}');
        Add(b, "PlaceItem", "E++ PlaceItems. itemPath,x,y,z (world meters; ground top y=8); optional pitch/yaw/roll/addUndo/autofocus/tag.", '{"type":"object","properties":{"itemPath":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"addUndo":{"type":"boolean"},"autofocus":{"type":"boolean"},"tag":{"type":"string"}},"required":["itemPath","x","y","z"],"additionalProperties":false}');
        Add(b, "DeleteRecentBlocks", "E++ DeleteBlocks on the last N map blocks.", '{"type":"object","properties":{"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "DeleteRecentItems", "E++ DeleteItems on the last N anchored items.", '{"type":"object","properties":{"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "PlaceBlocksAndItems", "E++ batch place: blocks[] + items[] in one call.", '{"type":"object","properties":{"blocks":{"type":"array"},"items":{"type":"array"},"addUndo":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "DeleteBlocksAndItems", "E++ batch delete by blockIndexes[]/itemIndexes[].", '{"type":"object","properties":{"blockIndexes":{"type":"array"},"itemIndexes":{"type":"array"},"addUndo":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ConvertBlockToFree", "E++ ConvertBlockToFree by block index.", '{"type":"object","properties":{"index":{"type":"integer"}},"required":["index"],"additionalProperties":false}');
        Add(b, "GetMapAsMacroblock", "E++ GetMapAsMacroblock block/item/skin counts.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "SetMacroblockAutoTerrainLen", "DEV probe: set AutoTerrains length on generated ground variant (which=variant, +0x258) or macroblock buf (which=mb, +0x200). Params: name|path|index, which, value. Restore manually after probing.", '{"type":"object","properties":{"name":{"type":"string"},"path":{"type":"string"},"index":{"type":"integer"},"which":{"type":"string"},"value":{"type":"integer"}},"required":["value"],"additionalProperties":false}');
        Add(b, "PlaceMacroblockModelNative", "Native (non-E++-donor) macroblock placement ground truth: resolves model by name/path/index and calls pmt.PlaceMacroblock / PlaceMacroblock_NoTerrain / PlaceMacroblock_AirMode. Params: name|path|index, x,y,z (block coord), mode=ground|noTerrain|air, force.", '{"type":"object","properties":{"name":{"type":"string"},"path":{"type":"string"},"index":{"type":"integer"},"x":{"type":"integer"},"y":{"type":"integer"},"z":{"type":"integer"},"mode":{"type":"string"},"force":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "GetMapTerrainGrid", "Raw map terrain genealogy grid dump (CGameCtnChallenge+0x390, one CGameCtnZoneGenealogy per XZ cell). Optional x/z/w/h window (default 0/0/4/4).", '{"type":"object","properties":{"x":{"type":"integer"},"z":{"type":"integer"},"w":{"type":"integer"},"h":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "PlaceMacroblockModelViaEppSpec", "E++ donor-path placement test: builds an E++ MacroblockSpec from a native model (terrain captured from mb+0x1F8) and places via Editor::PlaceMacroblock (air blocks/items pass + ground terrain pass). Params: name|path|index.", '{"type":"object","properties":{"name":{"type":"string"},"path":{"type":"string"},"index":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "SetMapEmbeddedColors", "E++ Get/Set_Map_EmbeddedCustomColorsEncoded. action=get|set.", '{"type":"object","properties":{"action":{"type":"string"},"raw":{"type":"string"}},"additionalProperties":false}');
        Add(b, "ControlItemSkins", "E++ Get/SetItemSkinsRaw for item index. action=get|set.", '{"type":"object","properties":{"action":{"type":"string"},"index":{"type":"integer"},"fgSkin":{"type":"string"},"bgSkin":{"type":"string"}},"required":["index"],"additionalProperties":false}');
        Add(b, "ControlPlacementMode", "E++ Get/SetItemPlacementModeInt (0 None, 1 Normal, 2 FreeGround, 3 Free).", '{"type":"object","properties":{"action":{"type":"string"},"mode":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "ControlPivot", "E++ Get/SetCurrentPivot.", '{"type":"object","properties":{"action":{"type":"string"},"pivot":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "FindInventory", "Search E++ item inventory cache.", '{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "RefreshInventory", "Refresh E++ inventory cache.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "GetInventorySummary", "E++ inventory item count + scan flag.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "ControlInventory", "Editor inventory browse/select (E++ IInvCache).", '{"type":"object","properties":{"action":{"type":"string"},"type":{"type":"string"},"query":{"type":"string"},"path":{"type":"string"},"name":{"type":"string"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "MoveCursorToWorld", "Move the editor cursor to a world position (E++ SetAllCursorPos). Useful to show which block/spot is being inspected.", '{"type":"object","properties":{"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"}},"required":["x","y","z"],"additionalProperties":false}');
        Add(b, "FocusCamera", "E++ SetCamAnimationGoTo looking at x,y,z.", '{"type":"object","properties":{"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"distance":{"type":"number"}},"required":["x","y","z"],"additionalProperties":false}');
        Add(b, "SetCamGoTo", "E++ SetCamAnimationGoTo with h/v look angles.", '{"type":"object","properties":{"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"h":{"type":"number"},"v":{"type":"number"},"distance":{"type":"number"}},"required":["x","y","z"],"additionalProperties":false}');
        Add(b, "ControlMapObjectives", "E++ get/set clones and laps. action=get|set.", '{"type":"object","properties":{"action":{"type":"string"},"nbClones":{"type":"integer"},"nbLaps":{"type":"integer"},"isLapRace":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ControlEditMode", "E++ get/set editMode and placeMode.", '{"type":"object","properties":{"action":{"type":"string"},"editMode":{"type":"string"},"placeMode":{"type":"string"}},"additionalProperties":false}');
        Add(b, "GetEditorSelectionState", "Current block/item/mb selection + gizmo + picked block.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "SelectBlock", "E++ SetSelectedBlockInfo by blockName.", '{"type":"object","properties":{"blockName":{"type":"string"}},"required":["blockName"],"additionalProperties":false}');
        Add(b, "SelectItem", "Enter Item place mode for an inventory path.", '{"type":"object","properties":{"itemPath":{"type":"string"}},"required":["itemPath"],"additionalProperties":false}');
        Add(b, "SetAirMode", "E++ Get/SetIsBlockAirModeActive.", '{"type":"object","properties":{"active":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ControlItemEditor", "E++ item editor: action=state|open|save|leave|nullifyEME.", '{"type":"object","properties":{"action":{"type":"string"},"itemPath":{"type":"string"},"notify":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "GetBlockLocation", "E++ IsBlockFree + GetBlockLocation for map block index.", '{"type":"object","properties":{"index":{"type":"integer"}},"required":["index"],"additionalProperties":false}');
        Add(b, "CoordConvert", "E++ CoordToPos / PosToCoord. action=coordToPos|posToCoord.", '{"type":"object","properties":{"action":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"}},"required":["x","y","z"],"additionalProperties":false}');
        Add(b, "GetNodPointer", "E++ GetNodPointer of the current map.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "RefreshMapCache", "E++ RefreshMapCacheSoon + IsMapCacheStale.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "IsGizmoActive", "E++ IsGizmoActive.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "RunGizmoApplyBlock", "E++ Dev_RunGizmoApplyBlock.", '{"type":"object","properties":{"blockName":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"variant":{"type":"integer"}},"required":["blockName","x","y","z"],"additionalProperties":false}');
        Add(b, "SelectBlockModel", "Select a block model in the editor picker.", '{"type":"object","properties":{"blockName":{"type":"string"}},"required":["blockName"],"additionalProperties":false}');
        Add(b, "SetCursorBlock", "Alias of SelectBlockModel.", '{"type":"object","properties":{"blockName":{"type":"string"}},"required":["blockName"],"additionalProperties":false}');
        Add(b, "SelectItemModel", "Select item model in editor picker (inventory SelectArticle when found).", '{"type":"object","properties":{"itemPath":{"type":"string"},"path":{"type":"string"}},"additionalProperties":false}');
        Add(b, "SelectMacroblockModel", "Select macroblock model by name.", '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "CreateNamedMacroblock", "Create an empty named macroblock.", '{"type":"object","properties":{"name":{"type":"string"},"replace":{"type":"boolean"}},"required":["name"],"additionalProperties":false}');
        Add(b, "ListNamedMacroblocks", "List named macroblocks.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "GetNamedMacroblock", "Get named macroblock spec JSON.", '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "ClearNamedMacroblock", "Clear a named macroblock's contents.", '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "AddBlockToNamedMacroblock", "Add one block to a named macroblock.", '{"type":"object","properties":{"name":{"type":"string"},"blockName":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"variant":{"type":"integer"},"create":{"type":"boolean"}},"required":["name","blockName","x","y","z"],"additionalProperties":false}');
        Add(b, "AddBlocksToNamedMacroblock", "Add blocks[] to a named macroblock in one call.", '{"type":"object","properties":{"name":{"type":"string"},"blocks":{"type":"array"},"create":{"type":"boolean"}},"required":["name","blocks"],"additionalProperties":false}');
        Add(b, "AddItemToNamedMacroblock", "Add one item to a named macroblock.", '{"type":"object","properties":{"name":{"type":"string"},"itemPath":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"create":{"type":"boolean"}},"required":["name","itemPath","x","y","z"],"additionalProperties":false}');
        Add(b, "AddItemsToNamedMacroblock", "Add items[] to a named macroblock in one call.", '{"type":"object","properties":{"name":{"type":"string"},"items":{"type":"array"},"create":{"type":"boolean"}},"required":["name","items"],"additionalProperties":false}');
        Add(b, "PlaceNamedMacroblock", "Place a named macroblock: x/y/z is the world pos where the spec's LOWEST content lands (min internalPos anchor). Optional offset/pivot/rotation/tag/autofocus/addUndo. Returns placedBlocks/placedItems + placedBounds + overlap warnings. Imported stock grid models derive layout from coord; saved/authored models keep their authored pos.", '{"type":"object","properties":{"name":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"pivotX":{"type":"number"},"pivotY":{"type":"number"},"pivotZ":{"type":"number"},"autofocus":{"type":"boolean"},"addUndo":{"type":"boolean"},"tag":{"type":"string"}},"required":["name","x","y","z"],"additionalProperties":false}');
        Add(b, "PreflightNamedMacroblockPlacement", "Dry-run placement checks for a named macroblock.", '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "SaveNamedMacroblock", "Persist a named macroblock spec to plugin data.", '{"type":"object","properties":{"name":{"type":"string"},"fileName":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "DismissDialogs", "Dismiss any modal dialog currently blocking editor automation (engine HideDialogs). For interactive decisions use GetDialog + RespondDialog instead.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "GetDialog", "Inspect the current blocking dialog (no side effects): type, frame id, message text, and how to respond. Covers engine message/yes-no dialogs (incl. overwrite prompts) and the save-as frame.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "RespondDialog", "Answer the currently open dialog: yes/no/cancel (yes-no prompts, e.g. overwrite confirmation), ok (message dialogs), confirmSaveAs/cancelSaveAs (save-as frame). Poll GetDialog first.", '{"type":"object","properties":{"respond":{"type":"string","enum":["yes","no","cancel","ok","confirmSaveAs","cancelSaveAs"]}},"required":["respond"],"additionalProperties":false}');
        Add(b, "SummarizeMap", "Compressed whole-map overview for agents: distinct block/item types with counts, bboxes, categories (terrain/road/building), anomaly notes (pillars = raised ground blocks, ghosts, free blocks), all in one small response instead of paging GetBlocks/GetItems (100 rows / ~18KB per call). Optional world-meter bounds (minX/maxX/minZ/maxZ), blocks/items toggles, maxRows cap. Each row carries an echo-able `query` object for ZoomRegion.", '{"type":"object","properties":{"blocks":{"type":"boolean"},"items":{"type":"boolean"},"maxRows":{"type":"integer"},"minX":{"type":"number"},"maxX":{"type":"number"},"minZ":{"type":"number"},"maxZ":{"type":"number"}},"additionalProperties":false}');
        Add(b, "ZoomRegion", "Drill into a region: list individual blocks/items by name-substring query and/or world-meter bounds (minX/maxX/minZ/maxZ), with limit. This is the zoom-in counterpart to SummarizeMap rows (echo their `query` object). Returns compact rows (index, name, coord, dir, isFree).", '{"type":"object","properties":{"blocks":{"type":"boolean"},"items":{"type":"boolean"},"query":{"type":"string"},"minX":{"type":"number"},"maxX":{"type":"number"},"minZ":{"type":"number"},"maxZ":{"type":"number"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "CheckCheckpoints", "Audit every checkpoint/start/finish: vehicle spawn position (block cell top / item anchor, world meters) and a static would-the-car-fall support check — scans the column below each spawn for the highest solid support (block/item) or engine ground, reports dropDist and grounded (support within fallTolerance meters, default 8). Also reports linkOrder and tag (LinkedCheckpoint). Static estimate, no simulation.", '{"type":"object","properties":{"fallTolerance":{"type":"number"}},"additionalProperties":false}');
        Add(b, "SaveMacroblockFile", "Save a native .Macroblock.Gbx (real game file; auto-appears in the macroblock inventory). Sources: recorder stop-transfer (recorder/copyPaste) or tagged live placements (tagged + tag). Drives the engine's own save UI flow (snap scene + save-as dialog), so the file lands where the game puts saved macroblocks (Documents/Trackmania/Blocks/<Collection>/). If the name already exists, an overwrite prompt is detected and left OPEN for you: the result carries overwritePrompt=true + message — decide via RespondDialog (yes/no/cancel), or pass overwrite=true to auto-confirm. If it fails with 'snap-camera scene did not open', the copy-paste selection is stale/consumed — record + stop a fresh selection and retry.", '{"type":"object","properties":{"name":{"type":"string"},"source":{"type":"string","enum":["recorder","copyPaste","tagged"]},"tag":{"type":"string"},"overwrite":{"type":"boolean"}},"required":["name"],"additionalProperties":false}');
        Add(b, "LoadNamedMacroblock", "Load a named macroblock spec from plugin data.", '{"type":"object","properties":{"name":{"type":"string"},"fileName":{"type":"string"},"replace":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ImportMacroblockModelToNamed", "Import a native macroblock model (by name/path/index; e.g. one saved by SaveMacroblockFile) into the named store as an E++ spec. Layout: saved/authored models keep their authored pos; stock inventory grid models derive pos from coord. Place via PlaceNamedMacroblock (min-pos anchor).", '{"type":"object","properties":{"name":{"type":"string"},"path":{"type":"string"},"index":{"type":"integer"},"asName":{"type":"string"},"replace":{"type":"boolean"}},"required":["asName"],"additionalProperties":false}');
        Add(b, "ListSavedNamedMacroblocks", "List saved named macroblock files.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "RemoveBlocksByIndex", "Delete map blocks by index (max 50).", '{"type":"object","properties":{"index":{"type":"integer"},"indices":{"type":"array"},"addUndo":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "RemoveItemsByIndex", "Delete anchored items by index (max 50).", '{"type":"object","properties":{"index":{"type":"integer"},"indices":{"type":"array"},"addUndo":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "InspectMacroblockModel", "Inspect a macroblock model by name, path, or index (counts + metadata).", '{"type":"object","properties":{"name":{"type":"string"},"path":{"type":"string"},"index":{"type":"integer"},"limit":{"type":"integer"},"includeItems":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ControlMacroblockRecorder", "Control the E++ macroblock recorder: start recording, stop (finish or cancel), resume, or get status. While recording, every block/item placed (or deleted) in the editor is captured. Stop with cancel=false completes it (async transfer to copy-paste MB; poll status until hasExisting). Note: a modal dialog stalls the transfer — status reports blockingDialog; DismissDialogs clears it. A stale transfer can wedge the recorder until the Editor plugin is reloaded.", '{"type":"object","properties":{"action":{"type":"string","enum":["start","stop","resume","status"]},"cancel":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "GetRecordedMacroblockSpec", "Snapshot the active (or completed, via resume) macroblock recording as counts, optionally storing it in the named store (asName) for PlaceNamedMacroblock. Spec pos are world-authored.", '{"type":"object","properties":{"asName":{"type":"string"},"replace":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ListMacroblockInstances", "List macroblock model instances in the map.", '{"type":"object","properties":{"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "SetAgentTag", "Set the tag used for subsequent placements.", '{"type":"object","properties":{"tag":{"type":"string"}},"required":["tag"],"additionalProperties":false}');
        Add(b, "ListTagged", "List tagged placements.", '{"type":"object","properties":{"tag":{"type":"string"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "RemoveByTag", "Delete tagged placements.", '{"type":"object","properties":{"tag":{"type":"string"}},"required":["tag"],"additionalProperties":false}');
        Add(b, "ClearTagIndex", "Clear the tag index.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "AssertPlacement", "Verify deltas / near{x,y,z} / tags after a place.", '{"type":"object","properties":{"expectBlocksDelta":{"type":"integer"},"expectItemsDelta":{"type":"integer"},"near":{"type":"object"},"tag":{"type":"string"},"tagMinCount":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "GetBlockConnections", "Engine connection options for an existing grid block: per candidate block model, the coords+dirs where it can attach (pmt.GetConnectResults). Pass index or coord; optional newBlockName/query to restrict candidates, fitsSpace to probe CanPlaceBlock per row, onlyPlaceable to hide canConnect=false rows. Road-family models report no clip connections.", '{"type":"object","properties":{"index":{"type":"integer"},"coord":{"type":"array"},"newBlockName":{"type":"string"},"query":{"type":"string"},"onlyPlaceable":{"type":"boolean"},"fitsSpace":{"type":"boolean"},"onGround":{"type":"boolean"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "FindConnectingBlocks", "What blocks can connect to a given block model: synthesizes a temp grid block in an empty corner, runs the engine connection query per candidate model, then deletes the temp block. Optional dir (default North), query filter, limit. Coords are relative to tempCoord (subtract for source-relative offsets).", '{"type":"object","properties":{"blockName":{"type":"string"},"dir":{"type":"string"},"query":{"type":"string"},"onlyPlaceable":{"type":"boolean"},"limit":{"type":"integer"}},"required":["blockName"],"additionalProperties":false}');
        Add(b, "PlaceGridBlock", "Place a normal grid-aligned (non-free) block via the engine: coord [x,y,z] block units (or x,y,z world meters), dir North/East/South/West, variant, onGround, noDestruction (default true = never overwrite), ghost. Pre-checks CanPlaceBlock and reports canPlace when refusing. This is the counterpart to free-block PlaceBlock.", '{"type":"object","properties":{"blockName":{"type":"string"},"coord":{"type":"array"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"dir":{"type":"string"},"variant":{"type":"integer"},"onGround":{"type":"boolean"},"noDestruction":{"type":"boolean"},"ghost":{"type":"boolean"},"autofocus":{"type":"boolean"},"tag":{"type":"string"}},"required":["blockName"],"additionalProperties":false}');
        Add(b, "ListCoverage", "List this pack's tools.", '{"type":"object","properties":{},"additionalProperties":false}');
        b.SetDispatch(Dispatch);
        auto r = TmMcp::RegisterToolPack(b);
        if (r !is null && r.HasKey("error") && string(r["error"]) == "pack 'tm-mcp-pack-epp' is already registered; UnregisterToolPack first") {
            // reload race: our own OnDestroyed may have run after the fresh Main().
            // Drop the stale entry and retry once.
            TmMcp::UnregisterToolPack("tm-mcp-pack-epp");
            r = TmMcp::RegisterToolPack(b);
        }
        if (r is null || !r.HasKey("success") || !bool(r["success"])) {
            string err = (r !is null && r.HasKey("error")) ? string(r["error"]) : "null";
            warn("tm-mcp-pack-epp register failed: " + err);
            return;
        }
        print("tm-mcp-pack-epp registered pack=" + g_PackId);
    }

    void UnregisterPack() {
        if (g_PackId.Length == 0) return;
        TmMcp::UnregisterToolPack(g_PackId);
        g_PackId = "";
    }
}
