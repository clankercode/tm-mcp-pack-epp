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

    Json::Value@ MakeSuccess(Json::Value &in output) {
        Json::Value r = Json::Object();
        r["success"] = true;
        r["output"] = output;
        return r;
    }

    Json::Value@ MakeError(const string &in err) {
        return MakeError(err, "", false, "", "");
    }

    Json::Value@ MakeError(
        const string &in err,
        const string &in code,
        bool retryable = false,
        const string &in requiredMode = "",
        const string &in hint = ""
    ) {
        Json::Value r = Json::Object();
        r["success"] = false;
        r["error"] = err;
        if (code.Length > 0) r["code"] = code;
        if (retryable) r["retryable"] = true;
        if (requiredMode.Length > 0) r["requiredMode"] = requiredMode;
        if (hint.Length > 0) r["hint"] = hint;
        return r;
    }

    Json::Value@ EditorPlusPlusMissingError() {
        return MakeError("Editor++ is not available.", "missing_dependency");
    }

    Json::Value@ NeedEditor() {
        return Err("editor not available", "NOT_IN_EDITOR");
    }

    CGameCtnEditorFree@ GetEditor() {
        auto app = cast<CTrackMania>(GetApp());
        if (app is null || app.Editor is null) return null;
        return cast<CGameCtnEditorFree>(app.Editor);
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
}
