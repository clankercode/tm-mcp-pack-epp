#!/usr/bin/env bash
set -euo pipefail

mode="${1:-dev}"
case "$mode" in
  dev|release-check) ;;
  *)
    echo "usage: ./build.sh [dev|release-check]" >&2
    exit 2
    ;;
esac

root="$(cd "$(dirname "$0")" && pwd)"
slug="tm-mcp-pack-epp"
plugins_dir="${PLUGINS_DIR:-${OPENPLANET_DIR:-$HOME/OpenplanetNext}/Plugins}"
dest="$plugins_dir/$slug"
rb_host="${TM_REMOTE_BUILD_HOST:-10.100.1.3}"

mkdir -p "$dest"
rsync -a --delete --exclude '.git' "$root/src/" "$dest/"
cp "$root/info.toml" "$dest/info.toml"
if [[ "$mode" == "dev" ]]; then
  sed -i 's/^#__DEFINES__/defines = ["DEV"]/' "$dest/info.toml"
  sed -i 's/^\(name[ \t="]*\)\(.*\)"/\1\2 (Dev)"/' "$dest/info.toml"
else
  sed -i '/^defines[[:space:]]*=/d' "$dest/info.toml"
fi

echo "Staged $slug -> $dest"
if command -v tm-remote-build >/dev/null 2>&1; then
  tm-remote-build unload "$slug" -op OpenplanetNext --host "$rb_host" >/dev/null 2>&1 || true
  tm-remote-build load folder "$slug" -op OpenplanetNext --host "$rb_host"
else
  echo "tm-remote-build not found; load $slug from Openplanet UI"
fi
