namespace TmMcpPackEpp {
    Json::Value@ Ok(Json::Value@ output) {
        Json::Value r = Json::Object();
        r["success"] = true;
        r["output"] = output;
        return r;
    }

    Json::Value@ Err(const string &in msg, const string &in code = "") {
        Json::Value r = Json::Object();
        r["success"] = false;
        r["error"] = msg;
        if (code.Length > 0) r["code"] = code;
        return r;
    }

    Json::Value Vec3ToJson(const vec3 &in v) {
        Json::Value o = Json::Object();
        o["x"] = v.x;
        o["y"] = v.y;
        o["z"] = v.z;
        return o;
    }

    vec3 JsonToVec3(Json::Value@ input, const string &in prefix = "") {
        string px = prefix.Length == 0 ? "x" : prefix + "X";
        string py = prefix.Length == 0 ? "y" : prefix + "Y";
        string pz = prefix.Length == 0 ? "z" : prefix + "Z";
        float x = input.HasKey(px) ? float(input[px]) : 0.0;
        float y = input.HasKey(py) ? float(input[py]) : 0.0;
        float z = input.HasKey(pz) ? float(input[pz]) : 0.0;
        return vec3(x, y, z);
    }

    Json::Value MapSummary(CGameCtnEditorFree@ editor) {
        Json::Value o = Json::Object();
        if (editor is null || editor.Challenge is null) {
            o["available"] = false;
            return o;
        }
        o["available"] = true;
        o["mapName"] = string(editor.Challenge.MapName);
        o["nbBlocks"] = int(editor.Challenge.Blocks.Length);
        o["nbItems"] = int(editor.Challenge.AnchoredObjects.Length);
        return o;
    }

    CGameCtnEditorFree@ GetEditor() {
        return cast<CGameCtnEditorFree>(GetApp().Editor);
    }

    Json::Value@ NeedEditor() {
        return Err("editor not available", "NOT_IN_EDITOR");
    }

    bool ModelNameMatches(CMwNod@ nod, const string &in lowerName) {
        if (nod is null) return false;
        auto id = cast<CMwNod>(nod);
        string n = string(nod.IdName).ToLower();
        if (n == lowerName) return true;
        return n.IndexOf(lowerName) >= 0;
    }

    CGameCtnBlockInfo@ ResolveBlockModel(CGameEditorPluginMap@ pmt, const string &in blockName, bool &out isTerrain) {
        isTerrain = false;
        if (pmt is null) return null;
        CGameCtnBlockInfo@ info = pmt.GetBlockModelFromName(blockName);
        if (info !is null) return info;
        string lowerName = blockName.ToLower();
        for (uint i = 0; i < pmt.BlockModels.Length; i++) {
            @info = pmt.BlockModels[i];
            if (info !is null && string(info.IdName).ToLower() == lowerName) return info;
        }
        isTerrain = true;
        @info = pmt.GetTerrainBlockModelFromName(blockName);
        if (info !is null) return info;
        isTerrain = false;
        return null;
    }
}
