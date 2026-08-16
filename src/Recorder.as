namespace TmMcpPackEpp {
#if DEPENDENCY_EDITOR
    // E++ Macroblock Recorder control (issue #39 exports).
    // The export file (Components/Macroblocks/MacroblockRecorder_Export.as) is
    // compiled into this plugin via the Editor dependency's exports list, so
    // global MacroblockRecorder::* is already bound — do NOT redeclare it here
    // (a nested redeclaration resolves to a different qualified name and fails
    // with "Unbound function called").
    // StopRecording(false) moves the recording to the editor's copy-paste
    // macroblock via a background coroutine (cursor control + several frames);
    // poll HasExisting / CompletedRec_* for completion.

    Json::Value RecorderStatusJson() {
        Json::Value s = Json::Object();
        s["isActive"] = MacroblockRecorder::IsActive;
        s["hasExisting"] = MacroblockRecorder::HasExisting;
        s["activeIsEmpty"] = MacroblockRecorder::ActiveRecordingIsEmpty;
        s["activeBlocks"] = int(MacroblockRecorder::ActiveRec_NbBlocks);
        s["activeItems"] = int(MacroblockRecorder::ActiveRec_NbItems);
        s["completedBlocks"] = int(MacroblockRecorder::CompletedRec_NbBlocks);
        s["completedItems"] = int(MacroblockRecorder::CompletedRec_NbItems);
        s["note"] = "stop (cancel=false) keeps the recording as the completed MB (async transfer to copy-paste); poll status until hasExisting && !isActive.";
        return s;
    }

    Json::Value@ ControlMacroblockRecorder(Json::Value &in input) {
        string action = input.HasKey("action") ? string(input["action"]) : "status";
        Json::Value output = Json::Object();
        if (action == "start") {
            MacroblockRecorder::StartRecording();
        } else if (action == "stop") {
            bool cancel = input.HasKey("cancel") ? bool(input["cancel"]) : false;
            MacroblockRecorder::StopRecording(cancel);
        } else if (action == "resume") {
            MacroblockRecorder::ResumeRecording();
        } else if (action != "status") {
            return MakeError("unknown action: " + action + " (start|stop|resume|status)", "INVALID_INPUT");
        }
        output["action"] = action;
        output["status"] = RecorderStatusJson();
        return MakeSuccess(output);
    }

    // Snapshot the recording as a spec (active if recording, else completed via resume).
    Json::Value@ GetRecordedMacroblockSpec(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        auto spec = MacroblockRecorder::GetRecordingMB();
        bool fromActive = spec !is null;
        if (spec is null && MacroblockRecorder::HasExisting) {
            // completed recording is not exposed as a spec; resume into active to
            // read it (the stop transfer may take a few frames to settle)
            for (uint i = 0; i < 20 && spec is null; i++) {
                MacroblockRecorder::ResumeRecording();
                yield();
                @spec = MacroblockRecorder::GetRecordingMB();
            }
        }
        if (spec is null) return MakeError("no recording available (start recording and place blocks/items first)", "NOT_FOUND");
        string asName = input.HasKey("asName") ? string(input["asName"]) : "";
        Json::Value output = Json::Object();
        output["fromActive"] = fromActive;
        output["nbBlocks"] = int(spec.blocks.Length);
        output["nbItems"] = int(spec.items.Length);
        if (asName.Length > 0) {
            bool replace = input.HasKey("replace") ? bool(input["replace"]) : false;
            // Duplicate first — GetRecordingMB returns the recorder's live spec.
            auto stored = StoreSpecAsNamed(spec.Duplicate(), asName, replace);
            output["storedAs"] = stored is null ? "" : asName;
            if (stored is null) output["storeError"] = "failed to store (empty spec or duplicate name; pass replace=true)";
        }
        output["note"] = "Spec pos are world-authored. Stored specs place via PlaceNamedMacroblock with x/y/z = target world pos for the spec's lowest content.";
        return MakeSuccess(output);
    }
#endif
}
