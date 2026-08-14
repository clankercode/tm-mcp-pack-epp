# TM MCP Pack E++

Openplanet plugin that registers **Editor++** APIs as [tm-control-mcp](https://github.com/clankercode/tm-control-mcp) tool-pack tools.

Public names: `tm-mcp-pack-epp.<FuncName>`.

Does **not** remove tm-control-mcp’s in-tree E++ tools.

## Depend

- `tm-control-mcp`
- `Editor` (Editor++)

## Build

```bash
./build.sh dev
```

## Smoke

```bash
python3 ../tm-control-mcp/tools/call.py ListToolPacks
python3 ../tm-control-mcp/tools/call.py tm-mcp-pack-epp.Ping
```

Authoring: `../tm-control-mcp/docs/tool-packs.md`
