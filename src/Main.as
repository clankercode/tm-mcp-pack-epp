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
        if (name == "FindInventory") return FindInventory(input);
        if (name == "RefreshInventory") return RefreshInventory(input);
        if (name == "GetInventorySummary") return GetInventorySummary(input);
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
        Add(b, "PlaceBlock", "E++ PlaceBlocks freeblock. input: blockName,x,y,z optional pitch/yaw/roll/variant/addUndo/autofocus.", '{"type":"object","properties":{"blockName":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"variant":{"type":"integer"},"addUndo":{"type":"boolean"},"autofocus":{"type":"boolean"}},"required":["blockName","x","y","z"],"additionalProperties":false}');
        Add(b, "PlaceItem", "E++ PlaceItems. input: itemPath,x,y,z optional pitch/yaw/roll/addUndo.", '{"type":"object","properties":{"itemPath":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"pitch":{"type":"number"},"yaw":{"type":"number"},"roll":{"type":"number"},"addUndo":{"type":"boolean"}},"required":["itemPath","x","y","z"],"additionalProperties":false}');
        Add(b, "DeleteRecentBlocks", "E++ DeleteBlocks on the last N map blocks.", '{"type":"object","properties":{"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "DeleteRecentItems", "E++ DeleteItems on the last N anchored items.", '{"type":"object","properties":{"count":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "FindInventory", "Search E++ item inventory cache.", '{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer"}},"additionalProperties":false}');
        Add(b, "RefreshInventory", "Refresh E++ inventory cache.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "GetInventorySummary", "E++ inventory item count + scan flag.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "FocusCamera", "E++ SetCamAnimationGoTo looking at x,y,z.", '{"type":"object","properties":{"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"distance":{"type":"number"}},"required":["x","y","z"],"additionalProperties":false}');
        Add(b, "SetCamGoTo", "E++ SetCamAnimationGoTo with h/v look angles.", '{"type":"object","properties":{"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"h":{"type":"number"},"v":{"type":"number"},"distance":{"type":"number"}},"required":["x","y","z"],"additionalProperties":false}');
        Add(b, "ControlMapObjectives", "E++ get/set clones and laps. action=get|set.", '{"type":"object","properties":{"action":{"type":"string"},"nbClones":{"type":"integer"},"nbLaps":{"type":"integer"},"isLapRace":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ControlEditMode", "E++ get/set editMode and placeMode.", '{"type":"object","properties":{"action":{"type":"string"},"editMode":{"type":"string"},"placeMode":{"type":"string"}},"additionalProperties":false}');
        Add(b, "GetEditorSelectionState", "Current block/item/mb selection + gizmo + picked block.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "SelectBlock", "E++ SetSelectedBlockInfo by blockName.", '{"type":"object","properties":{"blockName":{"type":"string"}},"required":["blockName"],"additionalProperties":false}');
        Add(b, "SelectItem", "Set CurrentItemModel from inventory path and switch to item place mode.", '{"type":"object","properties":{"itemPath":{"type":"string"}},"required":["itemPath"],"additionalProperties":false}');
        Add(b, "SetAirMode", "E++ Get/SetIsBlockAirModeActive.", '{"type":"object","properties":{"active":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "ControlItemEditor", "E++ item editor: action=state|open|save|leave|nullifyEME.", '{"type":"object","properties":{"action":{"type":"string"},"itemPath":{"type":"string"},"notify":{"type":"boolean"}},"additionalProperties":false}');
        Add(b, "GetBlockLocation", "E++ IsBlockFree + GetBlockLocation for map block index.", '{"type":"object","properties":{"index":{"type":"integer"}},"required":["index"],"additionalProperties":false}');
        Add(b, "CoordConvert", "E++ CoordToPos / PosToCoord. action=coordToPos|posToCoord.", '{"type":"object","properties":{"action":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"}},"required":["x","y","z"],"additionalProperties":false}');
        Add(b, "GetNodPointer", "E++ GetNodPointer of the current map.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "RefreshMapCache", "E++ RefreshMapCacheSoon + IsMapCacheStale.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "IsGizmoActive", "E++ IsGizmoActive.", '{"type":"object","properties":{},"additionalProperties":false}');
        Add(b, "RunGizmoApplyBlock", "E++ Dev_RunGizmoApplyBlock.", '{"type":"object","properties":{"blockName":{"type":"string"},"x":{"type":"number"},"y":{"type":"number"},"z":{"type":"number"},"variant":{"type":"integer"}},"required":["blockName","x","y","z"],"additionalProperties":false}');
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
