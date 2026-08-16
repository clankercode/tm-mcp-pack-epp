// MapOverview: agent-friendly compressed map summaries + zoom-in queries.
// The raw GetBlocks/GetItems tools page ~100 objects per ~18KB call; a map
// with thousands of blocks costs dozens of calls and floods the context.
// This tool summarizes the whole map in one compact response and gives every
// summary row an echo-able `query` for drilling into details.
namespace TmMcpPackEpp {

    // ---- block classification -------------------------------------------------

    bool IsTerrainLikeName(const string &in name) {
        // Stadium terrain blocks: Grass, Dirt, Road* with "Ground" in name, etc.
        string n = name.ToLower();
        return n.StartsWith("grass") || n.StartsWith("dirt") || n.StartsWith("roadgrass")
            || n.StartsWith("roaddirt") || n.StartsWith("techgras") || n.StartsWith("techdirt");
    }

    bool IsRoadLikeName(const string &in name) {
        string n = name.ToLower();
        return n.StartsWith("road") && !IsTerrainLikeName(name);
    }

    string BlockCategory(const string &in name) {
        if (IsTerrainLikeName(name)) return "terrain";
        if (IsRoadLikeName(name)) return "road";
        return "building";
    }

    // ---- summary state ---------------------------------------------------------

    class BlockNameSummary {
        string name;
        string category;
        uint count;
        int3 lo;      // grid coords (min)
        int3 hi;      // grid coords (max)
        bool sawGhost;
        bool sawGround;
        bool sawFree;
        vec3 wlo;
        vec3 whi;
        BlockNameSummary(const string &in n) {
            name = n; category = BlockCategory(n); count = 0;
            sawGhost = false; sawGround = false; sawFree = false;
            wlo = vec3(1e30, 1e30, 1e30); whi = vec3(-1e30, -1e30, -1e30);
        }
        void Add(vec3 wpos, bool ghost, bool ground, bool free) {
            count++;
            wlo.x = Math::Min(wlo.x, wpos.x); wlo.y = Math::Min(wlo.y, wpos.y); wlo.z = Math::Min(wlo.z, wpos.z);
            whi.x = Math::Max(whi.x, wpos.x); whi.y = Math::Max(whi.y, wpos.y); whi.z = Math::Max(whi.z, wpos.z);
            if (ghost) sawGhost = true;
            if (ground) sawGround = true;
            if (free) sawFree = true;
        }
    }

    class ItemNameSummary {
        string name;
        uint count;
        vec3 lo;
        vec3 hi;
        ItemNameSummary(const string &in n) {
            name = n; count = 0;
            lo = vec3(1e30, 1e30, 1e30); hi = vec3(-1e30, -1e30, -1e30);
        }
        void Add(vec3 pos) {
            count++;
            lo.x = Math::Min(lo.x, pos.x); lo.y = Math::Min(lo.y, pos.y); lo.z = Math::Min(lo.z, pos.z);
            hi.x = Math::Max(hi.x, pos.x); hi.y = Math::Max(hi.y, pos.y); hi.z = Math::Max(hi.z, pos.z);
        }
    }

    // ---- tools ------------------------------------------------------------------

    // SummarizeMap: whole-map compressed overview. Optional filter to scope it.
    Json::Value@ SummarizeMap(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return MakeError("editor/map not available", "NOT_IN_EDITOR", true, "Editor");

        bool wantBlocks = !input.HasKey("blocks") || bool(input["blocks"]);
        bool wantItems = input.HasKey("items") && bool(input["items"]);
        if (!wantBlocks && !wantItems) return MakeError("blocks and items both false — nothing to summarize", "INVALID_INPUT");

        // optional world-space filter (same convention as the rest of the pack:
        // world meters; x/z horizontal, y up)
        bool hasFilter = input.HasKey("minX") || input.HasKey("maxX") || input.HasKey("minZ") || input.HasKey("maxZ");
        float fMinX = input.HasKey("minX") ? float(input["minX"]) : -1e30;
        float fMaxX = input.HasKey("maxX") ? float(input["maxX"]) : 1e30;
        float fMinZ = input.HasKey("minZ") ? float(input["minZ"]) : -1e30;
        float fMaxZ = input.HasKey("maxZ") ? float(input["maxZ"]) : 1e30;

        // ---- blocks: group by name ----
        dictionary blockByName;   // name -> BlockNameSummary@
        uint nBlocks = 0;
        uint nGhost = 0;
        uint nFree = 0;
        uint nFiltered = 0;
        if (wantBlocks) {
            auto blocks = editor.Challenge.Blocks;
            for (uint i = 0; i < blocks.Length; i++) {
                auto blk = blocks[i];
                if (blk is null || blk.BlockInfo is null) continue;
                nBlocks++;
                nat3 c = blk.Coord;
                bool ghost = blk.IsGhostBlock();
                bool free = false;
                bool coordValid = c.x != 0xFFFFFFFF && c.z != 0xFFFFFFFF;
                vec3 wpos = vec3(float(c.x) * 32.0, (float(c.y) - 8.0) * 8.0, float(c.z) * 32.0);
#if DEPENDENCY_EDITOR
                free = Editor::IsBlockFree(blk);
                if (free) {
                    // free blocks carry no grid coord (0xFFFFFFFF); use live world pos
                    wpos = Editor::GetBlockLocation(blk);
                }
#endif
                if (ghost) nGhost++;
                if (free) nFree++;
                if (hasFilter) {
                    if (wpos.x < fMinX || wpos.x > fMaxX || wpos.z < fMinZ || wpos.z > fMaxZ) { nFiltered++; continue; }
                }
                string name = string(blk.BlockInfo.Name);
                BlockNameSummary@ s;
                if (!blockByName.Exists(name)) {
                    @s = BlockNameSummary(name);
                    blockByName.Set(name, @s);
                } else {
                    @s = cast<BlockNameSummary@>(blockByName[name]);
                }
                // grid coords are meaningless for free/ghost blocks; compute
                // world pos for everything so bboxes are in one space
                s.Add(wpos, ghost, blk.IsGround, free);
            }
        }

        // ---- items: group by name ----
        dictionary itemByName;
        uint nItems = 0;
        if (wantItems) {
            auto items = editor.Challenge.AnchoredObjects;
            for (uint i = 0; i < items.Length; i++) {
                auto it = items[i];
                if (it is null || it.ItemModel is null) continue;
                nItems++;
                vec3 pos = it.AbsolutePositionInMap;
                if (hasFilter) {
                    if (pos.x < fMinX || pos.x > fMaxX || pos.z < fMinZ || pos.z > fMaxZ) { nFiltered++; continue; }
                }
                string name = string(it.ItemModel.Name);
                ItemNameSummary@ s;
                if (!itemByName.Exists(name)) {
                    @s = ItemNameSummary(name);
                    itemByName.Set(name, @s);
                } else {
                    @s = cast<ItemNameSummary@>(itemByName[name]);
                }
                s.Add(pos);
            }
        }

        // ---- assemble (sorted by count desc, capped) ----
        array<BlockNameSummary@> bList;
        array<string>@ keys = blockByName.GetKeys();
        for (uint i = 0; i < keys.Length; i++) {
            BlockNameSummary@ s = cast<BlockNameSummary@>(blockByName[keys[i]]);
            if (s !is null) bList.InsertLast(s);
        }
        // selection sort by count desc (maps have few distinct names)
        for (uint i = 0; i < bList.Length; i++) {
            for (uint j = i + 1; j < bList.Length; j++) {
                if (bList[j].count > bList[i].count) {
                    BlockNameSummary@ tmp = bList[i]; @bList[i] = bList[j]; @bList[j] = tmp;
                }
            }
        }

        uint maxRows = input.HasKey("maxRows") ? uint(Math::Max(1, int(input["maxRows"]))) : 25;
        Json::Value blockRows = Json::Array();
        uint shown = Math::Min(maxRows, bList.Length);
        for (uint i = 0; i < shown; i++) {
            auto s = bList[i];
            Json::Value row = Json::Object();
            row["name"] = s.name;
            row["count"] = int(s.count);
            row["category"] = s.category;
            // flat bbox [minX,minY,minZ,maxX,maxY,maxZ] world meters — compact
            Json::Value bbox = Json::Array();
            bbox.Add(Math::Round(s.wlo.x)); bbox.Add(Math::Round(s.wlo.y)); bbox.Add(Math::Round(s.wlo.z));
            bbox.Add(Math::Round(s.whi.x)); bbox.Add(Math::Round(s.whi.y)); bbox.Add(Math::Round(s.whi.z));
            row["bbox"] = bbox;
            // terrain-like well above ground level (ground top = y 8m)? report as pillars
            if (s.category == "terrain" && s.wlo.y > 8.5) {
                row["note"] = "ground blocks at y=" + tostring(int(s.wlo.y)) + ".." + tostring(int(s.whi.y)) + "m — raised terrain/pillars above ground level (ground top = 8m)";
            } else if (s.whi.y > 40.0) {
                row["note"] = "blocks up to y=" + tostring(int(s.whi.y)) + "m — far above buildable space (stranded recorder-transfer blocks? clean via RemoveBlocksByIndex)";
            } else if (s.sawGhost) {
                row["note"] = "includes ghost blocks";
            } else if (s.sawFree) {
                row["note"] = "includes free (unanchored) blocks";
            }
            Json::Value q = Json::Object();
            q["blocks"] = true;
            q["query"] = s.name;
            row["query"] = q;
            blockRows.Add(row);
        }

        Json::Value itemRows = Json::Array();
        if (wantItems) {
            array<ItemNameSummary@> iList;
            array<string>@ ikeys = itemByName.GetKeys();
            for (uint i = 0; i < ikeys.Length; i++) {
                ItemNameSummary@ s = cast<ItemNameSummary@>(itemByName[ikeys[i]]);
                if (s !is null) iList.InsertLast(s);
            }
            for (uint i = 0; i < iList.Length; i++) {
                for (uint j = i + 1; j < iList.Length; j++) {
                    if (iList[j].count > iList[i].count) {
                        ItemNameSummary@ tmp = iList[i]; @iList[i] = iList[j]; @iList[j] = tmp;
                    }
                }
            }
            uint shownI = Math::Min(maxRows, iList.Length);
            for (uint i = 0; i < shownI; i++) {
                auto s = iList[i];
                Json::Value row = Json::Object();
                row["name"] = s.name;
                row["count"] = int(s.count);
                Json::Value bbox = Json::Array();
                bbox.Add(Math::Round(s.lo.x)); bbox.Add(Math::Round(s.lo.y)); bbox.Add(Math::Round(s.lo.z));
                bbox.Add(Math::Round(s.hi.x)); bbox.Add(Math::Round(s.hi.y)); bbox.Add(Math::Round(s.hi.z));
                row["bbox"] = bbox;
                Json::Value q = Json::Object();
                q["items"] = true;
                q["query"] = s.name;
                row["query"] = q;
                itemRows.Add(row);
            }
            if (iList.Length > shownI) {
                Json::Value row = Json::Object();
                row["note"] = "...and " + tostring(iList.Length - shownI) + " more item types (raise maxRows)";
                itemRows.Add(row);
            }
        }

        if (bList.Length > shown) {
            Json::Value row = Json::Object();
            row["note"] = "...and " + tostring(bList.Length - shown) + " more block types (raise maxRows)";
            blockRows.Add(row);
        }

        Json::Value output = Json::Object();
        output["mapName"] = editor.Challenge.MapInfo.NameForUi;
        output["mapUid"] = editor.Challenge.MapInfo.MapUid;
        Json::Value totals = Json::Object();
        totals["blocks"] = int(nBlocks);
        totals["items"] = int(nItems);
        totals["ghostBlocks"] = int(nGhost);
        totals["freeBlocks"] = int(nFree);
        totals["distinctBlockNames"] = int(bList.Length);
        if (wantItems) totals["distinctItemNames"] = int(itemByName.GetSize());
        output["totals"] = totals;
        if (nFiltered > 0) output["filteredOut"] = int(nFiltered);
        output["blockTypes"] = blockRows;
        if (wantItems) output["itemTypes"] = itemRows;
        output["zoom"] = "Pass any row's `query` object back to ZoomRegion (plus optional tighter min/maxX/Z world-meter bounds) to list the individual objects. For raw paging use GetBlocks/GetItems.";
        output["note"] = "All positions/bboxes are WORLD METERS (x/z horizontal, y up; stadium grid spans roughly +/-768m XZ, ground top y=8). Filter bounds are world meters too.";
        return MakeSuccess(output);
    }

    // ZoomRegion: list individual blocks/items in a world-space box or matching
    // a name query — the drill-down counterpart to SummarizeMap.
    Json::Value@ ZoomRegion(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return MakeError("editor/map not available", "NOT_IN_EDITOR", true, "Editor");
        bool wantBlocks = !input.HasKey("blocks") || bool(input["blocks"]);
        bool wantItems = input.HasKey("items") && bool(input["items"]);
        string query = input.HasKey("query") ? string(input["query"]) : "";
        string qLower = query.ToLower();
        float fMinX = input.HasKey("minX") ? float(input["minX"]) : -1e30;
        float fMaxX = input.HasKey("maxX") ? float(input["maxX"]) : 1e30;
        float fMinZ = input.HasKey("minZ") ? float(input["minZ"]) : -1e30;
        float fMaxZ = input.HasKey("maxZ") ? float(input["maxZ"]) : 1e30;
        uint limit = input.HasKey("limit") ? uint(Math::Max(1, int(input["limit"]))) : 200;

        Json::Value blocksOut = Json::Array();
        uint bMatched = 0;
        if (wantBlocks) {
            auto blocks = editor.Challenge.Blocks;
            for (uint i = 0; i < blocks.Length && bMatched < limit; i++) {
                auto blk = blocks[i];
                if (blk is null || blk.BlockInfo is null) continue;
                string name = string(blk.BlockInfo.Name);
                if (qLower.Length > 0) {
                    string nl = name.ToLower();
                    if (!nl.Contains(qLower)) continue;
                }
                nat3 c = blk.Coord;
                float wx;
                float wz;
                bool coordValid = c.x != 0xFFFFFFFF && c.z != 0xFFFFFFFF;
                bool free = false;
#if DEPENDENCY_EDITOR
                free = Editor::IsBlockFree(blk);
#endif
                if (free) {
#if DEPENDENCY_EDITOR
                    vec3 wpos = Editor::GetBlockLocation(blk);
                    wx = wpos.x; wz = wpos.z;
#endif
                } else if (coordValid) {
                    wx = float(c.x) * 32.0;
                    wz = float(c.z) * 32.0;
                } else {
                    continue; // ghost/no-coord and not free: unresolvable position
                }
                if (wx < fMinX || wx > fMaxX || wz < fMinZ || wz > fMaxZ) continue;
                bMatched++;
                Json::Value row = Json::Object();
                row["index"] = int(i);
                row["name"] = name;
                row["coord"] = CoordToJson(c);
                row["worldXZ"] = Vec2ToJson(vec2(wx, wz));
                row["dir"] = int(blk.BlockDir);
                row["isFree"] = free;
                blocksOut.Add(row);
            }
        }

        Json::Value itemsOut = Json::Array();
        uint iMatched = 0;
        if (wantItems) {
            auto items = editor.Challenge.AnchoredObjects;
            for (uint i = 0; i < items.Length && iMatched < limit; i++) {
                auto it = items[i];
                if (it is null || it.ItemModel is null) continue;
                string name = string(it.ItemModel.Name);
                if (qLower.Length > 0) {
                    string nl = name.ToLower();
                    if (!nl.Contains(qLower)) continue;
                }
                vec3 pos = it.AbsolutePositionInMap;
                if (pos.x < fMinX || pos.x > fMaxX || pos.z < fMinZ || pos.z > fMaxZ) continue;
                iMatched++;
                Json::Value row = Json::Object();
                row["index"] = int(i);
                row["name"] = name;
                row["pos"] = Vec3ToJson(pos);
                itemsOut.Add(row);
            }
        }

        Json::Value output = Json::Object();
        output["blocksMatched"] = int(bMatched);
        output["itemsMatched"] = int(iMatched);
        output["limit"] = int(limit);
        output["blocks"] = blocksOut;
        output["items"] = itemsOut;
        if (bMatched >= limit || iMatched >= limit) output["note"] = "hit limit; tighten the region or raise limit";
        return MakeSuccess(output);
    }
}
