namespace TmMcpPackEpp {
    Json::Value@ Ping(Json::Value &in input) {
        auto o = Json::Object();
        o["pong"] = true;
        o["pack"] = "tm-mcp-pack-epp";
        return Ok(o);
    }

    // B: batch place/delete in one call
    Json::Value@ PlaceBlocksAndItems(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("blocks") && !input.HasKey("items")) return Err("missing blocks / items arrays");

        Editor::BlockSpec@[] blocks;
        if (input.HasKey("blocks") && input["blocks"].GetType() == Json::Type::Array) {
            auto arr = input["blocks"];
            for (uint i = 0; i < arr.Length; i++) {
                Json::Value b = arr[i];
                if (!b.HasKey("blockName")) return Err("blocks[" + i + "] missing blockName");
                bool isTerrain = false;
                auto info = ResolveBlockModel(editor.PluginMapType, string(b["blockName"]), isTerrain);
                if (info is null) return Err("block not found: " + string(b["blockName"]));
                vec3 pos = JsonToVec3(b);
                vec3 rot = vec3(
                    b.HasKey("pitch") ? float(b["pitch"]) : 0.0,
                    b.HasKey("yaw") ? float(b["yaw"]) : 0.0,
                    b.HasKey("roll") ? float(b["roll"]) : 0.0
                );
                auto spec = Editor::MakeBlockSpec(info, pos, rot);
                if (b.HasKey("free") ? bool(b["free"]) : true) {
                    spec.SetFree();
                    spec.isGround = false;
                    spec.isGhost = false;
                }
                if (b.HasKey("variant")) spec.variant = uint(int(b["variant"]));
                spec.EnsureValidVariant();
                blocks.InsertLast(spec);
            }
        }
        Editor::ItemSpec@[] items;
        if (input.HasKey("items") && input["items"].GetType() == Json::Type::Array) {
            auto arr = input["items"];
            for (uint i = 0; i < arr.Length; i++) {
                Json::Value it = arr[i];
                if (!it.HasKey("itemPath")) return Err("items[" + i + "] missing itemPath");
                auto model = Editor::GetInventoryItemModelByPath(string(it["itemPath"]));
                if (model is null) return Err("item not found: " + string(it["itemPath"]));
                vec3 pos = JsonToVec3(it);
                vec3 rot = vec3(
                    it.HasKey("pitch") ? float(it["pitch"]) : 0.0,
                    it.HasKey("yaw") ? float(it["yaw"]) : 0.0,
                    it.HasKey("roll") ? float(it["roll"]) : 0.0
                );
                auto spec = Editor::MakeItemSpec(model, pos, rot);
                items.InsertLast(spec);
            }
        }

        bool addUndo = input.HasKey("addUndo") ? bool(input["addUndo"]) : true;
        bool placed = false;
        try { placed = Editor::PlaceBlocksAndItems(blocks, items, addUndo); } catch {
            return Err("PlaceBlocksAndItems threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["placed"] = placed;
        o["blockCount"] = int(blocks.Length);
        o["itemCount"] = int(items.Length);
        return Ok(o);
    }

    Json::Value@ DeleteBlocksAndItems(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("blockIndexes") && !input.HasKey("itemIndexes")) return Err("missing blockIndexes / itemIndexes");

        Editor::BlockSpec@[] blocks;
        CGameCtnBlock@[] blockRefs;
        if (input.HasKey("blockIndexes") && input["blockIndexes"].GetType() == Json::Type::Array) {
            auto arr = input["blockIndexes"];
            for (uint i = 0; i < arr.Length; i++) {
                int idx = int(arr[i]);
                if (idx < 0 || uint(idx) >= editor.Challenge.Blocks.Length) return Err("blockIndex out of range: " + idx);
                auto b = editor.Challenge.Blocks[uint(idx)];
                if (b is null) continue;
                auto spec = Editor::MakeBlockSpec(b);
                if (spec is null) continue;
                blocks.InsertLast(spec);
                blockRefs.InsertLast(b);
            }
        }
        Editor::ItemSpec@[] items;
        CGameCtnAnchoredObject@[] itemRefs;
        if (input.HasKey("itemIndexes") && input["itemIndexes"].GetType() == Json::Type::Array) {
            auto arr = input["itemIndexes"];
            for (uint i = 0; i < arr.Length; i++) {
                int idx = int(arr[i]);
                if (idx < 0 || uint(idx) >= editor.Challenge.AnchoredObjects.Length) return Err("itemIndex out of range: " + idx);
                auto it = editor.Challenge.AnchoredObjects[uint(idx)];
                if (it is null) continue;
                auto spec = Editor::MakeItemSpec(it);
                if (spec is null) continue;
                items.InsertLast(spec);
                itemRefs.InsertLast(it);
            }
        }

        // Note: spec-based delete handles freeblocks correctly
        bool addUndo = input.HasKey("addUndo") ? bool(input["addUndo"]) : true;
        bool deleted = false;
        try { deleted = Editor::DeleteBlocksAndItems(blocks, items, addUndo); } catch {
            return Err("DeleteBlocksAndItems threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["deleted"] = deleted;
        o["blockCount"] = int(blocks.Length);
        o["itemCount"] = int(items.Length);
        return Ok(o);
    }

    Json::Value@ ConvertBlockToFree(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("index")) return Err("missing index");
        int idx = int(input["index"]);
        if (idx < 0 || uint(idx) >= editor.Challenge.Blocks.Length) return Err("index out of range");
        auto block = editor.Challenge.Blocks[uint(idx)];
        CGameCtnBlock@ repl = null;
        try { @repl = Editor::ConvertBlockToFree(block); } catch {
            return Err("ConvertBlockToFree threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["converted"] = repl !is null;
        if (repl !is null) o["pos"] = Vec3ToJson(Editor::GetBlockLocation(repl, true));
        return Ok(o);
    }

    Json::Value@ GetMapAsMacroblock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        Editor::MacroblockWithSetSkins@ mbs = null;
        try { @mbs = Editor::GetMapAsMacroblock(); } catch {
            return Err("GetMapAsMacroblock threw: " + getExceptionInfo(), "epp_exception");
        }
        if (mbs is null || mbs.macroblock is null) return Err("GetMapAsMacroblock returned null", "NULL_RESULT");
        auto o = Json::Object();
        o["nbBlocks"] = int(mbs.macroblock.blocks.Length);
        o["nbItems"] = int(mbs.macroblock.items.Length);
        o["nbSkins"] = int(mbs.setSkins.Length);
        return Ok(o);
    }

    Json::Value@ SetMapEmbeddedColors(Json::Value &in input) {
        string action = input.HasKey("action") ? string(input["action"]) : "get";
        if (action == "set") {
            if (!input.HasKey("raw")) return Err("missing raw (encoded colors string)");
            Editor::Set_Map_EmbeddedCustomColorsEncoded(string(input["raw"]));
        }
        auto o = Json::Object();
        o["raw"] = Editor::Get_Map_EmbeddedCustomColorsEncoded();
        o["hasColors"] = string(Editor::Get_Map_EmbeddedCustomColorsEncoded()).Length > 0;
        return Ok(o);
    }

    Json::Value@ ControlItemSkins(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("index")) return Err("missing index");
        int idx = int(input["index"]);
        if (idx < 0 || uint(idx) >= editor.Challenge.AnchoredObjects.Length) return Err("index out of range");
        auto item = editor.Challenge.AnchoredObjects[uint(idx)];
        string action = input.HasKey("action") ? string(input["action"]) : "get";
        auto o = Json::Object();
        o["index"] = idx;
        if (action == "set") {
            CSystemPackDesc@ fg = input.HasKey("fgSkin") && string(input["fgSkin"]).Length > 0
                ? Editor::GetPackDesc(string(input["fgSkin"])) : null;
            CSystemPackDesc@ bg = input.HasKey("bgSkin") && string(input["bgSkin"]).Length > 0
                ? Editor::GetPackDesc(string(input["bgSkin"])) : null;
            try { Editor::SetItemSkinsRaw(item, bg, fg); } catch {
                return Err("SetItemSkinsRaw threw: " + getExceptionInfo(), "epp_exception");
            }
        }
        auto fgNow = Editor::GetItemFGSkin(item);
        auto bgNow = Editor::GetItemBGSkin(item);
        o["fgSkin"] = fgNow !is null ? string(fgNow.IdName) : "";
        o["bgSkin"] = bgNow !is null ? string(bgNow.IdName) : "";
        return Ok(o);
    }

    Json::Value@ ControlPlacementMode(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null) return NeedEditor();
        string action = input.HasKey("action") ? string(input["action"]) : "get";
        if (action == "set" && input.HasKey("mode")) {
            Editor::SetItemPlacementModeInt(int(input["mode"]));
        }
        auto o = Json::Object();
        int mode = Editor::GetItemPlacementModeInt();
        o["mode"] = mode;
        o["modeName"] = mode == 0 ? "None" : mode == 1 ? "Normal" : mode == 2 ? "FreeGround" : mode == 3 ? "Free" : "Mode(" + mode + ")";
        return Ok(o);
    }

    Json::Value@ ControlPivot(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null) return NeedEditor();
        string action = input.HasKey("action") ? string(input["action"]) : "get";
        if (action == "set" && input.HasKey("pivot")) {
            Editor::SetCurrentPivot(editor, uint(int(input["pivot"])));
        }
        auto o = Json::Object();
        o["pivot"] = int(Editor::GetCurrentPivot(editor));
        return Ok(o);
    }

    Json::Value@ DuplicateItem(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return NeedEditor();
        if (!input.HasKey("index")) return Err("missing index");
        int idx = int(input["index"]);
        if (idx < 0 || uint(idx) >= editor.Challenge.AnchoredObjects.Length) return Err("index out of range");
        auto item = editor.Challenge.AnchoredObjects[uint(idx)];
        bool update = input.HasKey("updateItems") ? bool(input["updateItems"]) : false;
        CGameCtnAnchoredObject@ dup = null;
        try { @dup = Editor::DuplicateAndAddItem(editor, item, update); } catch {
            return Err("DuplicateAndAddItem threw: " + getExceptionInfo(), "epp_exception");
        }
        auto o = Json::Object();
        o["duplicated"] = dup !is null;
        o["afterItems"] = int(editor.Challenge.AnchoredObjects.Length);
        if (dup !is null) o["pos"] = Vec3ToJson(dup.AbsolutePositionInMap);
        return Ok(o);
    }

    Json::Value@ ListCoverage(Json::Value &in input) {
        auto o = Json::Object();
        auto tools = Json::Array();
        string[] names = {
            "Ping",
            "PlaceBlock",
            "PlaceItem",
            "DeleteRecentBlocks",
            "DeleteRecentItems",
            "PlaceBlocksAndItems",
            "DeleteBlocksAndItems",
            "ConvertBlockToFree",
            "GetMapAsMacroblock",
            "SetMapEmbeddedColors",
            "ControlItemSkins",
            "ControlPlacementMode",
            "ControlPivot",
            "DuplicateItem",
            "FindInventory",
            "RefreshInventory",
            "GetInventorySummary",
            "ControlInventory",
            "FocusCamera",
            "SetCamGoTo",
            "ControlMapObjectives",
            "ControlEditMode",
            "GetEditorSelectionState",
            "SelectBlock",
            "SelectItem",
            "SetAirMode",
            "ControlItemEditor",
            "GetBlockLocation",
            "CoordConvert",
            "GetNodPointer",
            "RefreshMapCache",
            "IsGizmoActive",
            "RunGizmoApplyBlock",
            "SelectBlockModel",
            "SetCursorBlock",
            "SelectItemModel",
            "SelectMacroblockModel",
            "CreateNamedMacroblock",
            "ListNamedMacroblocks",
            "GetNamedMacroblock",
            "ClearNamedMacroblock",
            "AddBlockToNamedMacroblock",
            "AddBlocksToNamedMacroblock",
            "AddItemToNamedMacroblock",
            "AddItemsToNamedMacroblock",
            "PlaceNamedMacroblock",
            "PreflightNamedMacroblockPlacement",
            "SaveNamedMacroblock",
            "LoadNamedMacroblock",
            "ListSavedNamedMacroblocks",
            "RemoveBlocksByIndex",
            "RemoveItemsByIndex",
            "InspectMacroblockModel",
            "ListMacroblockInstances",
            "SetAgentTag",
            "ListTagged",
            "RemoveByTag",
            "ClearTagIndex",
            "AssertPlacement",
            "ListCoverage"
        };
        for (uint i = 0; i < names.Length; i++) tools.Add(names[i]);
        o["tools"] = tools;
        o["count"] = int(names.Length);
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
            o["x"] = int(Math::Floor(v.x / 32.0));
            o["y"] = int(Math::Floor((v.y + 64.0) / 8.0));
            o["z"] = int(Math::Floor(v.z / 32.0));
        } else {
            o["pos"] = Vec3ToJson(vec3(v.x * 32.0, v.y * 8.0 - 64.0, v.z * 32.0));
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
            AutofocusCameraOn(pos, 60.0);
        }
        auto o = Json::Object();
        o["placed"] = placed;
        o["beforeBlocks"] = int(before);
        o["afterBlocks"] = int(editor.Challenge.Blocks.Length);
        o["pos"] = Vec3ToJson(pos);
        o["blockName"] = string(blockInfo.IdName);
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
        if (input.HasKey("autofocus") ? bool(input["autofocus"]) : true) {
            AutofocusCameraOn(pos, 60.0);
        }
        auto o = Json::Object();
        o["placed"] = placed;
        o["beforeItems"] = int(before);
        o["afterItems"] = int(editor.Challenge.AnchoredObjects.Length);
        o["pos"] = Vec3ToJson(pos);
        o["itemPath"] = string(input["itemPath"]);
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
}
