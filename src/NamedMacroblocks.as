namespace TmMcpPackEpp {
    array<string> g_NamedMacroblockNames;
    array<Editor::MacroblockSpec@> g_NamedMacroblocks;
    array<NamedMacroblockSkin@[]@> g_NamedMacroblockSkins;
    Json::Value@ CreateNamedMacroblock(Json::Value &in input) {
        if (!input.HasKey("name")) return MakeError("missing name");
        string name = string(input["name"]);
        if (name.Length == 0) return MakeError("name is empty");
        bool replace = input.HasKey("replace") ? bool(input["replace"]) : false;
        int index = FindNamedMacroblockIndex(name);
        if (index >= 0 && !replace) return MakeError("named macroblock already exists: " + name);

        auto mb = Editor::MakeMacroblockSpec();
        if (index >= 0) {
            @g_NamedMacroblocks[index] = mb;
            @g_NamedMacroblockSkins[index] = NewNamedMacroblockSkinList();
        } else {
            g_NamedMacroblockNames.InsertLast(name);
            g_NamedMacroblocks.InsertLast(mb);
            g_NamedMacroblockSkins.InsertLast(NewNamedMacroblockSkinList());
        }
        return MakeSuccess(NamedMacroblockSummary(name, mb));
    }

    Json::Value@ ListNamedMacroblocks(Json::Value &in input) {
        Json::Value entries = Json::Array();
        for (uint i = 0; i < g_NamedMacroblockNames.Length; i++) {
            entries.Add(NamedMacroblockSummary(g_NamedMacroblockNames[i], g_NamedMacroblocks[i]));
        }

        Json::Value output = Json::Object();
        output["macroblocks"] = entries;
        output["count"] = int(entries.Length);
        return MakeSuccess(output);
    }

    Json::Value@ GetNamedMacroblockTool(Json::Value &in input) {
        if (!input.HasKey("name")) return MakeError("missing name");
        string name = string(input["name"]);
        auto mb = GetNamedMacroblock(name);
        if (mb is null) return MakeError("named macroblock not found: " + name);

        int limit = input.HasKey("limit") ? int(input["limit"]) : 100;
        if (limit < 1) limit = 1;
        if (limit > 500) limit = 500;
        bool includeItems = input.HasKey("includeItems") ? bool(input["includeItems"]) : true;

        Json::Value blocks = Json::Array();
        for (uint i = 0; i < mb.blocks.Length && blocks.Length < uint(limit); i++) {
            auto obj = BlockSpecToJson(mb.blocks[i]);
            obj["index"] = int(i);
            blocks.Add(obj);
        }

        Json::Value items = Json::Array();
        if (includeItems) {
            for (uint i = 0; i < mb.items.Length && items.Length < uint(limit); i++) {
                auto obj = ItemSpecToJson(mb.items[i]);
                obj["index"] = int(i);
                items.Add(obj);
            }
        }

        Json::Value output = NamedMacroblockSummary(name, mb);
        output["blocks"] = blocks;
        output["items"] = items;
        output["postSkins"] = NamedMacroblockSkinsToJson(GetNamedMacroblockSkins(name), limit);
        output["limit"] = limit;
        output["includeItems"] = includeItems;
        return MakeSuccess(output);
    }

    Json::Value@ ClearNamedMacroblock(Json::Value &in input) {
        bool clearAll = input.HasKey("all") ? bool(input["all"]) : false;
        if (clearAll) {
            int count = int(g_NamedMacroblockNames.Length);
            g_NamedMacroblockNames.RemoveRange(0, g_NamedMacroblockNames.Length);
            g_NamedMacroblocks.RemoveRange(0, g_NamedMacroblocks.Length);
            g_NamedMacroblockSkins.RemoveRange(0, g_NamedMacroblockSkins.Length);
            Json::Value output = Json::Object();
            output["clearedAll"] = true;
            output["count"] = count;
            return MakeSuccess(output);
        }

        if (!input.HasKey("name")) return MakeError("missing name or all=true");
        string name = string(input["name"]);
        int index = FindNamedMacroblockIndex(name);
        if (index < 0) return MakeError("named macroblock not found: " + name);
        g_NamedMacroblockNames.RemoveAt(index);
        g_NamedMacroblocks.RemoveAt(index);
        g_NamedMacroblockSkins.RemoveAt(index);

        Json::Value output = Json::Object();
        output["cleared"] = true;
        output["name"] = name;
        return MakeSuccess(output);
    }

    Json::Value@ AddBlockToNamedMacroblock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        if (!input.HasKey("name") || !input.HasKey("blockName") || !input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) {
            return MakeError("missing name, blockName, x, y, z");
        }

        string name = string(input["name"]);
        string blockName = string(input["blockName"]);
        bool create = input.HasKey("create") ? bool(input["create"]) : true;
        auto mb = GetNamedMacroblock(name);
        if (mb is null && create) {
            @mb = Editor::MakeMacroblockSpec();
            g_NamedMacroblockNames.InsertLast(name);
            g_NamedMacroblocks.InsertLast(mb);
            g_NamedMacroblockSkins.InsertLast(NewNamedMacroblockSkinList());
        }
        if (mb is null) return MakeError("named macroblock not found: " + name);

        bool isTerrain = false;
        auto blockInfo = ResolveBlockModel(editor.PluginMapType, blockName, isTerrain);
        if (blockInfo is null) return MakeError("block not found: " + blockName);
        if (isTerrain) return MakeError("terrain models are not supported in named freeblock macroblocks");

        vec3 pos = PositionInput(input);
        vec3 rot = RotationInput(input);
        auto spec = Editor::MakeBlockSpec(blockInfo, pos, rot);
        spec.SetFree();
        spec.isGround = false;
        spec.isGhost = false;
        spec.variant = input.HasKey("variant") ? uint(input["variant"]) : 0;
        bool variantOk = spec.EnsureValidVariant();
        uint blockIndex = mb.blocks.Length;
        mb.blocks.InsertLast(spec);
        string fgSkin = input.HasKey("fgSkin") ? string(input["fgSkin"]) : "";
        string bgSkin = input.HasKey("bgSkin") ? string(input["bgSkin"]) : "";
        if (!input.HasKey("fgSkin") && input.HasKey("skin")) fgSkin = string(input["skin"]);
        AddPostSkinToNamedMacroblock(name, blockIndex, fgSkin, bgSkin);

        Json::Value output = NamedMacroblockSummary(name, mb);
        output["added"] = true;
        output["blockIndex"] = int(blockIndex);
        output["variantOk"] = variantOk;
        output["blockName"] = blockName;
        output["modelName"] = blockInfo.Name;
        output["modelIdName"] = blockInfo.IdName;
        output["pos"] = Vec3ToJson(pos);
        output["rot"] = Vec3ToJson(rot);
        output["rotDeg"] = Vec3DegToJson(rot);
        output["fgSkin"] = fgSkin;
        output["bgSkin"] = bgSkin;
        return MakeSuccess(output);
    }

    Json::Value@ AddBlocksToNamedMacroblock(Json::Value &in input) {
        if (!input.HasKey("name") || !input.HasKey("blocks")) return MakeError("missing name or blocks");
        auto blocks = input["blocks"];
        if (blocks.GetType() != Json::Type::Array) return MakeError("blocks must be an array");
        string name = string(input["name"]);
        bool create = input.HasKey("create") ? bool(input["create"]) : true;
        bool continueOnError = input.HasKey("continueOnError") ? bool(input["continueOnError"]) : false;

        Json::Value errors = Json::Array();
        int added = 0;
        for (uint i = 0; i < blocks.Length; i++) {
            Json::Value block = blocks[i];
            block["name"] = name;
            block["create"] = create;
            auto result = AddBlockToNamedMacroblock(block);
            if (bool(result["success"])) {
                added++;
                continue;
            }
            Json::Value err = Json::Object();
            err["index"] = int(i);
            err["error"] = string(result["error"]);
            errors.Add(err);
            if (!continueOnError) break;
        }

        auto mb = GetNamedMacroblock(name);
        Json::Value output = mb is null ? Json::Object() : NamedMacroblockSummary(name, mb);
        output["requested"] = int(blocks.Length);
        output["added"] = added;
        output["errors"] = errors;
        output["ok"] = errors.Length == 0;
        return MakeSuccess(output);
    }

    Json::Value@ AddItemToNamedMacroblock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        if (!input.HasKey("name") || !input.HasKey("itemPath") || !input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) {
            return MakeError("missing name, itemPath, x, y, z");
        }

        string name = string(input["name"]);
        string itemPath = string(input["itemPath"]);
        bool create = input.HasKey("create") ? bool(input["create"]) : true;
        auto mb = GetNamedMacroblock(name);
        if (mb is null && create) {
            @mb = Editor::MakeMacroblockSpec();
            g_NamedMacroblockNames.InsertLast(name);
            g_NamedMacroblocks.InsertLast(mb);
            g_NamedMacroblockSkins.InsertLast(NewNamedMacroblockSkinList());
        }
        if (mb is null) return MakeError("named macroblock not found: " + name);

        auto itemModel = ResolveItemModel(itemPath);
        if (itemModel is null) return MakeError("item not found: " + itemPath);

        vec3 pos = PositionInput(input);
        vec3 rot = RotationInput(input);
        auto spec = Editor::MakeItemSpec(itemModel, pos, rot);
        spec.isFlying = 1;
        spec.variantIx = input.HasKey("variant") ? uint16(input["variant"]) : 0;
        uint itemIndex = mb.items.Length;
        mb.items.InsertLast(spec);
        string fgSkin = input.HasKey("fgSkin") ? string(input["fgSkin"]) : "";
        string bgSkin = input.HasKey("bgSkin") ? string(input["bgSkin"]) : "";
        if (!input.HasKey("fgSkin") && input.HasKey("skin")) bgSkin = string(input["skin"]);
        AddPostItemSkinToNamedMacroblock(name, itemIndex, fgSkin, bgSkin);

        Json::Value output = NamedMacroblockSummary(name, mb);
        output["added"] = true;
        output["itemIndex"] = int(itemIndex);
        output["itemPath"] = itemPath;
        output["model"] = ItemModelToJson(itemModel, itemPath);
        output["pos"] = Vec3ToJson(pos);
        output["rot"] = Vec3ToJson(rot);
        output["rotDeg"] = Vec3DegToJson(rot);
        output["variant"] = int(spec.variantIx);
        output["fgSkin"] = fgSkin;
        output["bgSkin"] = bgSkin;
        return MakeSuccess(output);
    }

    Json::Value@ AddItemsToNamedMacroblock(Json::Value &in input) {
        if (!input.HasKey("name") || !input.HasKey("items")) return MakeError("missing name or items");
        auto items = input["items"];
        if (items.GetType() != Json::Type::Array) return MakeError("items must be an array");
        string name = string(input["name"]);
        bool create = input.HasKey("create") ? bool(input["create"]) : true;
        bool continueOnError = input.HasKey("continueOnError") ? bool(input["continueOnError"]) : false;

        Json::Value errors = Json::Array();
        int added = 0;
        for (uint i = 0; i < items.Length; i++) {
            Json::Value item = items[i];
            item["name"] = name;
            item["create"] = create;
            auto result = AddItemToNamedMacroblock(item);
            if (bool(result["success"])) {
                added++;
                continue;
            }
            Json::Value err = Json::Object();
            err["index"] = int(i);
            err["error"] = string(result["error"]);
            errors.Add(err);
            if (!continueOnError) break;
        }

        auto mb = GetNamedMacroblock(name);
        Json::Value output = mb is null ? Json::Object() : NamedMacroblockSummary(name, mb);
        output["requested"] = int(items.Length);
        output["added"] = added;
        output["errors"] = errors;
        output["ok"] = errors.Length == 0;
        return MakeSuccess(output);
    }

    Json::Value@ PlaceNamedMacroblock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        if (!input.HasKey("name")) return MakeError("missing name");
        string name = string(input["name"]);
        auto mb = GetNamedMacroblock(name);
        if (mb is null) return MakeError("named macroblock not found: " + name);
        if (mb.blocks.Length == 0 && mb.items.Length == 0) return MakeError("named macroblock is empty: " + name);

        bool addUndo = input.HasKey("addUndo") ? bool(input["addUndo"]) : true;
        bool autofocus = input.HasKey("autofocus") ? bool(input["autofocus"]) : true;
        vec3 offset = OptionalOffsetInput(input);
        vec3 rotation = RotationInput(input);
        vec3 pivot = PivotInput(input);
        bool transformed = HasTransformInput(input);
        auto placedMb = transformed
            ? DuplicateAndTransformMacroblock(mb, offset, rotation, pivot)
            : mb.Duplicate();

        Json::Value mapPre = MapSummary(editor);
        int blockBaseIndex = int(editor.Challenge.Blocks.Length);
        int itemBaseIndex = int(editor.Challenge.AnchoredObjects.Length);
        bool placed = false;
        string error = "";
        try {
            placed = Editor::PlaceMacroblock(placedMb, addUndo);
        } catch {
            error = getExceptionInfo();
        }

        Json::Value skinApplication = Json::Object();
        skinApplication["requested"] = 0;
        bool skinsApplied = false;
        string skinError = "";
        auto postSkins = GetNamedMacroblockSkins(name);
        int skinsRequested = postSkins is null ? 0 : int(postSkins.Length);
        if (placed && skinsRequested > 0) {
            try {
                skinApplication = ApplyNamedMacroblockSkinsDirect(editor.PluginMapType, name, blockBaseIndex, itemBaseIndex);
                skinsApplied = bool(skinApplication["ok"]);
                for (uint i = 0; i < 5; i++) yield();
            } catch {
                skinError = getExceptionInfo();
            }
        }

        Json::Value output = NamedMacroblockSummary(name, mb);
        output["placed"] = placed;
        output["skinsRequested"] = skinsRequested;
        output["skinsApplied"] = skinsApplied;
        output["skinApplication"] = skinApplication;
        output["addUndo"] = addUndo;
        output["transformed"] = transformed;
        output["offset"] = Vec3ToJson(offset);
        output["rot"] = Vec3ToJson(rotation);
        output["rotDeg"] = Vec3DegToJson(rotation);
        output["pivot"] = Vec3ToJson(pivot);
        output["mapPre"] = mapPre;
        output["mapPost"] = MapSummary(editor);
        RememberMapDelta("PlaceNamedMacroblock", mapPre, output["mapPost"]);
        if (placed) RecordTaggedNamedMacroblock(input, placedMb, blockBaseIndex, itemBaseIndex);
        string agentTag = ResolvePlacementTag(input);
        if (agentTag.Length > 0) output["agentTag"] = agentTag;
        if (error.Length > 0) output["error"] = error;
        if (skinError.Length > 0) output["skinError"] = skinError;
        output["autofocus"] = false;
        if (placed && autofocus && (placedMb.blocks.Length > 0 || placedMb.items.Length > 0)) {
            vec3 bMin = vec3(1e18, 1e18, 1e18);
            vec3 bMax = vec3(-1e18, -1e18, -1e18);
            for (uint i = 0; i < placedMb.blocks.Length; i++) {
                vec3 p = placedMb.blocks[i].pos;
                bMin = vec3(Math::Min(bMin.x, p.x), Math::Min(bMin.y, p.y), Math::Min(bMin.z, p.z));
                bMax = vec3(Math::Max(bMax.x, p.x), Math::Max(bMax.y, p.y), Math::Max(bMax.z, p.z));
            }
            for (uint i = 0; i < placedMb.items.Length; i++) {
                vec3 p = placedMb.items[i].pos;
                bMin = vec3(Math::Min(bMin.x, p.x), Math::Min(bMin.y, p.y), Math::Min(bMin.z, p.z));
                bMax = vec3(Math::Max(bMax.x, p.x), Math::Max(bMax.y, p.y), Math::Max(bMax.z, p.z));
            }
            vec3 center = (bMin + bMax) * 0.5 - MacroblockInternalOffset();
            vec3 diag = bMax - bMin;
            float diagonal = Math::Sqrt(diag.x * diag.x + diag.y * diag.y + diag.z * diag.z);
            float autofocusDistance = input.HasKey("autofocusDistance") ? float(input["autofocusDistance"]) : Math::Max(60.0, diagonal * 2.0);
            output["autofocus"] = AutofocusCameraOn(center, autofocusDistance);
            output["autofocusTarget"] = Vec3ToJson(center);
            output["autofocusDistance"] = autofocusDistance;
        }
        return MakeSuccess(output);
    }

    Json::Value@ RemoveBlocksByIndex(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");

        array<int> indices;
        string err;
        int total = int(editor.Challenge.Blocks.Length);
        if (!ReadIndexArgs(input, total, 50, indices, err)) return MakeError(err);
        bool addUndo = input.HasKey("addUndo") ? bool(input["addUndo"]) : true;

        CGameCtnBlock@[] blocks;
        Json::Value removed = Json::Array();
        for (uint i = 0; i < indices.Length; i++) {
            auto block = editor.Challenge.Blocks[indices[i]];
            if (block is null) continue;
            blocks.InsertLast(block);
            auto obj = BlockToJson(block);
            obj["index"] = indices[i];
            removed.Add(obj);
        }

        Json::Value mapPre = MapSummary(editor);
        int beforeBlocks = int(editor.Challenge.Blocks.Length);
        bool allFree = true;
        for (uint i = 0; i < blocks.Length; i++) {
            if (!Editor::IsBlockFree(blocks[i])) allFree = false;
        }

        bool ok = false;
        string method = allFree ? "DeleteFreeblocks" : "DeleteBlocks";
        uint queuedFreeblocks = 0;
        try {
            if (allFree) {
                queuedFreeblocks = Editor::DeleteFreeblocks(blocks);
                for (uint i = 0; i < 30 && int(editor.Challenge.Blocks.Length) == beforeBlocks; i++) yield();
                ok = int(editor.Challenge.Blocks.Length) <= beforeBlocks - int(blocks.Length);
                if (ok && addUndo && editor.PluginMapType !is null) editor.PluginMapType.AutoSave();
            } else {
                ok = Editor::DeleteBlocks(blocks, addUndo);
            }
        } catch {
            return MakeError(method + " failed: " + getExceptionInfo());
        }

        Json::Value output = Json::Object();
        output["deleted"] = ok;
        output["method"] = method;
        output["queuedFreeblocks"] = int(queuedFreeblocks);
        output["requestedCount"] = int(indices.Length);
        output["matchedCount"] = int(blocks.Length);
        output["addUndo"] = addUndo;
        output["removed"] = removed;
        output["mapPre"] = mapPre;
        output["mapPost"] = MapSummary(editor);
        return MakeSuccess(output);
    }

    Json::Value@ RemoveItemsByIndex(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");

        array<int> indices;
        string err;
        int total = int(editor.Challenge.AnchoredObjects.Length);
        if (!ReadIndexArgs(input, total, 50, indices, err)) return MakeError(err);
        bool addUndo = input.HasKey("addUndo") ? bool(input["addUndo"]) : true;
        bool forceBufferFallback = input.HasKey("forceBufferFallback") ? bool(input["forceBufferFallback"]) : false;

        CGameCtnAnchoredObject@[] items;
        Json::Value removed = Json::Array();
        for (uint i = 0; i < indices.Length; i++) {
            auto item = editor.Challenge.AnchoredObjects[indices[i]];
            if (item is null) continue;
            items.InsertLast(item);
            auto obj = ItemToJson(item);
            obj["index"] = indices[i];
            removed.Add(obj);
        }

        Json::Value mapPre = MapSummary(editor);
        bool ok = false;
        string method = "DeleteItems";
        try {
            ok = Editor::DeleteItems(items, addUndo);
        } catch {
            return MakeError("DeleteItems failed: " + getExceptionInfo());
        }
        if (!ok && forceBufferFallback && total == int(editor.Challenge.AnchoredObjects.Length)) {
            method = "AnchoredObjects.RemoveRangeByIndex";
            while (indices.Length > 0) {
                int bestPos = 0;
                for (uint i = 1; i < indices.Length; i++) {
                    if (indices[i] > indices[bestPos]) bestPos = int(i);
                }
                editor.Challenge.AnchoredObjects.RemoveRange(indices[bestPos], 1);
                indices.RemoveAt(bestPos);
            }
            ok = int(editor.Challenge.AnchoredObjects.Length) == total - int(items.Length);
            if (ok && addUndo && editor.PluginMapType !is null) editor.PluginMapType.AutoSave();
        }

        Json::Value output = Json::Object();
        output["deleted"] = ok;
        output["method"] = method;
        output["undoSupported"] = method == "DeleteItems";
        output["requestedCount"] = int(removed.Length);
        output["matchedCount"] = int(items.Length);
        output["addUndo"] = addUndo;
        output["removed"] = removed;
        output["mapPre"] = mapPre;
        output["mapPost"] = MapSummary(editor);
        return MakeSuccess(output);
    }

    Json::Value@ SetCursorBlock(Json::Value &in input) {
        return SelectBlockModel(input);
    }

    Json::Value@ SelectBlockModel(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        if (!input.HasKey("blockName")) return MakeError("missing blockName");
        string blockName = string(input["blockName"]);
        bool isTerrain = false;
        auto blockInfo = ResolveBlockModel(editor.PluginMapType, blockName, isTerrain);
        if (blockInfo is null) return MakeError("block not found: " + blockName);
        if (isTerrain) return MakeError("terrain models cannot be selected as the current block model");

        string selection = input.HasKey("selection") ? string(input["selection"]).ToLower() : "both";
        if (selection == "normal") {
            Editor::SetSelectedNormalBlockInfo(editor, blockInfo);
        } else if (selection == "ghost") {
            Editor::SetSelectedGhostBlockInfo(editor, blockInfo);
        } else if (selection == "both" || selection.Length == 0) {
            Editor::SetSelectedBlockInfo(editor, blockInfo);
        } else {
            return MakeError("selection must be one of: both, normal, ghost");
        }

        Json::Value output = Json::Object();
        output["selected"] = true;
        output["selection"] = selection.Length == 0 ? "both" : selection;
        output["blockName"] = blockName;
        output["modelName"] = blockInfo.Name;
        output["modelIdName"] = blockInfo.IdName;
        output["currentBlockName"] = editor.CurrentBlockInfo is null ? "" : string(editor.CurrentBlockInfo.Name);
        output["currentBlockIdName"] = editor.CurrentBlockInfo is null ? "" : string(editor.CurrentBlockInfo.IdName);
        output["currentGhostBlockName"] = editor.CurrentGhostBlockInfo is null ? "" : string(editor.CurrentGhostBlockInfo.Name);
        output["currentGhostBlockIdName"] = editor.CurrentGhostBlockInfo is null ? "" : string(editor.CurrentGhostBlockInfo.IdName);
        return MakeSuccess(output);
    }

    Json::Value@ FocusCamera(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        if (!input.HasKey("x") || !input.HasKey("y") || !input.HasKey("z")) return MakeError("missing x, y, z");
        vec3 target = PositionInput(input);
        float distance = input.HasKey("distance") ? float(input["distance"]) : 60.0;
        bool focused = FocusCameraOn(target, distance);

        Json::Value output = CameraToJson(editor);
        output["focused"] = focused;
        output["target"] = Vec3ToJson(target);
        output["distance"] = distance;
        return MakeSuccess(output);
    }

    Json::Value@ FindInventory(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        string query = input.HasKey("query") ? string(input["query"]).ToLower() : "";
        string requestedType = input.HasKey("type") ? string(input["type"]).ToLower() : "all";
        int limit = input.HasKey("limit") ? int(input["limit"]) : 25;
        if (limit < 1) limit = 1;
        if (limit > 200) limit = 200;

        Json::Value results = Json::Array();
        if (InventoryTypeEnabled(requestedType, "block")) {
            for (uint i = 0; i < editor.PluginMapType.BlockModels.Length && results.Length < uint(limit); i++) {
                auto blockInfo = editor.PluginMapType.BlockModels[i];
                if (!ModelMatchesQuery(blockInfo, query)) continue;
                auto entry = ModelToJson(blockInfo, false);
                entry["type"] = "block";
                results.Add(entry);
            }
        }
        if (InventoryTypeEnabled(requestedType, "item")) {
            uint nbItems = Editor::GetInventoryNbItems();
            for (uint i = 0; i < nbItems && results.Length < uint(limit); i++) {
                string path = Editor::GetInventoryItemPath(i);
                string name = Editor::GetInventoryItemName(i);
                if (!TextMatchesQuery(path, query) && !TextMatchesQuery(name, query)) continue;
                Json::Value entry = Json::Object();
                entry["type"] = "item";
                entry["name"] = name;
                entry["path"] = path;
                results.Add(entry);
            }
        }
        if (InventoryTypeEnabled(requestedType, "macroblock")) {
            for (uint i = 0; i < editor.PluginMapType.MacroblockModels.Length && results.Length < uint(limit); i++) {
                auto macroblockInfo = editor.PluginMapType.MacroblockModels[i];
                if (macroblockInfo is null) continue;
                string name = string(macroblockInfo.Name);
                string idName = string(macroblockInfo.IdName);
                if (!TextMatchesQuery(name, query) && !TextMatchesQuery(idName, query)) continue;
                results.Add(MacroblockModelToJson(macroblockInfo));
            }
        }

        Json::Value output = Json::Object();
        output["results"] = results;
        output["count"] = int(results.Length);
        output["query"] = query;
        output["type"] = requestedType;
        output["inventory"] = InventorySummary(editor.PluginMapType);
        return MakeSuccess(output);
    }

    Json::Value@ RefreshInventory(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        uint preCount = Editor::GetInventoryNbItems();
        Editor::RefreshInventoryCache();
        Json::Value output = Json::Object();
        output["nbItemsBefore"] = int(preCount);
        output["isScanningItems"] = Editor::IsInventoryScanningItems();
        output["note"] = "rescan started; poll GetInventorySummary until isScanningItems=false, then re-query";
        return MakeSuccess(output);
    }

    Json::Value@ GetInventorySummary(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        return MakeSuccess(InventorySummary(editor.PluginMapType));
    }

    Editor::MacroblockSpec@ GetNamedMacroblock(const string &in name) {
        int index = FindNamedMacroblockIndex(name);
        if (index < 0) return null;
        return g_NamedMacroblocks[index];
    }

    int FindNamedMacroblockIndex(const string &in name) {
        for (uint i = 0; i < g_NamedMacroblockNames.Length; i++) {
            if (g_NamedMacroblockNames[i] == name) return int(i);
        }
        return -1;
    }

    Json::Value NamedMacroblockSummary(const string &in name, Editor::MacroblockSpec@ mb) {
        Json::Value output = Json::Object();
        auto skins = GetNamedMacroblockSkins(name);
        output["name"] = name;
        output["exists"] = mb !is null;
        output["nbBlocks"] = mb is null ? 0 : int(mb.blocks.Length);
        output["nbItems"] = mb is null ? 0 : int(mb.items.Length);
        output["nbRawSkins"] = mb is null ? 0 : int(mb.skins.Length);
        output["nbPostSkins"] = skins is null ? 0 : int(skins.Length);
        output["nbSkins"] = int(output["nbRawSkins"]) + int(output["nbPostSkins"]);
        return output;
    }

    Json::Value BlockSpecToJson(Editor::BlockSpec@ block) {
        Json::Value obj = Json::Object();
        if (block is null) return obj;
        obj["name"] = block.name;
        obj["coord"] = CoordToJson(block.coord);
        obj["dir"] = int(block.dir);
        obj["dir2"] = int(block.dir2);
        obj["pos"] = Vec3ToJson(block.pos - MacroblockInternalOffset());
        obj["internalPos"] = Vec3ToJson(block.pos);
        obj["rot"] = Vec3ToJson(block.pyr);
        obj["rotDeg"] = Vec3DegToJson(block.pyr);
        obj["variant"] = int(block.variant);
        obj["flags"] = int(block.flags);
        obj["isFree"] = block.isFree;
        obj["isGround"] = block.isGround;
        obj["isGhost"] = block.isGhost;
        return obj;
    }

    Json::Value ItemSpecToJson(Editor::ItemSpec@ item) {
        Json::Value obj = Json::Object();
        if (item is null) return obj;
        obj["name"] = item.name;
        obj["coord"] = CoordToJson(item.coord);
        obj["pos"] = Vec3ToJson(item.pos - MacroblockInternalOffset());
        obj["internalPos"] = Vec3ToJson(item.pos);
        obj["rot"] = Vec3ToJson(item.pyr);
        obj["rotDeg"] = Vec3DegToJson(item.pyr);
        obj["variant"] = int(item.variantIx);
        obj["isFlying"] = item.isFlying != 0;
        return obj;
    }

    void ApplyTransformToSpec(Editor::BlockSpec@ block, const mat4 &in transform) {
        auto blockMat = mat4::Translate(block.pos) * Editor::EulerToMat(block.pyr);
        auto transformed = transform * blockMat;
        block.pos = (transformed * vec3()).xyz;
        block.pyr = Editor::PitchYawRollFromRotationMatrix(mat4::Translate(block.pos * -1.0) * transformed);
    }

    void ApplyTransformToSpec(Editor::ItemSpec@ item, const mat4 &in transform) {
        auto itemMat = mat4::Translate(item.pos) * Editor::EulerToMat(item.pyr);
        auto transformed = transform * itemMat;
        item.pos = (transformed * vec3()).xyz;
        item.pyr = Editor::PitchYawRollFromRotationMatrix(mat4::Translate(item.pos * -1.0) * transformed);
    }

    Editor::MacroblockSpec@ DuplicateAndTransformMacroblock(Editor::MacroblockSpec@ mb, vec3 offset, vec3 rotation, vec3 pivot) {
        auto copy = mb.Duplicate();
        auto internalPivot = pivot + MacroblockInternalOffset();
        auto transform = mat4::Translate(internalPivot + offset)
            * Editor::EulerToMat(rotation)
            * mat4::Translate(internalPivot * -1.0);
        for (uint i = 0; i < copy.blocks.Length; i++) {
            ApplyTransformToSpec(copy.blocks[i], transform);
        }
        for (uint i = 0; i < copy.items.Length; i++) {
            ApplyTransformToSpec(copy.items[i], transform);
        }
        return copy;
    }

    vec3 MacroblockInternalOffset() {
        return vec3(0, 56, 0);
    }

    CGameCtnBlockInfo@ ResolveBlockModel(CGameEditorPluginMap@ pluginMap, const string &in blockName, bool &out isTerrain) {
        isTerrain = false;
        CGameCtnBlockInfo@ blockInfo = pluginMap.GetBlockModelFromName(blockName);
        if (blockInfo !is null) return blockInfo;

        string lowerName = blockName.ToLower();
        for (uint i = 0; i < pluginMap.BlockModels.Length; i++) {
            @blockInfo = pluginMap.BlockModels[i];
            if (ModelNameMatches(blockInfo, lowerName)) return blockInfo;
        }

        isTerrain = true;
        @blockInfo = pluginMap.GetTerrainBlockModelFromName(blockName);
        if (blockInfo !is null) return blockInfo;

        for (uint i = 0; i < pluginMap.TerrainBlockModels.Length; i++) {
            @blockInfo = pluginMap.TerrainBlockModels[i];
            if (ModelNameMatches(blockInfo, lowerName)) return blockInfo;
        }

        isTerrain = false;
        return null;
    }

    CGameItemModel@ ResolveItemModel(const string &in itemPath) {
        return Editor::GetInventoryItemModelByPath(itemPath);
    }

}