#if DEPENDENCY_EDITOR
namespace TmMcpPackEpp {
    CGameCtnMacroBlockInfo@ ResolveMacroblockModel(CGameEditorPluginMap@ pmt, Json::Value &in input, string &out source) {
        source = "";
        if (pmt is null) return null;

        if (input.HasKey("index")) {
            int index = int(input["index"]);
            if (index < 0 || index >= int(pmt.MacroblockModels.Length)) {
                source = "index out of range";
                return null;
            }
            source = "index";
            return pmt.MacroblockModels[uint(index)];
        }

        if (input.HasKey("path")) {
            string path = string(input["path"]);
            auto model = pmt.GetMacroblockModelFromFilePath(path);
            source = "path";
            return model;
        }

        if (input.HasKey("name")) {
            string name = string(input["name"]);
            auto model = pmt.GetMacroblockModelFromName(name);
            if (model !is null) {
                source = "name";
                return model;
            }

            string lowerName = name.ToLower();
            for (uint i = 0; i < pmt.MacroblockModels.Length; i++) {
                @model = pmt.MacroblockModels[i];
                if (model is null) continue;
                if (string(model.Name).ToLower() == lowerName || string(model.IdName).ToLower() == lowerName) {
                    source = "name scan";
                    return model;
                }
            }
            source = "name";
        }
        return null;
    }

    Json::Value MacroblockInfoDetailsToJson(CGameCtnMacroBlockInfo@ model) {
        Json::Value output = MacroblockModelToJson(model);
        if (model is null) return output;
        output["connected"] = model.Connected;
        output["initialized"] = model.Initialized;
        output["isGround"] = model.IsGround;
        output["hasStart"] = model.HasStart;
        output["hasFinish"] = model.HasFinish;
        output["hasCheckpoint"] = model.HasCheckpoint;
        output["hasMultilap"] = model.HasMultilap;
        if (model.GeneratedBlockInfo !is null) {
            output["generatedBlockInfo"] = ModelToJson(model.GeneratedBlockInfo, false);
            if (model.GeneratedBlockInfo.VariantBaseGround !is null) {
                output["autoTerrain"] = AutoTerrainsToJson(model.GeneratedBlockInfo.VariantBaseGround);
            }
            // CGameCtnBlockInfo+0xF0: read by CGameCtnEditorCommon::PlaceMacroBlock
            // and passed to the AutoTerrains apply (FUN_141180030). Identify what
            // it points at: if it's the ground variant, +0x250 will be the
            // AutoTerrains buffer.
            uint64 biF0 = Dev::GetOffsetUint64(model.GeneratedBlockInfo, 0xF0);
            Json::Value f0 = Json::Object();
            f0["ptr"] = Text::FormatPointer(biF0);
            if (biF0 != 0) {
                f0["atBufPtr"] = Text::FormatPointer(Dev::ReadUInt64(biF0 + 0x250));
                f0["atBufLen"] = int(Dev::ReadUInt32(biF0 + 0x258));
                f0["heightOffset_0x260"] = Dev::ReadInt32(biF0 + 0x260);
                f0["placeType_0x264"] = Dev::ReadInt32(biF0 + 0x264);
                // compare first elements of mb buf (+0x1F8) vs variant buf (+0x250):
                // same CGameCtnAutoTerrain nods or distinct copies?
                uint64 mbBuf = Dev::GetOffsetUint64(model, 0x1F8);
                uint64 vgBuf = Dev::ReadUInt64(biF0 + 0x250);
                if (mbBuf != 0 && vgBuf != 0) {
                    f0["mbBufEl0"] = Text::FormatPointer(Dev::ReadUInt64(mbBuf));
                    f0["vgBufEl0"] = Text::FormatPointer(Dev::ReadUInt64(vgBuf));
                    f0["mbBufEl1"] = Text::FormatPointer(Dev::ReadUInt64(mbBuf + 8));
                    f0["vgBufEl1"] = Text::FormatPointer(Dev::ReadUInt64(vgBuf + 8));
                }
            }
            output["blockInfoF0"] = f0;
        }
        // CGameCtnMacroBlockInfo+0x1F8: buf of ptrs to autoterrain-related
        // structs (see tm-editor-plus-plus research/CGameCtnMacroBlockInfo.txt).
        // Dump ptr/len so we can correlate with GeneratedBlockInfo AutoTerrains.
        Json::Value atBuf = Json::Object();
        atBuf["ptr"] = Text::FormatPointer(Dev::GetOffsetUint64(model, 0x1F8));
        atBuf["len"] = int(Dev::GetOffsetUint32(model, 0x200));
        atBuf["cap"] = int(Dev::GetOffsetUint32(model, 0x204));
        output["macroblockAutoTerrainBuf"] = atBuf;
        // Raw words 0x1C0..0x210: placement code (CGameCtnEditorCommon::PlaceMacroBlock,
        // Trackmania.exe @141166180) reads ptrs at +0x1D0/+0x1D8 (zone-list structs)
        // and int3s at +0x1E0/+0x1EC during terrain application.
        Json::Value raw = Json::Object();
        for (uint off = 0x1C0; off < 0x210; off += 4) {
            raw[Text::Format("0x%03x", off)] = Text::Format("0x%08x", Dev::GetOffsetUint32(model, off));
        }
        output["macroblockRaw1C0"] = raw;
        Json::Value raw180 = Json::Object();
        for (uint off = 0x180; off < 0x1C0; off += 4) {
            raw180[Text::Format("0x%03x", off)] = Text::Format("0x%08x", Dev::GetOffsetUint32(model, off));
        }
        output["macroblockRaw180"] = raw180;
        return output;
    }

    // Terrain stored on a macroblock's generated ground variant.
    // CGameCtnBlockInfoVariantGround+0x250: MwFastBuffer<CGameCtnAutoTerrain@>.
    Json::Value AutoTerrainsToJson(CGameCtnBlockInfoVariantGround@ vg) {
        Json::Value output = Json::Object();
        output["autoTerrainPlaceType"] = tostring(vg.AutoTerrainPlaceType);
        output["autoTerrainHeightOffset"] = vg.AutoTerrainHeightOffset;
        output["autoTerrainWithFrontiers"] = vg.AutoTerrainWithFrontiers;
        output["count"] = int(vg.AutoTerrains.Length);
        Json::Value arr = Json::Array();
        uint nb = Math::Min(vg.AutoTerrains.Length, 500);
        for (uint i = 0; i < nb; i++) {
            arr.Add(AutoTerrainToJson(vg.AutoTerrains[i], i));
        }
        output["terrains"] = arr;
        return output;
    }

    // CGameCtnAutoTerrain (0x03120000, size 0x30): OffsetX/Y/Z ints somewhere in
    // 0x18..0x27 (unmapped in OP), CGameCtnZoneGenealogy@ Genealogy @0x28.
    Json::Value AutoTerrainToJson(CGameCtnAutoTerrain@ at, int index) {
        Json::Value output = Json::Object();
        if (at is null) return output;
        output["index"] = index;
        // dump candidate words for OffsetX/Y/Z until offsets are confirmed
        Json::Value raw = Json::Object();
        for (uint off = 0x10; off <= 0x28; off += 4) {
            raw[Text::Format("0x%02x", off)] = Dev::GetOffsetInt32(at, off);
        }
        output["rawInts"] = raw;
        if (at.Genealogy !is null) {
            output["genealogy"] = ZoneGenealogyToJson(at.Genealogy);
        }
        return output;
    }

    // Map terrain grid: CGameCtnChallenge+0x390 is a buffer of
    // CGameCtnZoneGenealogy@ (one per XZ cell; len at +0x398), per
    // CGameCtnEditorCommon::PlaceTerrainFrontierBlocks (Trackmania.exe @14117f1f0).
    // Map size fields used for flattening: +0x268 (x), +0x26C (y), +0x270 (z).
    Json::Value@ GetMapTerrainGrid(Json::Value &in input) {
        auto map = GetApp().RootMap;
        if (map is null) return MakeError("no root map");
        uint64 gridPtr = Dev::GetOffsetUint64(map, 0x390);
        uint gridLen = Dev::GetOffsetUint32(map, 0x398);
        int3 sizeFields = int3(Dev::GetOffsetInt32(map, 0x268), Dev::GetOffsetInt32(map, 0x26C), Dev::GetOffsetInt32(map, 0x270));
        Json::Value output = Json::Object();
        output["gridPtr"] = Text::FormatPointer(gridPtr);
        output["gridLen"] = int(gridLen);
        output["sizeFields_0x268"] = sizeFields.ToString();
        output["mapSize"] = map.Size.ToString();
        // map+0x200 int3: compared against macroblock+0x1E0 in
        // CGameCtnEditorCommon::PlaceMacroBlock terrain-apply gate
        Json::Value raw200 = Json::Object();
        for (uint off = 0x1F8; off < 0x214; off += 4) {
            raw200[Text::Format("0x%03x", off)] = Dev::GetOffsetInt32(map, off);
        }
        output["mapRaw1F8"] = raw200;
        int cx = input.HasKey("x") ? int(input["x"]) : 0;
        int cz = input.HasKey("z") ? int(input["z"]) : 0;
        int w = input.HasKey("w") ? int(input["w"]) : 4;
        int h = input.HasKey("h") ? int(input["h"]) : 4;
        if (w > 32) w = 32;
        if (h > 32) h = 32;
        Json::Value cells = Json::Array();
        for (int z = cz; z < cz + h; z++) {
            for (int x = cx; x < cx + w; x++) {
                Json::Value cell = Json::Object();
                cell["x"] = x; cell["z"] = z;
                // flatten guess: x + z*sizeX
                uint ix = uint(x) + uint(z) * uint(sizeFields.x);
                cell["ix"] = int(ix);
                if (ix >= gridLen || gridPtr == 0) { cell["oob"] = true; cells.Add(cell); continue; }
                uint64 genPtr = Dev::ReadUInt64(gridPtr + ix * 8);
                cell["genPtr"] = Text::FormatPointer(genPtr);
                if (genPtr != 0) cell["genealogy"] = ZoneGenealogyRawToJson(genPtr);
                cells.Add(cell);
            }
        }
        output["cells"] = cells;
        return MakeSuccess(output);
    }

    // Decode a CGameCtnZoneGenealogy from a raw pointer (no typed handle).
    // Offsets per Openplanet docs: CurrentZone @0x18, Zones buf @0x20,
    // ZoneHeights buf @0x30 (int), CurrentIndex @0x40, Dir @0x44,
    // ZoneIds buf @0x48 (MwId), CurrentZoneId @0x58, BaseHeight @0x5C,
    // BottomHeight @0x60, TopHeight @0x64.
    Json::Value ZoneGenealogyRawToJson(uint64 genPtr) {
        Json::Value output = Json::Object();
        output["currentIndex"] = Dev::ReadInt32(genPtr + 0x40);
        output["dir"] = Dev::ReadInt32(genPtr + 0x44);
        output["baseHeight"] = Dev::ReadInt32(genPtr + 0x5C);
        output["bottomHeight"] = Dev::ReadInt32(genPtr + 0x60);
        output["topHeight"] = Dev::ReadInt32(genPtr + 0x64);
        output["currentZoneId"] = Dev::ReadUInt32(genPtr + 0x58);
        uint64 zonesPtr = Dev::ReadUInt64(genPtr + 0x20);
        uint zonesLen = Dev::ReadUInt32(genPtr + 0x28);
        uint64 heightsPtr = Dev::ReadUInt64(genPtr + 0x30);
        uint heightsLen = Dev::ReadUInt32(genPtr + 0x38);
        uint64 zoneIdsPtr = Dev::ReadUInt64(genPtr + 0x48);
        uint zoneIdsLen = Dev::ReadUInt32(genPtr + 0x50);
        output["nbZones"] = int(zonesLen);
        Json::Value zones = Json::Array();
        for (uint i = 0; i < zonesLen && i < 16; i++) {
            zones.Add(Text::FormatPointer(Dev::ReadUInt64(zonesPtr + i * 8)));
        }
        output["zonePtrs"] = zones;
        Json::Value heights = Json::Array();
        for (uint i = 0; i < heightsLen && i < 16; i++) {
            heights.Add(Dev::ReadInt32(heightsPtr + i * 4));
        }
        output["zoneHeights"] = heights;
        Json::Value ids = Json::Array();
        for (uint i = 0; i < zoneIdsLen && i < 16; i++) {
            ids.Add(Text::Format("0x%08x", Dev::ReadUInt32(zoneIdsPtr + i * 4)));
        }
        output["zoneIdValues"] = ids;
        return output;
    }

    Json::Value ZoneGenealogyToJson(CGameCtnZoneGenealogy@ gen) {
        Json::Value output = Json::Object();
        output["currentIndex"] = gen.CurrentIndex;
        output["dir"] = tostring(gen.Dir);
        output["baseHeight"] = gen.BaseHeight;
        output["bottomHeight"] = gen.BottomHeight;
        output["topHeight"] = gen.TopHeight;
        output["nbZones"] = int(gen.Zones.Length);
        Json::Value heights = Json::Array();
        for (uint i = 0; i < gen.ZoneHeights.Length; i++) {
            heights.Add(gen.ZoneHeights[i]);
        }
        output["zoneHeights"] = heights;
        Json::Value zoneIds = Json::Array();
        for (uint i = 0; i < gen.ZoneIds.Length; i++) {
            zoneIds.Add(gen.ZoneIds[i].GetName());
        }
        output["zoneIds"] = zoneIds;
        // zone nod ptrs (raw) so raw grid dumps can be name-mapped by pointer
        uint64 zonesPtr = Dev::GetOffsetUint64(gen, 0x20);
        Json::Value zonePtrs = Json::Array();
        for (uint i = 0; i < gen.Zones.Length && i < 16; i++) {
            zonePtrs.Add(Text::FormatPointer(Dev::ReadUInt64(zonesPtr + i * 8)));
        }
        output["zonePtrs"] = zonePtrs;
        return output;
    }

    Json::Value MacroblockSpecContentsToJson(Editor::MacroblockSpec@ spec, int limit, bool includeItems) {
        Json::Value output = Json::Object();
        if (spec is null) return output;
        output["nbBlocks"] = int(spec.blocks.Length);
        output["nbItems"] = int(spec.items.Length);

        Json::Value blocks = Json::Array();
        for (uint i = 0; i < spec.blocks.Length && blocks.Length < uint(limit); i++) {
            auto obj = BlockSpecToJson(spec.blocks[i]);
            obj["index"] = int(i);
            blocks.Add(obj);
        }
        output["blocks"] = blocks;

        Json::Value items = Json::Array();
        if (includeItems) {
            for (uint i = 0; i < spec.items.Length && items.Length < uint(limit); i++) {
                auto obj = ItemSpecToJson(spec.items[i]);
                obj["index"] = int(i);
                items.Add(obj);
            }
        }
        output["items"] = items;
        output["returnedBlocks"] = int(blocks.Length);
        output["returnedItems"] = int(items.Length);
        return output;
    }

    // Native macroblock placement for ground-truth experiments (NOT the E++
    // donor/temp-write path). mode: "ground" (PlaceMacroblock, applies terrain),
    // "noTerrain" (PlaceMacroblock_NoTerrain), "air" (PlaceMacroblock_AirMode).
    Json::Value@ PlaceMacroblockModelNative(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available");
        string source;
        auto model = ResolveMacroblockModel(editor.PluginMapType, input, source);
        if (model is null) return MakeError("macroblock model not found via " + source);
        int x = input.HasKey("x") ? int(input["x"]) : 0;
        int y = input.HasKey("y") ? int(input["y"]) : 1;
        int z = input.HasKey("z") ? int(input["z"]) : 0;
        string mode = input.HasKey("mode") ? string(input["mode"]) : "ground";
        auto pmt = editor.PluginMapType;
        auto coord = int3(x, y, z);
        auto dir = CGameEditorPluginMap::ECardinalDirections::North;
        bool canPlace = false;
        bool placed = false;
        string err = "";
        try {
            if (mode == "ground") {
                canPlace = pmt.CanPlaceMacroblock(model, coord, dir);
                if (canPlace || (input.HasKey("force") && bool(input["force"])))
                    placed = pmt.PlaceMacroblock(model, coord, dir);
            } else if (mode == "noTerrain") {
                canPlace = pmt.CanPlaceMacroblock_NoTerrain(model, coord, dir);
                if (canPlace || (input.HasKey("force") && bool(input["force"])))
                    placed = pmt.PlaceMacroblock_NoTerrain(model, coord, dir);
            } else if (mode == "air") {
                canPlace = pmt.CanPlaceMacroblock(model, coord, dir);
                if (canPlace || (input.HasKey("force") && bool(input["force"])))
                    placed = pmt.PlaceMacroblock_AirMode(model, coord, dir);
            } else {
                return MakeError("unknown mode: " + mode + " (expected ground|noTerrain|air)");
            }
        } catch {
            err = getExceptionInfo();
        }
        Json::Value output = Json::Object();
        output["mode"] = mode;
        output["canPlace"] = canPlace;
        output["placed"] = placed;
        output["coord"] = coord.ToString();
        output["modelName"] = string(model.Name);
        output["modelIsGround"] = model.IsGround;
        if (err != "") output["error"] = err;
        return MakeSuccess(output);
    }

    // E++ donor-path placement (NOT the native path): builds an E++
    // MacroblockSpec from a native model — exercising E++'s terrain capture
    // from mb+0x1F8 — then places via Editor::PlaceMacroblock (air-mode
    // blocks/items pass + ground-mode terrain pass). Reports spec contents so
    // terrain capture can be verified (nbTerrains should match the model's
    // AutoTerrains length).
    Json::Value@ PlaceMacroblockModelViaEppSpec(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available");
        string source;
        auto model = ResolveMacroblockModel(editor.PluginMapType, input, source);
        if (model is null) return MakeError("macroblock model not found via " + source);
        Json::Value output = Json::Object();
        output["modelName"] = string(model.Name);
        string err = "";
        bool placed = false;
        try {
            auto spec = Editor::MakeMacroblockSpec(model);
            output["nbBlocks"] = int(spec.blocks.Length);
            output["nbItems"] = int(spec.items.Length);
            output["nbTerrains"] = int(spec.Terrains.Length);
            placed = Editor::PlaceMacroblock(spec, false);
        } catch {
            err = getExceptionInfo();
        }
        output["placed"] = placed;
        if (err != "") output["error"] = err;
        return MakeSuccess(output);
    }

    // DEV probe: temporarily set the AutoTerrains length on either the
    // generated ground variant (+0x258) or the macroblock's own buf (+0x200)
    // to identify which one native ground placement consumes. Caller must
    // restore (read current value first via InspectMacroblockModel).
    Json::Value@ SetMacroblockAutoTerrainLen(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available");
        string source;
        auto model = ResolveMacroblockModel(editor.PluginMapType, input, source);
        if (model is null) return MakeError("macroblock model not found via " + source);
        string which = input.HasKey("which") ? string(input["which"]) : "variant";
        uint value = input.HasKey("value") ? uint(input["value"]) : 0;
        Json::Value output = Json::Object();
        if (which == "variant") {
            auto vg = model.GeneratedBlockInfo is null ? null : model.GeneratedBlockInfo.VariantBaseGround;
            if (vg is null) return MakeError("no ground variant");
            output["oldLen"] = int(vg.AutoTerrains.Length);
            Dev::SetOffset(vg, 0x258, value);
            output["newLen"] = int(Dev::GetOffsetUint32(vg, 0x258));
        } else if (which == "mb") {
            output["oldLen"] = int(Dev::GetOffsetUint32(model, 0x200));
            Dev::SetOffset(model, 0x200, value);
            output["newLen"] = int(Dev::GetOffsetUint32(model, 0x200));
        } else {
            return MakeError("which must be variant|mb");
        }
        return MakeSuccess(output);
    }

    Json::Value@ InspectMacroblockModel(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available");
        if (!input.HasKey("name") && !input.HasKey("path") && !input.HasKey("index")) {
            return MakeError("missing name, path, or index");
        }

        string source;
        auto model = ResolveMacroblockModel(editor.PluginMapType, input, source);
        if (model is null) return MakeError("macroblock model not found via " + source);

        int limit = input.HasKey("limit") ? int(input["limit"]) : 100;
        if (limit < 1) limit = 1;
        if (limit > 500) limit = 500;
        bool includeItems = input.HasKey("includeItems") ? bool(input["includeItems"]) : true;

        Editor::MacroblockSpec@ spec = null;
        string specError = "";
        try {
            @spec = Editor::MakeMacroblockSpec(model);
        } catch {
            specError = getExceptionInfo();
        }

        Json::Value output = Json::Object();
        output["source"] = source;
        output["model"] = MacroblockInfoDetailsToJson(model);
        output["limit"] = limit;
        output["includeItems"] = includeItems;
        output["contents"] = MacroblockSpecContentsToJson(spec, limit, includeItems);
        output["specOk"] = spec !is null;
        output["specError"] = specError;
        output["skinNote"] = "Block skins are not included here; this uses E++ MacroblockSpec block/item conversion.";
        output["inventory"] = InventorySummary(editor.PluginMapType);
        return MakeSuccess(output);
    }

    Json::Value MacroblockInstanceToJson(CGameEditorMapMacroBlockInstance@ inst, int index, int unitCoordLimit) {
        Json::Value output = Json::Object();
        if (inst is null) return output;
        output["index"] = index;
        output["order"] = int(inst.Order);
        output["coord"] = Int3ToJson(inst.Coord);
        output["dir"] = int(inst.Dir);
        output["userData"] = inst.UserData;
        output["size"] = CoordToJson(inst.GetSize());
        output["color"] = int(inst.Color);
        output["forceMacroblockColor"] = inst.ForceMacroblockColor;
        output["model"] = MacroblockInfoDetailsToJson(inst.MacroblockModel);

        Json::Value unitCoords = Json::Array();
        for (uint i = 0; i < inst.UnitCoords.Length && unitCoords.Length < uint(unitCoordLimit); i++) {
            unitCoords.Add(CoordToJson(inst.UnitCoords[i]));
        }
        output["unitCoords"] = unitCoords;
        output["nbUnitCoords"] = int(inst.UnitCoords.Length);
        output["returnedUnitCoords"] = int(unitCoords.Length);
        output["unitCoordsTruncated"] = inst.UnitCoords.Length > uint(unitCoordLimit);
        return output;
    }

    Json::Value@ ListMacroblockInstances(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available");

        int total = int(editor.PluginMapType.MacroblockInstances.Length);
        int limit = input.HasKey("limit") ? int(input["limit"]) : 50;
        if (limit < 1) limit = 1;
        if (limit > 250) limit = 250;
        int offset = input.HasKey("offset") ? int(input["offset"]) : 0;
        if (offset < 0) offset = 0;
        bool recent = input.HasKey("recent") ? bool(input["recent"]) : false;
        int unitCoordLimit = input.HasKey("unitCoordLimit") ? int(input["unitCoordLimit"]) : 50;
        if (unitCoordLimit < 0) unitCoordLimit = 0;
        if (unitCoordLimit > 500) unitCoordLimit = 500;

        int start = recent ? Math::Max(0, total - offset - limit) : offset;
        int end = recent ? Math::Max(0, total - offset) : Math::Min(total, start + limit);

        Json::Value instances = Json::Array();
        for (int i = start; i < end; i++) {
            auto inst = editor.PluginMapType.MacroblockInstances[uint(i)];
            instances.Add(MacroblockInstanceToJson(inst, i, unitCoordLimit));
        }

        Json::Value output = Json::Object();
        output["instances"] = instances;
        output["count"] = int(instances.Length);
        output["total"] = total;
        output["offset"] = offset;
        output["limit"] = limit;
        output["recent"] = recent;
        output["unitCoordLimit"] = unitCoordLimit;
        output["inventory"] = InventorySummary(editor.PluginMapType);
        return MakeSuccess(output);
    }
}
#endif
