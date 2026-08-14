# Plugin initialization brief

## Simple interview — required

- **Plugin identity / folder:** `tm-mcp-pack-epp` (module `TmMcpPackEpp`)
- **Purpose:** Register E++ (Editor++) functions as TmMcp tool-pack tools (`tm-mcp-pack-epp.FuncName`) with the same or greater coverage than tm-control-mcp’s in-tree E++ tools. Does not remove those builtins.
- **Target games:** Trackmania (current)
- **Tested games and Openplanet versions/channels:** OpenplanetNext / current TM (to be recorded at first load)
- **Publication intent:** public candidate (same org as tm-control-mcp when published)
- **Source, provenance, and AI use:** newly authored wrappers around Editor++ public exports; UNLICENSE/CC0; AI-assisted
- **Paid-feature permissions:** N/A
- **Architecture / module topology:** one plugin module; depends on `tm-control-mcp` + `Editor`
- **Dependencies:** required `tm-control-mcp`, `Editor`. Plugin does not load without them.
- **Canonical source and build/staging flow:** this folder; `./build.sh dev` rsyncs `src/` + `info.toml` to `~/OpenplanetNext/Plugins/tm-mcp-pack-epp` and RemoteBuild-loads
- **Expected Openplanet callbacks:** `Main`, `OnEnabled`, `OnDisabled`, `OnDestroyed`
- **Smallest observable completion gate:** `ListToolPacks` includes `tm-mcp-pack-epp`; `tm-mcp-pack-epp.Ping` returns `{pong:true}`
- **Validation plan:** `openplanet-lsp` optional; in-game compile is ground truth; live `call.py` after load
- **Policy assumptions:** localhost MCP only (inherited); no secrets; human-controlled publication

## Advanced branches — answer when applicable

### Assets

- N/A — no fonts/media

### Dependencies and exports

- Dependency IDs: `tm-control-mcp`, `Editor` (hard)
- `shared_exports`: N/A — this plugin does not export types
- Dependent reload: if TmMcp or Editor unloads, this pack must unregister/reload

### Build, staging, and defines

- `./build.sh dev` injects `DEV`; `./build.sh release-check` does not
- Exact-bytes: rsync `--delete` of `src/` to staged folder

### Authentication and public configuration

- N/A — no settings, no secrets

### Packaging and publication preparation

- Folder plugin first; `.op` later if tagged
- Human decides GH publish

## Initialization result

- **Tracked brief path:** `docs/INITIALIZATION-BRIEF.md`
- **Clone-local state path:** `.local-state.md` (git-excluded)
- **Manifest and entrypoint:** `info.toml`, `src/Main.as`
- **Static diagnostics:** recorded at first build
- **First-load evidence:** 2026-08-15 Openplanet.log `Loaded plugin 'tm-mcp-pack-epp'` + `TM Control MCP pack registered tm-mcp-pack-epp tools=24`. Live: Ping, ListCoverage, GetInventorySummary (5966 items), ControlEditMode get.
- **Explicit runtime blocker, if evidence is unavailable:** —
- **Initialization boundary:** feature tools included in first increment per user request (E++ coverage)
