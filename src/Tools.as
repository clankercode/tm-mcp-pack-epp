namespace TmMcpPackEpp {
    Json::Value@ Ping(Json::Value &in input) {
        auto o = Json::Object();
        o["pong"] = true;
        o["pack"] = "tm-mcp-pack-epp";
        return Ok(o);
    }

    Json::Value@ PlaceBlock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("blockName") || !input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) {
            return Err("missing blockName, x, y, z");
        }
        bool isTerrain = false;
        auto blockInfo = ResolveBlockModel(editor.PluginMapType, string(input["blockName"]), isTerrain);
        if (blockInfo is null) return Err("block not found: " + string(input["blockName"]));
        if (isTerrain) return Err("terrain models are not supported by E++ free-block placement");

        vec3 pos = JsonToVec3(input);
        vec3 rot = vec3(
            input.HasKey("pitch") ? float(input["pitch"]) : 0.0,
            input.HasKey("yaw") ? float(input["yaw"]) : 0.0,
            input.HasKey("roll") ? float(input["roll"]) : 0.0
        );
        bool addUndo = input.HasKey("addUndo") ? bool(input["addUndo"]) : true;
        auto spec = Editor::MakeBlockSpec(blockInfo, pos, rot);
        spec.SetFree();
        spec.isGround = false;
        spec.isGhost = false;
        if (input.HasKey("variant")) spec.variant = uint(int(input["variant"]));
        spec.EnsureValidVariant();
        Editor::BlockSpec@[] blocks;
        blocks.InsertLast(spec);
        uint before = editor.Challenge.Blocks.Length;
        bool placed = false;
        try { placed = Editor::PlaceBlocks(blocks, addUndo); } catch {
            return Err("PlaceBlocks threw: " + getExceptionInfo(), "epp_exception");
        }
        if (input.HasKey("autofocus") ? bool(input["autofocus"]) : true) {
            Editor::SetCamAnimationGoTo(Editor::DirToLookUv(vec3(0, -0.4, 1)), pos, 60.0);
        }
        auto o = Json::Object();
        o["placed"] = placed;
        o["beforeBlocks"] = int(before);
        o["afterBlocks"] = int(editor.Challenge.Blocks.Length);
        o["pos"] = Vec3ToJson(pos);
        o["blockName"] = string(blockInfo.IdName);
        o["map"] = MapSummary(editor);
        return Ok(o);
    }

    Json::Value@ PlaceItem(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("itemPath") || !input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) {
            return Err("missing itemPath, x, y, z");
        }
        auto model = Editor::GetInventoryItemModelByPath(string(input["itemPath"]));
        if (model is null) return Err("item not found: " + string(input["itemPath"]));
        vec3 pos = JsonToVec3(input);
        vec3 rot = vec3(
            input.HasKey("pitch") ? float(input["pitch"]) : 0.0,
            input.HasKey("yaw") ? float(input["yaw"]) : 0.0,
            input.HasKey("roll") ? float(input["roll"]) : 0.0
        );
        bool addUndo = input.HasKey("addUndo") ? bool(input["addUndo"]) : true;
        auto spec = Editor::MakeItemSpec(model, pos, rot);
        Editor::ItemSpec@[] items;
        items.InsertLast(spec);
        uint before = editor.Challenge.AnchoredObjects.Length;
        bool placed = false;
        try { placed = Editor::PlaceItems(items, addUndo); } catch {
            return Err("PlaceItems threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["placed"] = placed;
        o["beforeItems"] = int(before);
        o["afterItems"] = int(editor.Challenge.AnchoredObjects.Length);
        o["pos"] = Vec3ToJson(pos);
        o["itemPath"] = string(input["itemPath"]);
        o["map"] = MapSummary(editor);
        return Ok(o);
    }

    Json::Value@ DeleteRecentBlocks(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        int count = input.HasKey("count") ? int(input["count"]) : 1;
        if (count < 1) count = 1;
        auto blocks = editor.Challenge.Blocks;
        if (blocks.Length == 0) return Err("no blocks");
        CGameCtnBlock@[] toDel;
        uint start = blocks.Length > uint(count) ? blocks.Length - uint(count) : 0;
        for (uint i = start; i < blocks.Length; i++) {
            if (blocks[i] !is null) toDel.InsertLast(blocks[i]);
        }
        bool ok = false;
        try { ok = Editor::DeleteBlocks(toDel, true); } catch {
            return Err("DeleteBlocks threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["deleted"] = ok;
        o["requested"] = count;
        o["map"] = MapSummary(editor);
        return Ok(o);
    }

    Json::Value@ DeleteRecentItems(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        int count = input.HasKey("count") ? int(input["count"]) : 1;
        if (count < 1) count = 1;
        auto items = editor.Challenge.AnchoredObjects;
        if (items.Length == 0) return Err("no items");
        CGameCtnAnchoredObject@[] toDel;
        uint start = items.Length > uint(count) ? items.Length - uint(count) : 0;
        for (uint i = start; i < items.Length; i++) {
            if (items[i] !is null) toDel.InsertLast(items[i]);
        }
        bool ok = false;
        try { ok = Editor::DeleteItems(toDel, true); } catch {
            return Err("DeleteItems threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["deleted"] = ok;
        o["requested"] = count;
        o["map"] = MapSummary(editor);
        return Ok(o);
    }

    Json::Value@ FindInventory(Json::Value &in input) {
        string query = input.HasKey("query") ? string(input["query"]).ToLower() : "";
        int limit = input.HasKey("limit") ? int(input["limit"]) : 20;
        if (limit < 1) limit = 1;
        if (limit > 100) limit = 100;
        uint nb = Editor::GetInventoryNbItems();
        auto hits = Json::Array();
        for (uint i = 0; i < nb && int(hits.Length) < limit; i++) {
            string path = Editor::GetInventoryItemPath(i);
            string name = Editor::GetInventoryItemName(i);
            if (query.Length == 0 || path.ToLower().IndexOf(query) >= 0 || name.ToLower().IndexOf(query) >= 0) {
                auto h = Json::Object();
                h["index"] = int(i);
                h["name"] = name;
                h["path"] = path;
                hits.Add(h);
            }
        }
        auto o = Json::Object();
        o["query"] = query;
        o["nbItems"] = int(nb);
        o["scanning"] = Editor::IsInventoryScanningItems();
        o["hits"] = hits;
        o["count"] = int(hits.Length);
        return Ok(o);
    }

    Json::Value@ RefreshInventory(Json::Value &in input) {
        Editor::RefreshInventoryCache();
        auto o = Json::Object();
        o["nbItems"] = int(Editor::GetInventoryNbItems());
        o["scanning"] = Editor::IsInventoryScanningItems();
        return Ok(o);
    }

    Json::Value@ GetInventorySummary(Json::Value &in input) {
        auto o = Json::Object();
        o["nbItems"] = int(Editor::GetInventoryNbItems());
        o["scanning"] = Editor::IsInventoryScanningItems();
        return Ok(o);
    }

    Json::Value@ FocusCamera(Json::Value &in input) {
        if (!input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) {
            return Err("missing x, y, z");
        }
        vec3 pos = JsonToVec3(input);
        float dist = input.HasKey("distance") ? float(input["distance"]) : 60.0;
        bool ok = Editor::SetCamAnimationGoTo(Editor::DirToLookUv(vec3(0, -0.4, 1)), pos, dist);
        auto o = Json::Object();
        o["ok"] = ok;
        o["pos"] = Vec3ToJson(pos);
        o["distance"] = dist;
        return Ok(o);
    }

    Json::Value@ SetCamGoTo(Json::Value &in input) {
        if (!input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) {
            return Err("missing x, y, z");
        }
        vec3 pos = JsonToVec3(input);
        float h = input.HasKey("h") ? float(input["h"]) : 0.0;
        float v = input.HasKey("v") ? float(input["v"]) : 0.3;
        float dist = input.HasKey("distance") ? float(input["distance"]) : 60.0;
        bool ok = Editor::SetCamAnimationGoTo(vec2(h, v), pos, dist);
        auto o = Json::Object();
        o["ok"] = ok;
        o["pos"] = Vec3ToJson(pos);
        return Ok(o);
    }

    Json::Value@ ControlMapObjectives(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        auto map = editor.Challenge;
        string action = input.HasKey("action") ? string(input["action"]) : "get";
        if (action == "set") {
            if (input.HasKey("nbClones")) {
                Editor::SetMapNbClones(map, uint(Math::Clamp(int(input["nbClones"]), 0, 64)));
            }
            if (input.HasKey("isLapRace") || input.HasKey("nbLaps")) {
                bool isLap = input.HasKey("isLapRace") ? bool(input["isLapRace"]) : Editor::GetMapIsLapRace(map);
                uint laps = input.HasKey("nbLaps") ? uint(Math::Clamp(int(input["nbLaps"]), 0, 99)) : Editor::GetMapNbLaps(map);
                Editor::SetMapLapMode(map, isLap, laps);
            }
        }
        auto o = Json::Object();
        o["nbClones"] = int(Editor::GetMapNbClones(map));
        o["nbLaps"] = int(Editor::GetMapNbLaps(map));
        o["isLapRace"] = Editor::GetMapIsLapRace(map);
        return Ok(o);
    }

    Json::Value@ ControlEditMode(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null) return NeedEditor();
        string action = input.HasKey("action") ? string(input["action"]) : "get";
        if (action == "set") {
            if (input.HasKey("editMode")) {
                string s = string(input["editMode"]).ToLower();
                CGameEditorPluginMap::EditMode em = CGameEditorPluginMap::EditMode::Place;
                if (s == "freelook" || s == "free") em = CGameEditorPluginMap::EditMode::FreeLook;
                else if (s == "erase") em = CGameEditorPluginMap::EditMode::Erase;
                else if (s == "pick") em = CGameEditorPluginMap::EditMode::Pick;
                Editor::SetEditMode(editor, em);
            }
            if (input.HasKey("placeMode")) {
                string s = string(input["placeMode"]).ToLower();
                CGameEditorPluginMap::EPlaceMode pm = CGameEditorPluginMap::EPlaceMode::Block;
                if (s == "freeblock") pm = CGameEditorPluginMap::EPlaceMode::FreeBlock;
                else if (s == "item") pm = CGameEditorPluginMap::EPlaceMode::Item;
                else if (s == "macroblock") pm = CGameEditorPluginMap::EPlaceMode::Macroblock;
                else if (s == "ghostblock" || s == "ghost") pm = CGameEditorPluginMap::EPlaceMode::GhostBlock;
                else if (s == "freemacroblock") pm = CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
                Editor::SetPlacementMode(editor, pm);
            }
        }
        auto o = Json::Object();
        o["editMode"] = int(Editor::GetEditMode(editor));
        o["placeMode"] = int(Editor::GetPlacementMode(editor));
        o["isBlockPlacement"] = Editor::IsInBlockPlacementMode(editor, false);
        o["isFreeBlockPlacement"] = Editor::IsInFreeBlockPlacementMode(editor, false);
        o["isAnyItemPlacement"] = Editor::IsInAnyItemPlacementMode(editor, false);
        o["isMacroblockPlacement"] = Editor::IsInMacroblockPlacementMode(editor, false);
        o["isGizmoActive"] = Editor::IsGizmoActive();
        return Ok(o);
    }

    Json::Value@ GetEditorSelectionState(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null) return NeedEditor();
        auto o = Json::Object();
        o["isGizmoActive"] = Editor::IsGizmoActive();
        if (editor.CurrentBlockInfo !is null) {
            o["currentBlock"] = string(editor.CurrentBlockInfo.IdName);
        }
        if (editor.CurrentItemModel !is null) {
            o["currentItem"] = string(editor.CurrentItemModel.IdName);
        }
        if (editor.CurrentMacroBlockInfo !is null) {
            o["currentMacroblock"] = string(editor.CurrentMacroBlockInfo.IdName);
        }
        auto picked = Editor::GetPickedBlock();
        if (picked !is null && picked.BlockInfo !is null) {
            o["pickedBlock"] = string(picked.BlockInfo.IdName);
        }
        return Ok(o);
    }

    Json::Value@ SelectBlock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return NeedEditor();
        if (!input.HasKey("blockName")) return Err("missing blockName");
        bool isTerrain = false;
        auto info = ResolveBlockModel(editor.PluginMapType, string(input["blockName"]), isTerrain);
        if (info is null) return Err("block not found");
        Editor::SetSelectedBlockInfo(editor, info);
        auto o = Json::Object();
        o["blockName"] = string(info.IdName);
        return Ok(o);
    }

    Json::Value@ SelectItem(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null) return NeedEditor();
        if (!input.HasKey("itemPath")) return Err("missing itemPath");
        auto model = Editor::GetInventoryItemModelByPath(string(input["itemPath"]));
        if (model is null) return Err("item not found");
        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Item);
        auto o = Json::Object();
        o["item"] = string(model.IdName);
        o["method"] = "placeModeOnly";
        o["hint"] = "CurrentItemModel is read-only; use PlaceItem to place by path.";
        return Ok(o);
    }

    Json::Value@ SetAirMode(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null) return NeedEditor();
        if (input.HasKey("active")) {
            Editor::SetIsBlockAirModeActive(editor, bool(input["active"]));
        }
        auto o = Json::Object();
        o["active"] = Editor::GetIsBlockAirModeActive(editor);
        return Ok(o);
    }

    Json::Value@ ControlItemEditor(Json::Value &in input) {
        auto editor = GetEditor();
        string action = input.HasKey("action") ? string(input["action"]) : "state";
        if (action == "save") {
            Editor::SaveCurrentItemEditorItem();
            return Ok(Json::Object());
        }
        if (action == "leave") {
            Editor::LeaveCurrentItemEditor();
            return Ok(Json::Object());
        }
        if (action == "nullifyEME") {
            if (editor is null || editor.CurrentItemModel is null) return Err("no current item model");
            bool notify = input.HasKey("notify") ? bool(input["notify"]) : false;
            string err = Editor::NullifyItemModelEME(editor.CurrentItemModel, notify);
            if (err.Length > 0) return Err(err, "eme_failed");
            return Ok(Json::Object());
        }
        if (action == "open") {
            if (editor is null) return NeedEditor();
            if (!input.HasKey("itemPath")) return Err("missing itemPath");
            auto model = Editor::GetInventoryItemModelByPath(string(input["itemPath"]));
            if (model is null) return Err("item not found");
            Editor::OpenItemEditor(editor, model);
            auto o = Json::Object();
            o["opened"] = string(model.IdName);
            return Ok(o);
        }
        auto o = Json::Object();
        o["inMapEditor"] = editor !is null;
        return Ok(o);
    }

    Json::Value@ GetBlockLocation(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("index")) return Err("missing index");
        int idx = int(input["index"]);
        if (idx < 0 || uint(idx) >= editor.Challenge.Blocks.Length) return Err("index out of range");
        auto block = editor.Challenge.Blocks[uint(idx)];
        auto o = Json::Object();
        o["isFree"] = Editor::IsBlockFree(block);
        o["pos"] = Vec3ToJson(Editor::GetBlockLocation(block));
        if (block.BlockInfo !is null) o["name"] = string(block.BlockInfo.IdName);
        return Ok(o);
    }

    Json::Value@ CoordConvert(Json::Value &in input) {
        string action = input.HasKey("action") ? string(input["action"]) : "coordToPos";
        vec3 v = JsonToVec3(input);
        auto o = Json::Object();
        if (action == "posToCoord") {
            nat3 c = Editor::PosToCoord(v);
            o["x"] = int(c.x);
            o["y"] = int(c.y);
            o["z"] = int(c.z);
        } else {
            o["pos"] = Vec3ToJson(Editor::CoordToPos(nat3(uint(v.x), uint(v.y), uint(v.z))));
        }
        return Ok(o);
    }

    Json::Value@ GetNodPointer(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        uint64 ptr = Editor::GetNodPointer(editor.Challenge);
        auto o = Json::Object();
        o["mapPtr"] = Text::FormatPointer(ptr);
        return Ok(o);
    }

    Json::Value@ RefreshMapCache(Json::Value &in input) {
        Editor::RefreshMapCacheSoon();
        auto o = Json::Object();
        o["stale"] = Editor::IsMapCacheStale();
        return Ok(o);
    }

    Json::Value@ IsGizmoActiveTool(Json::Value &in input) {
        auto o = Json::Object();
        o["active"] = Editor::IsGizmoActive();
        return Ok(o);
    }

    Json::Value@ RunGizmoApplyBlock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return NeedEditor();
        if (!input.HasKey("blockName") || !input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) {
            return Err("missing blockName, x, y, z");
        }
        bool isTerrain = false;
        auto info = ResolveBlockModel(editor.PluginMapType, string(input["blockName"]), isTerrain);
        if (info is null) return Err("block not found");
        vec3 pos = JsonToVec3(input);
        uint variant = input.HasKey("variant") ? uint(int(input["variant"])) : 0;
        bool ok = false;
        try { ok = Editor::Dev_RunGizmoApplyBlock(info, pos, variant); } catch {
            return Err("gizmo apply threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["ok"] = ok;
        o["pos"] = Vec3ToJson(pos);
        return Ok(o);
    }

    Json::Value@ ListCoverage(Json::Value &in input) {
        auto o = Json::Object();
        auto tools = Json::Array();
        string[] names = {
            "Ping", "PlaceBlock", "PlaceItem", "DeleteRecentBlocks", "DeleteRecentItems",
            "FindInventory", "RefreshInventory", "GetInventorySummary",
            "FocusCamera", "SetCamGoTo", "ControlMapObjectives", "ControlEditMode",
            "GetEditorSelectionState", "SelectBlock", "SelectItem", "SetAirMode",
            "ControlItemEditor", "GetBlockLocation", "CoordConvert", "GetNodPointer",
            "RefreshMapCache", "IsGizmoActive", "RunGizmoApplyBlock", "ListCoverage"
        };
        for (uint i = 0; i < names.Length; i++) tools.Add(names[i]);
        o["tools"] = tools;
        o["count"] = int(names.Length);
        o["note"] = "Named-macroblock JSON store and RemoveByTag stay in tm-control-mcp for now.";
        return Ok(o);
    }
}
