// CheckCheckpoints: agent-friendly checkpoint audit — vehicle spawn position
// and "would the car fall?" support analysis for every checkpoint/finish/start
// in the map. Static analysis (no simulation): we take the checkpoint's
// drivable surface (block top / item anchor) and scan the column below it for
// solid ground within a fall tolerance.
//
// Detection (mirrors E++ Checkpoints component):
//   blocks: WaypointSpecialProperty !is null (WayPointType filter)
//   items:  WaypointSpecialProperty !is null (IsCheckpoint / WaypointType)
// Positions are world meters (same frame as SummarizeMap; ground top = 8m).

namespace TmMcpPackEpp {

    const float EngineGroundTopY = 8.0;

    string WpTypeToStr(int t) {
        if (t == 0) return "Start";
        if (t == 1) return "Finish";
        if (t == 2) return "Checkpoint";
        if (t == 3) return "StartFinish";
        if (t == 4) return "Multilap";
        return "Other" + t;
    }

    // Scan the column below (x,z) for the top of the highest solid support
    // (block or item) strictly below yMax. out: supY, supKind, supIndex.
    // Defaults to engine ground when nothing found.
    void FindSupportBelow(CGameCtnChallenge@ map, float x, float z, float yMax,
                          float &out supY, string &out supKind, uint &out supIndex) {
        supY = EngineGroundTopY;
        supKind = "ground";
        supIndex = 0;
        float best = -1e30;
        for (uint i = 0; i < map.Blocks.Length; i++) {
            auto blk = map.Blocks[i];
            if (blk is null) continue;
            if (blk.IsGhostBlock()) continue;
            nat3 c = blk.Coord;
            bool coordValid = c.x != 0xFFFFFFFF && c.z != 0xFFFFFFFF;
#if DEPENDENCY_EDITOR
            bool freeBlk = Editor::IsBlockFree(blk);
#else
            bool freeBlk = false;
#endif
            if (!coordValid && !freeBlk) continue; // unresolvable
            float bx, bz, bTop;
            if (freeBlk) {
                // free blocks have no grid coord — resolve live world pos (E++)
#if DEPENDENCY_EDITOR
                vec3 w = Editor::GetBlockLocation(blk);
                bx = Math::Floor(w.x / 32.0) * 32.0;
                bz = Math::Floor(w.z / 32.0) * 32.0;
                bTop = w.y + 8.0; // nominal 1-cell height
#else
                continue;
#endif
            } else {
                bx = float(c.x) * 32.0;
                bz = float(c.z) * 32.0;
                bTop = (float(c.y) - 8.0) * 8.0 + 8.0;
            }
            // 32m cell footprint: support must lie under x,z
            if (x < bx || x >= bx + 32.0) continue;
            if (z < bz || z >= bz + 32.0) continue;
            if (bTop > yMax) continue;
            if (bTop > best) {
                best = bTop;
                supY = bTop;
                supKind = "block:" + blk.BlockInfo.Name;
                supIndex = i;
            }
        }
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            auto it = map.AnchoredObjects[i];
            if (it is null || it.ItemModel is null) continue;
            vec3 p = it.AbsolutePositionInMap;
            // rough item footprint: 8m radius around the anchor
            if (Math::Abs(p.x - x) > 8.0 || Math::Abs(p.z - z) > 8.0) continue;
            if (p.y > yMax) continue;
            if (p.y > best) {
                best = p.y;
                supY = p.y;
                supKind = "item:" + it.ItemModel.Name;
                supIndex = i;
            }
        }
    }

    // Like FindSupportBelow but skips one anchored object (the CP itself) so
    // item checkpoints don't count their own anchor as support.
    void FindSupportBelowExclItem(CGameCtnChallenge@ map, float x, float z, float yMax, uint skipItem,
                                  float &out supY, string &out supKind, uint &out supIndex) {
        FindSupportBelow(map, x, z, yMax, supY, supKind, supIndex);
        if (supKind.StartsWith("item:") && supIndex == skipItem) {
            // rerun without items entirely — rare path, map scan is cheap
            supY = EngineGroundTopY;
            supKind = "ground";
            supIndex = 0;
            float best = -1e30;
            for (uint i = 0; i < map.Blocks.Length; i++) {
                auto blk = map.Blocks[i];
                if (blk is null) continue;
                if (blk.IsGhostBlock()) continue;
                nat3 c = blk.Coord;
                bool coordValid = c.x != 0xFFFFFFFF && c.z != 0xFFFFFFFF;
#if DEPENDENCY_EDITOR
                bool freeBlk = Editor::IsBlockFree(blk);
#else
                bool freeBlk = false;
#endif
                if (!coordValid && !freeBlk) continue;
                float bx, bz, bTop;
                if (freeBlk) {
#if DEPENDENCY_EDITOR
                    vec3 w = Editor::GetBlockLocation(blk);
                    bx = Math::Floor(w.x / 32.0) * 32.0;
                    bz = Math::Floor(w.z / 32.0) * 32.0;
                    bTop = w.y + 8.0;
#else
                    continue;
#endif
                } else {
                    bx = float(c.x) * 32.0;
                    bz = float(c.z) * 32.0;
                    bTop = (float(c.y) - 8.0) * 8.0 + 8.0;
                }
                if (x < bx || x >= bx + 32.0) continue;
                if (z < bz || z >= bz + 32.0) continue;
                if (bTop > yMax) continue;
                if (bTop > best) {
                    best = bTop;
                    supY = bTop;
                    supKind = "block:" + blk.BlockInfo.Name;
                    supIndex = i;
                }
            }
        }
    }

    Json::Value@ CheckCheckpoints(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.Challenge is null) return MakeError("editor/map not available", "NOT_IN_EDITOR", true, "Editor");
        auto map = editor.Challenge;

        float fallTolerance = input.HasKey("fallTolerance") ? float(input["fallTolerance"]) : 8.0;

        Json::Value cps = Json::Array();
        uint nBlockCps = 0, nItemCps = 0;

        // ---- waypoint blocks ----
        for (uint i = 0; i < map.Blocks.Length; i++) {
            auto blk = map.Blocks[i];
            if (blk is null || blk.WaypointSpecialProperty is null) continue;
            auto bi = blk.BlockInfo;
            if (bi is null) continue;
            int wt = int(bi.WayPointType);
            if (wt < 0 || wt > 4) continue;
            nBlockCps++;
            vec3 loc;
#if DEPENDENCY_EDITOR
            loc = Editor::GetBlockLocation(blk);
#else
            nat3 c = blk.Coord;
            loc = vec3(float(c.x) * 32.0, (float(c.y) - 8.0) * 8.0, float(c.z) * 32.0);
#endif
            // vehicle spawns on the drivable surface: top of the block cell
            vec3 spawn = loc + vec3(0, 8.0, 0);
            float supY; string supKind; uint supIx;
            // sample a car-width set of points under the gate — a single point
            // can straddle a block boundary and miss the road (roads are 32m
            // cells; CPs often sit exactly on cell edges)
            float bestDrop = 1e30;
            float tsupY = 0; string tsupKind = ""; uint tsupIx = 0;
            float offsetsX = Math::Abs(spawn.x % 32.0) < 4.0 ? -6.0 : 6.0;
            float offsetsZ = Math::Abs(spawn.z % 32.0) < 4.0 ? -6.0 : 6.0;
            FindSupportBelow(map, spawn.x, spawn.z, spawn.y, tsupY, tsupKind, tsupIx);
            bestDrop = spawn.y - tsupY; supY = tsupY; supKind = tsupKind; supIx = tsupIx;
            FindSupportBelow(map, spawn.x + offsetsX, spawn.z + offsetsZ, spawn.y, tsupY, tsupKind, tsupIx);
            if (spawn.y - tsupY < bestDrop) {
                bestDrop = spawn.y - tsupY; supY = tsupY; supKind = tsupKind; supIx = tsupIx;
            }
            float drop = spawn.y - supY;
            Json::Value row = Json::Object();
            row["kind"] = "block";
            row["wpType"] = WpTypeToStr(wt);
            row["name"] = bi.Name;
            row["index"] = int(i);
            row["pos"] = Vec3ToJson(loc);
            row["spawnPos"] = Vec3ToJson(vec3(Math::Round(spawn.x), Math::Round(spawn.y), Math::Round(spawn.z)));
            row["linkOrder"] = int(blk.WaypointSpecialProperty.Order);
            row["tag"] = blk.WaypointSpecialProperty.Tag;
            row["grounded"] = drop <= fallTolerance;
            row["dropDist"] = Math::Round(drop);
            row["supportKind"] = supKind;
            row["supportIndex"] = int(supIx);
            cps.Add(row);
        }

        // ---- waypoint items ----
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            auto it = map.AnchoredObjects[i];
            if (it is null || it.WaypointSpecialProperty is null) continue;
            auto im = it.ItemModel;
            if (im is null) continue;
            int wt = int(im.WaypointType);
            nItemCps++;
            vec3 loc = it.AbsolutePositionInMap;
            vec3 spawn = loc;
            // sample a car-width set of points (gates often sit on cell edges)
            float supY; string supKind; uint supIx;
            float offsetsX = Math::Abs(spawn.x % 32.0) < 4.0 ? -6.0 : 6.0;
            float offsetsZ = Math::Abs(spawn.z % 32.0) < 4.0 ? -6.0 : 6.0;
            FindSupportBelowExclItem(map, spawn.x, spawn.z, spawn.y, i, supY, supKind, supIx);
            float bestDrop = spawn.y - supY;
            float tsupY = 0; string tsupKind = ""; uint tsupIx = 0;
            FindSupportBelowExclItem(map, spawn.x + offsetsX, spawn.z + offsetsZ, spawn.y, i, tsupY, tsupKind, tsupIx);
            if (spawn.y - tsupY < bestDrop) {
                bestDrop = spawn.y - tsupY; supY = tsupY; supKind = tsupKind; supIx = tsupIx;
            }
            float drop = spawn.y - supY;
            Json::Value row = Json::Object();
            row["kind"] = "item";
            row["wpType"] = WpTypeToStr(wt);
            row["name"] = im.Name;
            row["index"] = int(i);
            row["pos"] = Vec3ToJson(loc);
            row["spawnPos"] = Vec3ToJson(vec3(Math::Round(spawn.x), Math::Round(spawn.y), Math::Round(spawn.z)));
            row["linkOrder"] = int(it.WaypointSpecialProperty.Order);
            row["tag"] = it.WaypointSpecialProperty.Tag;
            row["grounded"] = drop <= fallTolerance;
            row["dropDist"] = Math::Round(drop);
            row["supportKind"] = supKind;
            row["supportIndex"] = int(supIx);
            cps.Add(row);
        }

        Json::Value output = Json::Object();
        output["total"] = int(cps.Length);
        output["blockCheckpoints"] = int(nBlockCps);
        output["itemCheckpoints"] = int(nItemCps);
        output["checkpoints"] = cps;
        uint nFloating = 0;
        for (uint i = 0; i < cps.Length; i++) {
            if (!bool(cps[i]["grounded"])) nFloating++;
        }
        output["floating"] = int(nFloating);
        output["note"] = "spawnPos = vehicle spawn estimate (block CP: top of its own cell — the car stands ON the checkpoint block; item CP: gate anchor). grounded = solid support within fallTolerance below spawn. Elevated roads are NORMAL in Trackmania: a road CP high above ground is fine when the road passes through the gate (drop small); drop=large with support=ground far below means NOTHING under the gate — car would fall. Check floating gates with ZoomRegion around spawnPos. Positions are world meters.";
        return MakeSuccess(output);
    }
}
