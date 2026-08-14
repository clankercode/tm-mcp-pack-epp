## Project Notes

E++ tool pack for tm-control-mcp. Public tools are `tm-mcp-pack-epp.<Name>`.

- `./build.sh dev` stages to `~/OpenplanetNext/Plugins/tm-mcp-pack-epp` and RemoteBuild-loads.
- Hard deps: `tm-control-mcp`, `Editor`.
- Do not remove in-tree E++ tools from tm-control-mcp from this repo.
- Live smoke: `python3 ../tm-control-mcp/tools/call.py tm-mcp-pack-epp.Ping`
