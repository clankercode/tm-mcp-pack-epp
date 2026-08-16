namespace TmMcpPackEpp {
    Json::Value Int3ToJson(const int3 &in coord) {
        Json::Value arr = Json::Array();
        arr.Add(coord.x);
        arr.Add(coord.y);
        arr.Add(coord.z);
        return arr;
    }


    Json::Value Vec3DegToJson(const vec3 &in anglesRad) {
        return Vec3ToJson(vec3(
            Math::ToDeg(anglesRad.x),
            Math::ToDeg(anglesRad.y),
            Math::ToDeg(anglesRad.z)
        ));
    }

    vec3 RotationInput(Json::Value &in input) {
        return vec3(
            AngleInputRad(input, "pitch", "pitchRad", 0.0),
            AngleInputRad(input, "yaw", "yawRad", 0.0),
            AngleInputRad(input, "roll", "rollRad", 0.0)
        );
    }

    CGameEditorPluginMap::ECardinalDirections DirFromString(const string &in dir) {
        if (dir == "East") return CGameEditorPluginMap::ECardinalDirections::East;
        if (dir == "South") return CGameEditorPluginMap::ECardinalDirections::South;
        if (dir == "West") return CGameEditorPluginMap::ECardinalDirections::West;
        return CGameEditorPluginMap::ECardinalDirections::North;
    }

    bool ModelNameMatches(CGameCtnBlockInfo@ blockInfo, const string &in lowerName) {
        if (blockInfo is null) return false;
        if (string(blockInfo.Name).ToLower() == lowerName) return true;
        if (string(blockInfo.IdName).ToLower() == lowerName) return true;
        return false;
    }

    Json::Value MapSummary(CGameCtnEditorFree@ editor) {
        Json::Value output = Json::Object();
        if (editor is null || editor.Challenge is null) return output;
        auto map = editor.Challenge;
        output["name"] = map.MapName;
        output["size"] = CoordToJson(map.Size);
        output["bounds"] = MapBoundsToJson(map.Size);
        output["nbBlocks"] = int(map.Blocks.Length);
        output["nbBakedBlocks"] = int(map.BakedBlocks.Length);
        output["nbItems"] = int(map.AnchoredObjects.Length);
        if (editor.PluginMapType !is null) {
            output["nbScriptItems"] = int(editor.PluginMapType.Items.Length);
        }
        output["vertexCount"] = int(map.VertexCount);
        if (map.MapInfo !is null) {
            output["fileName"] = map.MapInfo.FileName;
        }
        auto fid = GetFidFromNod(map);
        if (fid !is null) {
            output["fullFileName"] = fid.FullFileName;
        }
        return output;
    }


    Json::Value CoordToJson(const nat3 &in coord) {
        Json::Value arr = Json::Array();
        arr.Add(coord.x);
        arr.Add(coord.y);
        arr.Add(coord.z);
        return arr;
    }

    string PackDescPath(CSystemPackDesc@ packDesc) {
        if (packDesc is null) return "";
        return packDesc.Url.Length > 0 ? packDesc.Url : string(packDesc.Name);
    }

    vec3 OptionalOffsetInput(Json::Value &in input) {
        return vec3(
            input.HasKey("offsetX") ? float(input["offsetX"]) : 0.0,
            input.HasKey("offsetY") ? float(input["offsetY"]) : 0.0,
            input.HasKey("offsetZ") ? float(input["offsetZ"]) : 0.0
        );
    }

    vec3 PivotInput(Json::Value &in input) {
        return vec3(
            input.HasKey("pivotX") ? float(input["pivotX"]) : 0.0,
            input.HasKey("pivotY") ? float(input["pivotY"]) : 0.0,
            input.HasKey("pivotZ") ? float(input["pivotZ"]) : 0.0
        );
    }

    bool HasTransformInput(Json::Value &in input) {
        return input.HasKey("offsetX") || input.HasKey("offsetY") || input.HasKey("offsetZ")
            || input.HasKey("x") || input.HasKey("y") || input.HasKey("z")
            || input.HasKey("pitch") || input.HasKey("yaw") || input.HasKey("roll")
            || input.HasKey("pitchRad") || input.HasKey("yawRad") || input.HasKey("rollRad");
    }

    Json::Value MacroblockModelToJson(CGameCtnMacroBlockInfo@ macroblockInfo) {
        Json::Value obj = Json::Object();
        obj["type"] = "macroblock";
        obj["name"] = macroblockInfo.Name;
        obj["idName"] = macroblockInfo.IdName;
        return obj;
    }

    bool TextMatchesQuery(const string &in text, const string &in lowerQuery) {
        return lowerQuery.Length == 0 || text.ToLower().Contains(lowerQuery);
    }

    bool InventoryTypeEnabled(const string &in requested, const string &in ty) {
        if (requested.Length == 0 || requested == "all") return true;
        if (requested == ty) return true;
        if (requested == "blocks" && ty == "block") return true;
        if (requested == "items" && ty == "item") return true;
        if (requested == "macroblocks" && ty == "macroblock") return true;
        return false;
    }

    Json::Value InventorySummary(CGameEditorPluginMap@ pmt) {
        Json::Value output = Json::Object();
        if (pmt is null) return output;
        output["source"] = "pluginMap";
        output["nbBlocks"] = int(pmt.BlockModels.Length);
        output["nbTerrainBlocks"] = int(pmt.TerrainBlockModels.Length);
        output["nbItems"] =
#if DEPENDENCY_EDITOR
            int(Editor::GetInventoryNbItems());
#else
            0;
#endif
        output["nbMacroblocks"] = int(pmt.MacroblockModels.Length);
        output["isScanningBlocks"] = false;
        output["isScanningItems"] =
#if DEPENDENCY_EDITOR
            Editor::IsInventoryScanningItems();
#else
            false;
#endif
        output["isScanningMacroblocks"] = false;
        output["loadingStatus"] = "loaded from CGameEditorPluginMap";
        output["loadingStatusShort"] = "ready";
        output["note"] = "Blocks/macroblocks come from CGameEditorPluginMap; items come from E++ inventory wrapper exports.";
        return output;
    }


    vec3 PositionInput(Json::Value &in input) {
        return vec3(float(input["x"]), float(input["y"]), float(input["z"]));
    }

    Json::Value CameraToJson(CGameCtnEditorFree@ editor) {
        Json::Value output = Json::Object();
        auto pmt = editor.PluginMapType;
        auto orbital = editor.OrbitalCameraControl;
        output["target"] = Vec3ToJson(pmt.CameraTargetPosition);
        output["distance"] = pmt.CameraToTargetDistance;
        output["hAngle"] = pmt.CameraHAngle;
        output["vAngle"] = pmt.CameraVAngle;
        output["angles"] = Vec2ToJson(vec2(pmt.CameraHAngle, pmt.CameraVAngle));
        output["anglesDeg"] = Vec2DegToJson(vec2(pmt.CameraHAngle, pmt.CameraVAngle));
        if (orbital !is null) {
            output["position"] = Vec3ToJson(orbital.Pos);
            output["orbitalTarget"] = Vec3ToJson(orbital.m_TargetedPosition);
            output["orbitalDistance"] = orbital.m_CameraToTargetDistance;
        }
        return output;
    }

    Json::Value BlockToJson(CGameCtnBlock@ block) {
        if (block is null) return Json::Value();
        Json::Value obj = Json::Object();
        obj["coord"] = CoordToJson(block.Coord);
        obj["dir"] = int(block.BlockDir);
        if (block.BlockInfo is null) {
            obj["name"] = "";
            obj["idName"] = "";
        } else {
            obj["name"] = block.BlockInfo.Name;
            obj["idName"] = block.BlockInfo.IdName;
        }
#if DEPENDENCY_EDITOR
        bool isFree = Editor::IsBlockFree(block);
        obj["isFree"] = isFree;
        obj["variant"] = int(block.BlockInfoVariantIndex);
        obj["mobilIndex"] = int(block.MobilIndex);
        obj["mobilVariant"] = int(block.MobilVariantIndex);
        obj["isGround"] = block.IsGround;
        obj["isGhost"] = block.IsGhostBlock();
        obj["pos"] = Vec3ToJson(Editor::GetBlockLocation(block));
        auto rot = Editor::GetBlockRotation(block);
        obj["rot"] = Vec3ToJson(rot);
        obj["rotDeg"] = Vec3DegToJson(rot);
#else
        obj["isFree"] = false;
        obj["variant"] = int(block.BlockInfoVariantIndex);
        obj["mobilIndex"] = int(block.MobilIndex);
        obj["mobilVariant"] = int(block.MobilVariantIndex);
        obj["isGround"] = block.IsGround;
        obj["isGhost"] = block.IsGhostBlock();
#endif
#if DEPENDENCY_EDITOR
        obj["skin"] = BlockSkinToJson(block);
#endif
        return obj;
    }

    Json::Value ItemToJson(CGameCtnAnchoredObject@ item) {
        if (item is null) return Json::Value();
        Json::Value obj = Json::Object();
        obj["coord"] = CoordToJson(item.BlockUnitCoord);
        obj["pos"] = Vec3ToJson(item.AbsolutePositionInMap);
        auto rot = vec3(item.Pitch, item.Yaw, item.Roll);
        obj["rot"] = Vec3ToJson(rot);
        obj["rotDeg"] = Vec3DegToJson(rot);
        obj["isFlying"] = item.IsFlying;
        obj["scale"] = item.Scale;
        obj["variant"] = int(item.IVariant);
        if (item.ItemModel is null) {
            obj["name"] = "";
            obj["idName"] = "";
            obj["waypointType"] = -1;
        } else {
            obj["name"] = item.ItemModel.Name;
            obj["idName"] = item.ItemModel.IdName;
            obj["waypointType"] = int(item.ItemModel.WaypointType);
        }
#if DEPENDENCY_EDITOR
        obj["skin"] = ItemSkinToJson(item);
#endif
        return obj;
    }

    bool ModelMatchesQuery(CGameCtnBlockInfo@ blockInfo, const string &in lowerQuery) {
        if (blockInfo is null) return false;
        if (lowerQuery.Length == 0) return true;
        if (string(blockInfo.Name).ToLower().Contains(lowerQuery)) return true;
        if (string(blockInfo.IdName).ToLower().Contains(lowerQuery)) return true;
        return false;
    }

    Json::Value ModelToJson(CGameCtnBlockInfo@ blockInfo, bool isTerrain) {
        Json::Value obj = Json::Object();
        obj["name"] = blockInfo.Name;
        obj["idName"] = blockInfo.IdName;
        obj["isTerrain"] = isTerrain;
        obj["groundVariants"] = int(blockInfo.AdditionalVariantsGround.Length) + 1;
        obj["airVariants"] = int(blockInfo.AdditionalVariantsAir.Length) + 1;
        obj["variantBaseGroundSize"] = CoordToJson(blockInfo.VariantBaseGround.Size);
        obj["variantBaseAirSize"] = CoordToJson(blockInfo.VariantBaseAir.Size);
        return obj;
    }


    bool ReadIndexArgs(Json::Value &in input, int total, int maxCount, array<int> &out indices, string &out err) {
        if (input.HasKey("index")) {
            int ix = int(input["index"]);
            if (ix < 0 || ix >= total) {
                err = "index out of range: " + ix + " / " + total;
                return false;
            }
            indices.InsertLast(ix);
        }
        if (input.HasKey("indices")) {
            auto raw = input["indices"];
            if (raw.GetType() != Json::Type::Array) {
                err = "indices must be an array";
                return false;
            }
            for (uint i = 0; i < raw.Length; i++) {
                int ix = int(raw[i]);
                if (ix < 0 || ix >= total) {
                    err = "index out of range: " + ix + " / " + total;
                    return false;
                }
                if (indices.Find(ix) == -1) indices.InsertLast(ix);
                if (indices.Length > uint(maxCount)) {
                    err = "too many indices; max is " + maxCount;
                    return false;
                }
            }
        }
        if (indices.Length == 0) {
            err = "missing index or indices";
            return false;
        }
        return true;
    }

    bool FocusCameraOn(vec3 pos, float distance) {
        auto editor = GetEditor();
        auto orbital = editor is null ? null : editor.OrbitalCameraControl;
        vec3 camPos = orbital is null ? pos + vec3(0, 0, -1) : orbital.Pos;
        vec3 dir = pos - camPos;
        if (dir.LengthSquared() < 1.0e-6) dir = vec3(0, 0, 1);
        return Editor::SetCamAnimationGoTo(LookDirToOrbitalAngles(dir), pos, distance);
    }


    Json::Value ItemModelToJson(CGameItemModel@ itemModel, const string &in path = "") {
        Json::Value obj = Json::Object();
        obj["type"] = "item";
        if (itemModel is null) {
            obj["name"] = "";
            obj["idName"] = "";
            obj["path"] = path;
            obj["waypointType"] = -1;
        } else {
            obj["name"] = itemModel.Name;
            obj["idName"] = itemModel.IdName;
            obj["path"] = path.Length > 0 ? path : itemModel.IdName;
            obj["waypointType"] = int(itemModel.WaypointType);
        }
        return obj;
    }

    bool AutofocusCameraOn(vec3 pos, float distance) {
        auto editor = GetEditor();
        auto orbital = editor is null ? null : editor.OrbitalCameraControl;
        if (orbital is null) return FocusCameraOn(pos, distance);
        vec3 horiz = (orbital.Pos - pos) * vec3(1, 0, 1);
        if (horiz.LengthSquared() < 1.0e-6) horiz = vec3(0, 0, -1);
        horiz = horiz.Normalized();
        float pitchDown = Math::ToRad(65.0);
        vec3 lookDir = horiz * -Math::Cos(pitchDown) + vec3(0, -Math::Sin(pitchDown), 0);
        return Editor::SetCamAnimationGoTo(LookDirToOrbitalAngles(lookDir), pos, distance);
    }




    Json::Value MapBoundsToJson(const nat3 &in size) {
        Json::Value output = Json::Object();
        Json::Value coord = Json::Object();
        coord["min"] = CoordToJson(nat3(0, 0, 0));
        coord["maxInclusive"] = CoordToJson(size - nat3(1, 1, 1));
        coord["maxExclusive"] = CoordToJson(size);
        output["coord"] = coord;

        Json::Value meters = Json::Object();
        meters["min"] = Vec3ToJson(vec3(0, -64, 0));
        meters["maxInclusiveCoordOrigin"] = Vec3ToJson(vec3(
            float(size.x - 1) * 32.0,
            (float(size.y - 1) - 8.0) * 8.0,
            float(size.z - 1) * 32.0
        ));
        meters["maxExclusive"] = Vec3ToJson(vec3(
            float(size.x) * 32.0,
            (float(size.y) - 8.0) * 8.0,
            float(size.z) * 32.0
        ));
        meters["blockUnitSize"] = Vec3ToJson(vec3(32, 8, 32));
        meters["baseHeightOffset"] = 64.0;
        output["meters"] = meters;
        return output;
    }

    Json::Value Vec2ToJson(const vec2 &in value) {
        Json::Value arr = Json::Array();
        arr.Add(value.x);
        arr.Add(value.y);
        return arr;
    }

    Json::Value Vec2DegToJson(const vec2 &in anglesRad) {
        return Vec2ToJson(vec2(Math::ToDeg(anglesRad.x), Math::ToDeg(anglesRad.y)));
    }

    float AngleInputRad(Json::Value &in input, const string &in degKey, const string &in radKey, float defaultDeg) {
        if (input.HasKey(radKey)) return float(input[radKey]);
        return Math::ToRad(InputFloatOr(input, degKey, defaultDeg));
    }

    vec2 LookDirToOrbitalAngles(vec3 dir) {
        if (dir.LengthSquared() < 1.0e-12) return vec2(0, 0);
        vec3 n = dir.Normalized();
        float h = Math::Atan2(n.x, n.z);
        float v = -Math::Asin(Math::Clamp(n.y, -1.0, 1.0));
        return vec2(h, v);
    }


    float InputFloatOr(Json::Value &in input, const string &in key, float defaultValue) {
        return input.HasKey(key) ? float(input[key]) : defaultValue;
    }
}
