# TM MCP Pack E++

Openplanet plugin that registers **Editor++** APIs as [tm-control-mcp](https://github.com/clankercode/tm-control-mcp) tool-pack tools.

Public names: `tm-mcp-pack-epp.<FuncName>` — 60 tools covering every Editor++-related tool tm-control-mcp ships built-in, plus batch place/delete, `ConvertBlockToFree`, map capture, embedded colors, item skins, pivot, and placement-mode controls that the builtin set doesn't expose.

Does **not** remove tm-control-mcp's in-tree E++ tools.

## License

Dual-licensed: [UNLICENSE](UNLICENSE) (public domain) or [CC0 1.0](LICENSE-CC0) — choose either.

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
