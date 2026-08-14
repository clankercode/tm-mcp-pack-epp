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
        if (name == "SetMapEmbeddedColors") return SetMapEmbeddedColors(input);
        if (name == "ControlItemSkins") return ControlItemSkins(input);
        if (name == "ControlPlacementMode") return ControlPlacementMode(input);
        if (name == "ControlPivot") return ControlPivot(input);
        if (name == "DuplicateItem") return DuplicateItem(input);
        if (name == "FindInventory") return FindInventory(input);
        if (name == "RefreshInventory") return RefreshInventory(input);
        if (name == "GetInventorySummary") return GetInventorySummary(input);
        if (name == "ControlInventory") return ControlInventory(input);
        if (name == "FocusCamera") return FocusCamera(input);
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
        if (name == "ListSavedNamedMacroblocks") return ListSavedNamedMacroblocks(input);
        if (name == "RemoveBlocksByIndex") return RemoveBlocksByIndex(input);
        if (name == "RemoveItemsByIndex") return RemoveItemsByIndex(input);
        if (name == "InspectMacroblockModel") return InspectMacroblockModel(input);
        if (name == "ListMacroblockInstances") return ListMacroblockInstances(input);
        if (name == "SetAgentTag") return SetAgentTag(input);
        if (name == "ListTagged") return ListTagged(input);
        if (name == "RemoveByTag") return RemoveByTag(input);
        if (name == "ClearTagIndex") return ClearTagIndex(input);
        if (name == "AssertPlacement") return AssertPlacement(input);
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
        Add(b, "PlaceBlock", "E++ PlaceBlocks freeblock. blockName,x,y,z; optional pitch/yaw/roll/variant/addUndo/autofocus.", '{"type":"object","properties":{"blockName":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"variant":{"type":"integer"},"addUndo":{"type":"boolean"},"autofocus":{"type":"boolean"}},"required":["blockName","x","y","z"],"additionalProperties":false}');
        Add(b, "PlaceItem", "E++ PlaceItems. itemPath,x,y,z; optional pitch/yaw/roll/addUndo/autofocus.", '{"type":"object","properties":{"itemPath":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"addUndo":{"type":"boolean"},"autofocus":{"type":"boolean"}},"required":["itemPath","x","y","z"],"additionalProperties":false}');
        Add(b, "DeleteRecentBlocks", "E++ DeleteBlocks on the last N map blocks.", '{"type":"object","properties":{"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "DeleteRecentItems", "E++ DeleteItems on the last N anchored items.", '{"type":"object","properties":{"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "PlaceBlocksAndItems", "E++ batch place: blocks[] + items[] in one call.", '{"type":"object","properties":{"blocks":{"type":"array"},"items":{"type":"array"},"addUndo":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "DeleteBlocksAndItems", "E++ batch delete by blockIndexes[]/itemIndexes[].", '{"type":"object","properties":{"blockIndexes":{"type":"array"},"itemIndexes":{"type":"array"},"addUndo":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ConvertBlockToFree", "E++ ConvertBlockToFree by block index.", '{"type":"object","properties":{"index":{"type":"integer"}},"required":["index"],"additionalProperties":false}');
        Add(b, "GetMapAsMacroblock", "E++ GetMapAsMacroblock block/item/skin counts.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "SetMapEmbeddedColors", "E++ Get/Set_Map_EmbeddedCustomColorsEncoded. action=get|set.", '{"type":"object","properties":{"action":{"type":"string"},"raw":{"type":"string"}},"additionalProperties":false}');
        Add(b, "ControlItemSkins", "E++ Get/SetItemSkinsRaw for item index. action=get|set.", '{"type":"object","properties":{"action":{"type":"string"},"index":{"type":"integer"},"fgSkin":{"type":"string"},"bgSkin":{"type":"string"}},"required":["index"],"additionalProperties":false}');
        Add(b, "ControlPlacementMode", "E++ Get/SetItemPlacementModeInt (0 None, 1 Normal, 2 FreeGround, 3 Free).", '{"type":"object","properties":{"action":{"type":"string"},"mode":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "ControlPivot", "E++ Get/SetCurrentPivot.", '{"type":"object","properties":{"action":{"type":"string"},"pivot":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "DuplicateItem", "E++ DuplicateAndAddItem by item index.", '{"type":"object","properties":{"index":{"type":"integer"},"updateItems":{"type":"boolean"}},"required":["index"],"additionalProperties":false}');
        Add(b, "FindInventory", "Search E++ item inventory cache.", '{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "RefreshInventory", "Refresh E++ inventory cache.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "GetInventorySummary", "E++ inventory item count + scan flag.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "ControlInventory", "Editor inventory browse/select (E++ IInvCache).", '{"type":"object","properties":{"action":{"type":"string"},"type":{"type":"string"},"query":{"type":"string"},"path":{"type":"string"},"name":{"type":"string"},"limit":{"type":"integer"}},"additionalProperties":false}');
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
        Add(b, "PlaceNamedMacroblock", "Place a named macroblock with optional offset/rotation.", '{"type":"object","properties":{"name":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"pivotX":{"type":"number"},"pivotY":{"type":"number"},"pivotZ":{"type":"number"},"autofocus":{"type":"boolean"},"addUndo":{"type":"boolean"}},"required":["name","x","y","z"],"additionalProperties":false}');
        Add(b, "PreflightNamedMacroblockPlacement", "Dry-run placement checks for a named macroblock.", '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "SaveNamedMacroblock", "Persist a named macroblock spec to plugin data.", '{"type":"object","properties":{"name":{"type":"string"},"fileName":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "LoadNamedMacroblock", "Load a named macroblock spec from plugin data.", '{"type":"object","properties":{"name":{"type":"string"},"fileName":{"type":"string"},"replace":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ListSavedNamedMacroblocks", "List saved named macroblock files.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "RemoveBlocksByIndex", "Delete map blocks by index (max 50).", '{"type":"object","properties":{"indexes":{"type":"array"},"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "RemoveItemsByIndex", "Delete anchored items by index (max 50).", '{"type":"object","properties":{"indexes":{"type":"array"},"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "InspectMacroblockModel", "Inspect a macroblock model (counts + metadata).", '{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false}');
        Add(b, "ListMacroblockInstances", "List macroblock model instances in the map.", '{"type":"object","properties":{"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "SetAgentTag", "Set the tag used for subsequent placements.", '{"type":"object","properties":{"tag":{"type":"string"}},"required":["tag"],"additionalProperties":false}');
        Add(b, "ListTagged", "List tagged placements.", '{"type":"object","properties":{"tag":{"type":"string"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "RemoveByTag", "Delete tagged placements.", '{"type":"object","properties":{"tag":{"type":"string"}},"required":["tag"],"additionalProperties":false}');
        Add(b, "ClearTagIndex", "Clear the tag index.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "AssertPlacement", "Verify deltas / near{x,y,z} / tags after a place.", '{"type":"object","properties":{"expectBlocksDelta":{"type":"integer"},"expectItemsDelta":{"type":"integer"},"near":{"type":"object"},"tag":{"type":"string"},"tagMinCount":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "ListCoverage", "List this pack's tools.", '{"type":"object","properties":{},"additionalProperties":false}');
        b.SetDispatch(Dispatch);
        auto r = TmMcp::RegisterToolPack(b);
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
