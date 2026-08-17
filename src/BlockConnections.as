#if DEPENDENCY_EDITOR
namespace TmMcpPackEpp {
    // Block connectivity + grid placement tools.
    // Engine semantics probed 2026-08-17 (research/getconnectresults-findings.md):
    //  - GetConnectResults(block, info) fills pmt.ConnectResults with {CanPlace, Coord, Dir}
    //    rows = valid placement options for the NEW block that attach it to the existing block.
    //  - NEVER pass a null candidate: GetConnectResults(block, null) hard-crashes the game.
    //  - Road-family models return 0 results (roads use frontier matching, not clips).
    //  - Free blocks have no grid connectivity (sentinel coord x/z=0xFFFFFFFF).
    //  - CanPlace in results is connection-geometry validity; fits-in-space needs an
    //    explicit CanPlaceBlock(_NoDestruction) probe per row.

    string ConnectDirName(CGameEditorPluginMap::ECardinalDirections d) {
        switch (d) {
            case CGameEditorPluginMap::ECardinalDirections::North: return "North";
            case CGameEditorPluginMap::ECardinalDirections::East: return "East";
            case CGameEditorPluginMap::ECardinalDirections::South: return "South";
            case CGameEditorPluginMap::ECardinalDirections::West: return "West";
        }
        return "Unknown";
    }

    int ConnectDirIndex(CGameEditorPluginMap::ECardinalDirections d) {
        return int(d);
    }

    bool CoordOccupied(CGameCtnChallenge@ map, int x, int y, int z) {
        for (uint i = 0; i < map.Blocks.Length; i++) {
            auto b = map.Blocks[i];
            if (b is null) continue;
            auto c = b.Coord;
            if (c.x >= 1000000) continue; // free block sentinel
            if (int(c.x) == x && int(c.y) == y && int(c.z) == z) return true;
        }
        return false;
    }

    CGameCtnBlock@ FindGridBlockByCoord(CGameCtnChallenge@ map, int x, int y, int z) {
        for (uint i = 0; i < map.Blocks.Length; i++) {
            auto b = map.Blocks[i];
            if (b is null) continue;
            auto c = b.Coord;
            if (c.x >= 1000000) continue;
            if (int(c.x) == x && int(c.y) == y && int(c.z) == z) return b;
        }
        return null;
    }

    bool FindEmptyCoord(CGameCtnEditorFree@ editor, int3 &out coord) {
        auto map = editor.Challenge;
        auto size = map.Size;
        // search from far corner inward; y=9 (first layer above ground top y=8m -> coord y 9)
        for (int x = int(size.x) - 3; x >= 2; x--) {
            for (int z = int(size.z) - 3; z >= 2; z--) {
                for (int y = int(size.y) - 2; y >= 9; y--) {
                    if (!CoordOccupied(map, x, y, z)) {
                        coord = int3(x, y, z);
                        return true;
                    }
                }
            }
        }
        return false;
    }

    Json::Value ConnectRowToJson(int3 coord, CGameEditorPluginMap::ECardinalDirections dir, bool canConnect,
                                 bool probeFits, CGameCtnBlockInfo@ candInfo, CGameEditorPluginMap@ pmt, bool onGround) {
        Json::Value row = Json::Object();
        row["coord"] = Int3ToJson(coord);
        row["dir"] = ConnectDirName(dir);
        row["dirIndex"] = ConnectDirIndex(dir);
        row["canConnect"] = canConnect;
        if (probeFits) {
            bool fits = pmt.CanPlaceBlock(candInfo, coord, dir, onGround, 0);
            bool fitsND = pmt.CanPlaceBlock_NoDestruction(candInfo, coord, dir, onGround, 0);
            row["fits"] = fits;
            row["fitsNoDestruction"] = fitsND;
        }
        return row;
    }

    // Run GetConnectResults for one candidate against a source block; returns candidate JSON object
    // or null if skipped by filters. NEVER call with null candInfo (game crash).
    Json::Value@ RunConnectCandidate(CGameEditorPluginMap@ pmt, CGameCtnBlock@ srcBlock, CGameCtnBlockInfo@ candInfo,
                                     bool fitsSpace, bool onlyPlaceable, bool onGround,
                                     int rowsLeft, int &out rowsAdded) {
        rowsAdded = 0;
        if (candInfo is null) return null;
        pmt.GetConnectResults(srcBlock, candInfo);
        uint n = pmt.ConnectResults.Length;
        Json::Value rows = Json::Array();
        for (uint i = 0; i < n; i++) {
            auto r = pmt.ConnectResults[i];
            if (onlyPlaceable && !r.CanPlace) continue;
            if (rowsLeft >= 0 && int(rows.Length) >= rowsLeft) break;
            rows.Add(ConnectRowToJson(r.Coord, r.Dir, r.CanPlace, fitsSpace, candInfo, pmt, onGround));
        }
        if (rows.Length == 0) return null;
        rowsAdded = int(rows.Length);
        Json::Value cand = Json::Object();
        cand["name"] = string(candInfo.Name);
        cand["idName"] = string(candInfo.IdName);
        cand["results"] = rows;
        return cand;
    }

    Json::Value@ GetBlockConnections(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) return NeedEditor();
        auto pmt = editor.PluginMapType;
        auto map = editor.Challenge;

        CGameCtnBlock@ src = null;
        int srcIndex = -1;
        if (input.HasKey("index")) {
            int idx = int(input["index"]);
            if (idx < 0 || uint(idx) >= map.Blocks.Length) return Err("index out of range: " + idx);
            @src = map.Blocks[uint(idx)];
            srcIndex = idx;
        } else if (input.HasKey("coord")) {
            auto c = input["coord"];
            if (c.GetType() != Json::Type::Array || c.Length < 3) return Err("coord must be [x,y,z]");
            @src = FindGridBlockByCoord(map, int(c[0]), int(c[1]), int(c[2]));
            if (src is null) return Err("no grid block at coord", "not_found");
        } else {
            return Err("pass index or coord");
        }
        if (src is null || src.BlockInfo is null) return Err("block has no BlockInfo");
        if (Editor::IsBlockFree(src) || src.Coord.x >= 1000000) {
            return Err("free blocks have no grid connectivity", "free_block");
        }

        bool fitsSpace = input.HasKey("fitsSpace") ? bool(input["fitsSpace"]) : false;
        bool onlyPlaceable = input.HasKey("onlyPlaceable") ? bool(input["onlyPlaceable"]) : false;
        bool onGround = input.HasKey("onGround") ? bool(input["onGround"]) : true;
        int limit = input.HasKey("limit") ? int(input["limit"]) : 200;
        if (limit < 1) limit = 1;
        string query = input.HasKey("query") ? string(input["query"]).ToLower() : "";

        Json::Value candidates = Json::Array();
        int scanned = 0;
        int totalRows = 0;
        bool truncated = false;

        if (input.HasKey("newBlockName")) {
            string want = string(input["newBlockName"]);
            bool isTerrain = false;
            auto info = ResolveBlockModel(pmt, want, isTerrain);
            if (info is null) {
                // fallback: model not in inventory — reuse BlockInfo from a placed block of that name
                for (uint i = 0; i < map.Blocks.Length; i++) {
                    auto b = map.Blocks[i];
                    if (b !is null && b.BlockInfo !is null && ModelNameMatches(b.BlockInfo, want.ToLower())) {
                        @info = b.BlockInfo;
                        break;
                    }
                }
            }
            if (info is null) return Err("block model not found: " + want, "not_found");
            int added = 0;
            auto cand = RunConnectCandidate(pmt, src, info, fitsSpace, onlyPlaceable, onGround, limit, added);
            scanned++;
            if (cand !is null) { candidates.Add(cand); totalRows += added; }
        } else {
            for (uint i = 0; i < pmt.BlockModels.Length; i++) {
                auto info = pmt.BlockModels[i];
                if (info is null) continue;
                if (query.Length > 0 && !ModelMatchesQuery(info, query)) continue;
                scanned++;
                int added = 0;
                int rowsLeft = limit - totalRows;
                if (rowsLeft <= 0) { truncated = true; break; }
                auto cand = RunConnectCandidate(pmt, src, info, fitsSpace, onlyPlaceable, onGround, rowsLeft, added);
                if (cand !is null) { candidates.Add(cand); totalRows += added; }
            }
            if (scanned >= int(pmt.BlockModels.Length) && totalRows >= limit) truncated = true;
        }

        auto o = Json::Object();
        auto blk = Json::Object();
        if (srcIndex >= 0) blk["index"] = srcIndex;
        blk["name"] = string(src.BlockInfo.IdName);
        blk["coord"] = CoordToJson(src.Coord);
        blk["dir"] = int(src.BlockDir);
        o["block"] = blk;
        o["candidates"] = candidates;
        o["candidateCount"] = int(candidates.Length);
        o["scanned"] = scanned;
        o["totalRows"] = totalRows;
        o["truncated"] = truncated;
        o["note"] = "results rows are placement options for the candidate block: absolute map coord + dir the candidate must face to attach to the source block. Empty per-model results mean no clip-based connection (road-family models connect via frontier matching and report none).";
        return Ok(o);
    }

    Json::Value@ FindConnectingBlocks(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) return NeedEditor();
        auto pmt = editor.PluginMapType;
        if (!input.HasKey("blockName")) return Err("missing blockName");
        string blockName = string(input["blockName"]);
        bool isTerrain = false;
        auto info = ResolveBlockModel(pmt, blockName, isTerrain);
        if (info is null) return Err("block not found: " + blockName);
        if (isTerrain) return Err("terrain models have no clip connectivity", "terrain");

        auto dir = CGameEditorPluginMap::ECardinalDirections::North;
        if (input.HasKey("dir")) dir = DirFromString(string(input["dir"]));
        bool onlyPlaceable = input.HasKey("onlyPlaceable") ? bool(input["onlyPlaceable"]) : false;
        int limit = input.HasKey("limit") ? int(input["limit"]) : 200;
        if (limit < 1) limit = 1;
        string query = input.HasKey("query") ? string(input["query"]).ToLower() : "";

        int3 tempCoord;
        if (!FindEmptyCoord(editor, tempCoord)) return Err("no empty coord found for temp block", "no_space");

        uint blocksBefore = editor.Challenge.Blocks.Length;
        bool placed = false;
        try { placed = pmt.PlaceBlock_NoDestruction(info, tempCoord, dir); } catch {
            return Err("temp PlaceBlock threw: " + getExceptionInfo(), "epp_exception");
        }
        if (!placed) return Err("failed to place temp block at " + tempCoord.ToString(), "place_failed");

        CGameCtnBlock@ tempBlock = FindGridBlockByCoord(editor.Challenge, tempCoord.x, tempCoord.y, tempCoord.z);
        if (tempBlock is null) {
            return Err("temp block placed but not found at coord", "internal");
        }

        Json::Value candidates = Json::Array();
        int scanned = 0;
        int totalRows = 0;
        bool truncated = false;
        for (uint i = 0; i < pmt.BlockModels.Length; i++) {
            auto candInfo = pmt.BlockModels[i];
            if (candInfo is null) continue;
            if (query.Length > 0 && !ModelMatchesQuery(candInfo, query)) continue;
            scanned++;
            int added = 0;
            int rowsLeft = limit - totalRows;
            if (rowsLeft <= 0) { truncated = true; break; }
            // fitsSpace=false: coords are relative to a synthetic temp placement, fits is meaningless there
            auto cand = RunConnectCandidate(pmt, tempBlock, candInfo, false, onlyPlaceable, true, rowsLeft, added);
            if (cand !is null) { candidates.Add(cand); totalRows += added; }
        }

        // cleanup: delete temp block on every path from here
        bool cleaned = false;
        Editor::BlockSpec@[] specs;
        auto spec = Editor::MakeBlockSpec(tempBlock);
        if (spec !is null) {
            specs.InsertLast(spec);
            Editor::ItemSpec@[] noItems;
            try { cleaned = Editor::DeleteBlocksAndItems(specs, noItems, false); } catch {
                warn("FindConnectingBlocks: temp block cleanup threw: " + getExceptionInfo());
            }
        }
        uint blocksAfter = editor.Challenge.Blocks.Length;

        auto o = Json::Object();
        auto src = Json::Object();
        src["name"] = string(info.IdName);
        src["dir"] = ConnectDirName(dir);
        src["dirIndex"] = ConnectDirIndex(dir);
        o["source"] = src;
        o["tempCoord"] = Int3ToJson(tempCoord);
        o["candidates"] = candidates;
        o["candidateCount"] = int(candidates.Length);
        o["scanned"] = scanned;
        o["totalRows"] = totalRows;
        o["truncated"] = truncated;
        o["tempBlockCleaned"] = cleaned && blocksAfter <= blocksBefore;
        o["note"] = "coords are absolute map coords relative to the temp source block at tempCoord; subtract tempCoord for source-relative offsets. Empty results for a model mean no clip-based connection to the source.";
        if (!cleaned) o["warning"] = "temp block cleanup failed; a " + string(info.IdName) + " may remain at " + tempCoord.ToString();
        return Ok(o);
    }

    Json::Value@ PlaceGridBlock(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) return NeedEditor();
        auto pmt = editor.PluginMapType;
        if (!input.HasKey("blockName")) return Err("missing blockName");
        string blockName = string(input["blockName"]);
        bool isTerrain = false;
        auto info = ResolveBlockModel(pmt, blockName, isTerrain);
        if (info is null) return Err("block not found: " + blockName);
        if (isTerrain) return Err("terrain models are not supported (use free placement)", "terrain");

        int3 coord;
        bool hasCoord = input.HasKey("coord");
        bool hasXYZ = input.HasKey("x") && input.HasKey("y") && input.HasKey("z");
        if (hasCoord) {
            auto c = input["coord"];
            if (c.GetType() != Json::Type::Array || c.Length < 3) return Err("coord must be [x,y,z]");
            coord = int3(int(c[0]), int(c[1]), int(c[2]));
        } else if (hasXYZ) {
            vec3 v = JsonToVec3(input);
            coord = int3(int(Math::Floor(v.x / 32.0)), int(Math::Floor((v.y + 64.0) / 8.0)), int(Math::Floor(v.z / 32.0)));
        } else {
            return Err("pass coord [x,y,z] or world x,y,z meters");
        }

        auto dir = CGameEditorPluginMap::ECardinalDirections::North;
        if (input.HasKey("dir")) dir = DirFromString(string(input["dir"]));
        uint variant = input.HasKey("variant") ? uint(int(input["variant"])) : 0;
        bool onGround = input.HasKey("onGround") ? bool(input["onGround"]) : true;
        bool noDestruction = input.HasKey("noDestruction") ? bool(input["noDestruction"]) : true;
        bool ghost = input.HasKey("ghost") ? bool(input["ghost"]) : false;

        bool canPlace = false;
        if (ghost) {
            canPlace = pmt.CanPlaceGhostBlock(info, coord, dir);
        } else if (noDestruction) {
            canPlace = pmt.CanPlaceBlock_NoDestruction(info, coord, dir, onGround, variant);
        } else {
            canPlace = pmt.CanPlaceBlock(info, coord, dir, onGround, variant);
        }

        auto o = Json::Object();
        o["blockName"] = string(info.IdName);
        o["coord"] = Int3ToJson(coord);
        o["dir"] = ConnectDirName(dir);
        o["dirIndex"] = ConnectDirIndex(dir);
        o["ghost"] = ghost;
        o["noDestruction"] = noDestruction;
        o["canPlace"] = canPlace;

        if (!canPlace) {
            o["placed"] = false;
            o["note"] = "engine refused placement (occupied, out of bounds, or invalid variant/connection).";
            return Ok(o);
        }

        uint blocksBefore = editor.Challenge.Blocks.Length;
        bool placed = false;
        try {
            if (ghost) placed = pmt.PlaceGhostBlock(info, coord, dir);
            else if (noDestruction) placed = pmt.PlaceBlock_NoDestruction(info, coord, dir);
            else placed = pmt.PlaceBlock(info, coord, dir);
        } catch {
            return Err("PlaceBlock threw: " + getExceptionInfo(), "epp_exception");
        }
        o["placed"] = placed;
        o["beforeBlocks"] = int(blocksBefore);
        o["afterBlocks"] = int(editor.Challenge.Blocks.Length);

        if (placed) {
            vec3 worldPos = vec3(float(coord.x) * 32.0, float(coord.y) * 8.0 - 64.0, float(coord.z) * 32.0);
            o["pos"] = Vec3ToJson(worldPos);
            string tag = ResolvePlacementTag(input);
            if (tag.Length > 0) {
                RecordTaggedPlacement(tag, "block", string(info.IdName), worldPos, int(blocksBefore));
                o["tag"] = tag;
            }
            if (input.HasKey("autofocus") ? bool(input["autofocus"]) : false) {
                AutofocusCameraOn(worldPos, 60.0);
            }
        }
        return Ok(o);
    }
}
#endif
