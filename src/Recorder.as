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

    // Control-tree navigation (mirrors E++ CControlNavigation — not exported).
    CControlBase@ FollowCtrlPath(CControlContainer@ c, string[] &in path) {
        for (uint i = 0; i < path.Length; i++) {
            MwId want = MwId();
            want.SetName(path[i]);
            CControlBase@ hit = null;
            if (c.Id.Value == want.Value) @hit = c;
            if (hit is null) {
                for (uint k = 0; k < c.Childs.Length; k++) {
                    if (c.Childs[k].Id.Value == want.Value) { @hit = c.Childs[k]; break; }
                }
            }
            if (hit is null) return null;
            if (i == path.Length - 1) return hit;
            @c = cast<CControlContainer>(hit);
            if (c is null) return null;
        }
        return null;
    }

    // A modal dialog blocks editor automation (copy/paste, recorder transfer,
    // saves). Returns null when nothing is blocking. Covers BasicDialogs
    // (engine message/yes-no dialogs) and ActiveMenus (manialink-layer dialogs,
    // e.g. the snap editor or save-as UI).
    Json::Value@ ActiveDialogJson() {
        auto app = cast<CGameCtnApp>(GetApp());
        if (app is null) return null;
        Json::Value@ j = null;
        if (app.BasicDialogs !is null) {
            auto dlg = app.BasicDialogs;
            if (int(dlg.Dialog) != 0) {
                @j = Json::Object();
                j["dialog"] = tostring(int(dlg.Dialog));
                if (dlg.Message_LabelText.Length > 0) j["message"] = dlg.Message_LabelText;
                if (dlg.WaitMessage_LabelText.Length > 0) j["waitMessage"] = dlg.WaitMessage_LabelText;
            }
            // Menu-layer dialog frames (save-as, yes/no overwrite prompts):
            // read the current frame's id + message label so agents can see
            // and decide on them (e.g. FrameAskYesNo overwrite confirmations).
            auto cf = dlg.Dialogs.CurrentFrame;
            if (cf !is null) {
                if (j is null) @j = Json::Object();
                j["frame"] = cf.IdName;
                // E++ chain {1,0,2,0} from FrameAskYesNo -> message label
                string frameLabel = FrameMessageLabel(cf);
                if (frameLabel.Length > 0) j["frameMessage"] = frameLabel;
                if (cf.IdName == "FrameAskYesNo") {
                    j["type"] = "yesNo";
                    j["respond"] = "RespondDialog tool: respond=yes|no|cancel";
                } else if (cf.IdName == "FrameDialogSaveAs") {
                    j["type"] = "saveAs";
                    j["path"] = dlg.DialogSaveAs_PathToDisplay;
                    j["respond"] = "driven by SaveMacroblockFile; DialogSaveAs_OnValidate/OnCancel via RespondDialog (confirmSaveAs|cancelSaveAs)";
                }
            }
        }
        if (app.ActiveMenus.Length > 0) {
            if (j is null) @j = Json::Object();
            j["activeMenus"] = int(app.ActiveMenus.Length);
        }
        if (j is null) return null;
        j["dismiss"] = "DismissDialogs tool (engine HideDialogs), or the dialog's own confirm/cancel; manialink-layer menus may need their own UI action";
        return j;
    }

    // FrameAskYesNo-style message label at E++ chain {1,0,2,0}; empty string if absent.
    string FrameMessageLabel(CGameMenuFrame@ frame) {
        if (frame is null) return "";
        try {
            auto c1 = FrameChildByChain(frame, {1, 0, 2, 0});
            auto label = cast<CControlLabel>(c1);
            if (label !is null) return label.Label;
        } catch {
            return "";
        }
        return "";
    }

    // Generic child-by-index chain walker (E++ GetFrameChildFromChain pattern).
    CControlBase@ FrameChildByChain(CGameMenuFrame@ frame, array<int> chain) {
        CControlContainer@ cur = frame;
        for (uint i = 0; i < chain.Length; i++) {
            if (cur is null || chain[i] < 0 || uint(chain[i]) >= cur.Childs.Length) return null;
            if (i == chain.Length - 1) return cur.Childs[uint(chain[i])];
            @cur = cast<CControlContainer>(cur.Childs[uint(chain[i])]);
        }
        return null;
    }

    Json::Value@ DismissDialogs(Json::Value &in input) {
        auto app = cast<CGameCtnApp>(GetApp());
        if (app is null || app.BasicDialogs is null) return MakeError("app not available", "UNKNOWN", true);
        app.BasicDialogs.HideDialogs();
        Json::Value output = Json::Object();
        output["dismissed"] = true;
        return MakeSuccess(output);
    }

    // Inspect the current blocking dialog (no side effects).
    Json::Value@ GetDialog(Json::Value &in input) {
        auto dlg = ActiveDialogJson();
        if (dlg is null) {
            Json::Value output = Json::Object();
            output["open"] = false;
            return MakeSuccess(output);
        }
        dlg["open"] = true;
        return MakeSuccess(dlg);
    }

    // Answer an engine dialog: yes/no/cancel (yes-no prompts incl. overwrite),
    // ok (message dialogs), confirmSaveAs/cancelSaveAs (save-as frame).
    Json::Value@ RespondDialog(Json::Value &in input) {
        auto app = cast<CGameCtnApp>(GetApp());
        if (app is null || app.BasicDialogs is null) return MakeError("app not available", "UNKNOWN", true);
        string respond = input.HasKey("respond") ? string(input["respond"]) : "";
        auto dlg = ActiveDialogJson();
        if (dlg is null) return MakeError("no dialog open", "NOT_FOUND", false, "", "Poll GetDialog");
        string frame = dlg.HasKey("frame") ? string(dlg["frame"]) : "";
        auto bd = app.BasicDialogs;
        if (respond == "yes") {
            if (frame != "FrameAskYesNo") return MakeError("respond=yes needs a FrameAskYesNo dialog; current frame: " + frame, "INVALID_INPUT", false, "", "GetDialog");
            bd.AskYesNo_Yes();
        } else if (respond == "no") {
            if (frame != "FrameAskYesNo") return MakeError("respond=no needs a FrameAskYesNo dialog; current frame: " + frame, "INVALID_INPUT", false, "", "GetDialog");
            bd.AskYesNo_No();
        } else if (respond == "cancel") {
            bd.AskYesNo_Cancel();
        } else if (respond == "ok") {
            bd.DoMessage_Ok();
        } else if (respond == "confirmSaveAs") {
            if (frame != "FrameDialogSaveAs") return MakeError("respond=confirmSaveAs needs the save-as dialog; current frame: " + frame, "INVALID_INPUT", false, "", "GetDialog");
            bd.DialogSaveAs_OnValidate();
        } else if (respond == "cancelSaveAs") {
            if (frame != "FrameDialogSaveAs") return MakeError("respond=cancelSaveAs needs the save-as dialog; current frame: " + frame, "INVALID_INPUT", false, "", "GetDialog");
            bd.DialogSaveAs_OnCancel();
        } else {
            return MakeError("unknown respond: " + respond + " (yes|no|cancel|ok|confirmSaveAs|cancelSaveAs)", "INVALID_INPUT");
        }
        Json::Value output = Json::Object();
        output["responded"] = respond;
        output["frame"] = frame;
        return MakeSuccess(output);
    }

    Json::Value RecorderStatusJson() {
        Json::Value s = Json::Object();
        s["isActive"] = MacroblockRecorder::IsActive;
        s["hasExisting"] = MacroblockRecorder::HasExisting;
        s["activeIsEmpty"] = MacroblockRecorder::ActiveRecordingIsEmpty;
        s["activeBlocks"] = int(MacroblockRecorder::ActiveRec_NbBlocks);
        s["activeItems"] = int(MacroblockRecorder::ActiveRec_NbItems);
        s["completedBlocks"] = int(MacroblockRecorder::CompletedRec_NbBlocks);
        s["completedItems"] = int(MacroblockRecorder::CompletedRec_NbItems);
        auto dlg = ActiveDialogJson();
        if (dlg !is null) s["blockingDialog"] = dlg;
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

    // Native save: writes <name>.Macroblock.Gbx into Documents/Trackmania/MacroBlocks/
    // via the engine's pmt.SaveMacroblock (RE'd pipeline: Fid dir 0x16, inventory
    // tree insert + MacroblockModels refresh happen in-engine).
    Json::Value@ SaveMacroblockFile(Json::Value &in input) {
        auto editor = GetEditor();
        if (editor is null || editor.PluginMapType is null) return MakeError("editor not available", "NOT_IN_EDITOR", true, "Editor");
        if (!input.HasKey("name")) return MakeError("missing name");
        string name = string(input["name"]);
        string source = input.HasKey("source") ? string(input["source"]) : "recorder";
        bool overwrite = input.HasKey("overwrite") ? bool(input["overwrite"]) : false;

        CGameCtnMacroBlockInfo@ mb = null;
        string sourceNote = "";
        if (source == "recorder" || source == "copyPaste") {
            // recorder stop transfers the recording to editor.CopyPasteMacroBlockInfo
            // asynchronously (cursor coroutine, several frames) — poll for it.
            for (uint i = 0; i < 120 && mb is null; i++) {
                if (i > 0) yield();
                @mb = editor.CopyPasteMacroBlockInfo;
            }
            if (mb !is null) {
                sourceNote = "editor.CopyPasteMacroBlockInfo (recorder stop target)";
            } else {
                return MakeError("no copy-paste macroblock available; record + stop (cancel=false) first, or copy a selection", "NOT_FOUND", true, "", "StopRecording(false) transfers asynchronously; retry after a moment");
            }
        } else if (source == "tagged") {
            // Region-select the live map blocks recorded under a placement tag, then
            // let the engine copy them into a native CopyPasteMacroBlockInfo.
            if (!input.HasKey("tag")) return MakeError("source=tagged requires tag", "INVALID_INPUT");
            string tag = string(input["tag"]);
            // gather tagged block positions (world pos, recorded at placement time)
            if (editor.Challenge is null) return MakeError("no challenge", "NOT_IN_EDITOR", true, "Editor");
            array<vec3> tagPos;
            for (uint i = 0; i < g_TaggedObjects.Length; i++) {
                auto o = g_TaggedObjects[i];
                if (o.tag != tag || o.kind != "block") continue;
                tagPos.InsertLast(vec3(o.x, o.y, o.z));
            }
            if (tagPos.Length == 0) return MakeError("no tagged blocks found for tag: " + tag, "NOT_FOUND");
            // resolve tagged positions to live blocks (match by pos proximity)
            int3 lo = int3(0x7fffffff, 0x7fffffff, 0x7fffffff);
            int3 hi = int3(0, 0, 0);
            uint found = 0;
            auto blocks = editor.Challenge.Blocks;
            for (uint b = 0; b < blocks.Length; b++) {
                auto blk = blocks[b];
                vec3 wpos = Editor::GetBlockLocation(blk);
                bool match = false;
                for (uint t = 0; t < tagPos.Length; t++) {
                    if (Math::Abs(wpos.x - tagPos[t].x) < 1.0 && Math::Abs(wpos.y - tagPos[t].y) < 1.0 && Math::Abs(wpos.z - tagPos[t].z) < 1.0) {
                        match = true;
                        break;
                    }
                }
                if (!match) continue;
                nat3 bCoord = blk.Coord;
                lo.x = Math::Min(lo.x, bCoord.x); lo.y = Math::Min(lo.y, bCoord.y); lo.z = Math::Min(lo.z, bCoord.z);
                hi.x = Math::Max(hi.x, bCoord.x); hi.y = Math::Max(hi.y, bCoord.y); hi.z = Math::Max(hi.z, bCoord.z);
                found++;
            }
            if (found == 0) return MakeError("tag " + tag + " resolved to no live blocks (placements may have moved)", "NOT_FOUND");
            auto pmt = editor.PluginMapType;
            // Mirror E++ TransferRecordedMbToEditorCopyPasteMb: enter copy-paste mode
            // first, otherwise CopyPaste_Copy operates outside its expected UI state.
            // (Idempotent: setting CopyPaste when already in it is a no-op.)
            Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CopyPaste);
            for (uint i = 0; i < 3; i++) yield();
            pmt.CopyPaste_ResetSelection();
            pmt.CopyPaste_AddOrSubSelection(lo, hi);
            for (uint i = 0; i < 3; i++) yield();
            pmt.CopyPaste_Copy();
            for (uint i = 0; i < 60 && editor.CopyPasteMacroBlockInfo is null; i++) yield();
            @mb = editor.CopyPasteMacroBlockInfo;
            if (mb is null) {
                pmt.CopyPaste_ResetSelection();
                Json::Value err = MakeError("engine copy produced no macroblock (selection " + found + " blocks, bbox " + tostring(lo) + ".." + tostring(hi) + "); copy-paste UI state may require the selection tool", "UNKNOWN", true);
                auto dlg = ActiveDialogJson();
                if (dlg !is null) err["blockingDialog"] = dlg;
                return err;
            }
            sourceNote = "engine CopyPaste_Copy of tag '" + tag + "' (" + found + " blocks)";
        } else {
            return MakeError("unknown source: " + source + " (recorder|copyPaste|tagged)", "INVALID_INPUT");
        }

        // ---- Native save via the engine's own UI flow (the same one E++
        // automates and the game uses): toolbar "save macroblock" -> snap
        // camera scene -> OK -> save-as dialog -> filename -> validate.
        // (The bare pmt.SaveMacroblock(mb) MS call no-ops: the filename is
        // built from dialog-provided name strings that only the UI path sets.)
        auto app = cast<CGameCtnApp>(GetApp());
        if (app is null) return MakeError("app not available", "UNKNOWN", true);
        uint mbBefore = editor.PluginMapType.MacroblockModels.Length;

        // The save-macroblock toolbar button lives in the copy-paste tool
        // frame and only responds in CopyPaste placement mode (E++'s
        // stop-transfer enters it; explicit for recorder/copyPaste sources
        // saved later in time). Idempotent if already in that mode.
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CopyPaste);
        for (uint i = 0; i < 5; i++) yield();

        CControlButton@ saveMbBtn = cast<CControlButton>(FollowCtrlPath(editor.EditorInterface.InterfaceRoot,
            {"FrameMain", "FrameCopyPasteTools", "FrameMacroblock", "ButtonSelectionBoxSaveNew"}));
        if (saveMbBtn is null) return MakeError("save-macroblock toolbar button not found (copy-paste mode?)", "UNKNOWN", true);
        if (source != "recorder" && source != "copyPaste" && source != "tagged") {
            return MakeError("unknown source: " + source + " (recorder|copyPaste|tagged)", "INVALID_INPUT");
        }

        // stage 1: click save-macroblock -> snap camera scene opens
        Json::Value stages = Json::Array();
        saveMbBtn.OnAction();
        CControlButton@ snapOkBtn = null;
        for (uint i = 0; i < 300; i++) {
            yield();
            @snapOkBtn = cast<CControlButton>(FollowCtrlPath(editor.EditorInterface.InterfaceRoot,
                {"FrameEditSnapCamera", "ButtonOk"}));
            if (snapOkBtn !is null && snapOkBtn.IsVisible && snapOkBtn.Parent.IsVisible) break;
            @snapOkBtn = null;
        }
        if (snapOkBtn is null) {
            Json::Value err = MakeError("snap-camera scene did not open after clicking save-macroblock", "UNKNOWN", true);
            auto dlg = ActiveDialogJson();
            if (dlg !is null) err["blockingDialog"] = dlg;
            return err;
        }
        stages.Add("snapSceneOpened");

        // stage 2: confirm snap -> save-as dialog opens
        snapOkBtn.OnAction();
        CGameMenuFrame@ saveAs = null;
        for (uint i = 0; i < 300; i++) {
            yield();
            auto cf = app.BasicDialogs.Dialogs.CurrentFrame;
            if (cf !is null && cf.IdName == "FrameDialogSaveAs") { @saveAs = cf; break; }
        }
        if (saveAs is null) {
            Json::Value err = MakeError("save-as dialog did not open after confirming the snapshot", "UNKNOWN", true);
            auto dlg = ActiveDialogJson();
            if (dlg !is null) err["blockingDialog"] = dlg;
            return err;
        }
        stages.Add("saveAsDialogOpened");

        // stage 3: set filename + validate
        auto entryPath = cast<CControlEntry>(FollowCtrlPath(saveAs, {"FrameContent", "FrameSave", "EntryFileName"}));
        if (entryPath is null) return MakeError("save-as filename entry not found", "UNKNOWN", true);
        auto d = cast<CGameDialogs>(entryPath.Nod);
        if (d is null) return MakeError("save-as filename entry nod is not CGameDialogs", "UNKNOWN", true);
        d.String = name + ".Macroblock.Gbx";
        yield();
        app.BasicDialogs.DialogSaveAs_OnValidate();
        stages.Add("validated");

        // stage 4: overwrite prompt? Detect FrameAskYesNo. With overwrite=true
        // auto-confirm Yes; otherwise report it and leave the dialog open for
        // the agent to decide via RespondDialog (yes/no/cancel).
        bool sawOverwrite = false;
        for (uint i = 0; i < 60; i++) {
            yield();
            auto cf = app.BasicDialogs.Dialogs.CurrentFrame;
            if (cf !is null && cf.IdName == "FrameAskYesNo") { sawOverwrite = true; break; }
        }
        if (sawOverwrite) {
            stages.Add("overwritePrompted");
            if (overwrite) {
                app.BasicDialogs.AskYesNo_Yes();
                stages.Add("overwriteConfirmed");
            } else {
                string msg = FrameMessageLabel(app.BasicDialogs.Dialogs.CurrentFrame);
                Json::Value output = Json::Object();
                output["saved"] = false;
                output["name"] = name;
                output["fileName"] = name + ".Macroblock.Gbx";
                output["stages"] = stages;
                output["source"] = sourceNote;
                output["overwritePrompt"] = true;
                output["message"] = msg;
                output["note"] = "A file with this name already exists. The overwrite prompt is OPEN — call RespondDialog {respond:\"yes\"} to overwrite, {\"no\"|\"cancel\"} to abort; then SaveMacroblockFile again if needed.";
                return MakeSuccess(output);
            }
        }

        // stage 5: wait for the file on disk. The save-as dialog defaults to
        // Documents/Trackmania/Blocks/<Collection>/ (observed) — index the
        // Blocks tree for the filename; also check MacroBlocks/.
        string foundPath = "";
        string wantFile = name + ".Macroblock.Gbx";
        for (uint i = 0; i < 300 && foundPath.Length == 0; i++) {
            yield();
            if (IO::FileExists("C:/users/steamuser/Documents/Trackmania/MacroBlocks/" + wantFile)) {
                foundPath = "C:/users/steamuser/Documents/Trackmania/MacroBlocks/" + wantFile;
                break;
            }
            string[] results = IO::IndexFolder("C:/users/steamuser/Documents/Trackmania/Blocks/", true);
            for (uint c = 0; c < results.Length; c++) {
                if (results[c].EndsWith(wantFile)) { foundPath = "C:/users/steamuser/Documents/Trackmania/Blocks/" + results[c]; break; }
            }
        }

        uint mbAfter = editor.PluginMapType.MacroblockModels.Length;
        Json::Value output = Json::Object();
        output["saved"] = foundPath.Length > 0;
        output["name"] = name;
        output["fileName"] = name + ".Macroblock.Gbx";
        output["filePath"] = foundPath;
        output["stages"] = stages;
        output["source"] = sourceNote;
        output["inventoryCountBefore"] = int(mbBefore);
        output["inventoryCountAfter"] = int(mbAfter);
        if (foundPath.Length == 0) {
            output["error"] = "dialog flow completed but no file appeared on disk";
            auto dlg = ActiveDialogJson();
            if (dlg !is null) output["blockingDialog"] = dlg;
        } else {
            output["note"] = "Native .Macroblock.Gbx written; inventory refreshes in-engine (verify with InspectMacroblockModel).";
        }
        return MakeSuccess(output);
    }
#endif
}
