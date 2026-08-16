namespace Editor {
    import vec3 GetBlockLocation(CGameCtnBlock@ block, bool forceFree = false) from "Editor";
    import vec3 GetBlockRotation(CGameCtnBlock@ block) from "Editor";
    import bool IsBlockFree(CGameCtnBlock@ block) from "Editor";
    // SetAllCursorPos + PosToCoord are imported by Editor/Exports_General.as,
    // which the dependency compile includes since E++ 5fd2ed2 — re-declaring
    // them here collides ("same name and parameters already exists").
}
