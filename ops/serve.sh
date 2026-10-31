#!/bin/zsh
# Serves build/web (made by ops/build-web.sh) on the Tailscale address, http://100.64.0.1:8003/.
# Started by launchd (com.sierraroja.serve) or by hand. launchd gives an empty environment, so PATH
# and HOME are set here. Override the bind address with SIERRAROJA_HOST, e.g. 127.0.0.1.
set -u
export PATH=/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin
export HOME="${HOME:-/Users/$(id -un)}"
REPO="${0:A:h:h}"
cd "$REPO" || exit 1
HOST="${SIERRAROJA_HOST:-100.64.0.1}"
PORT="${SIERRAROJA_PORT:-8003}"
if [[ ! -f build/web/index.html ]]; then
  echo "$(date -u +%FT%TZ) build/web/index.html missing: run ops/build-web.sh first" >&2
  exit 1
fi
echo "$(date -u +%FT%TZ) serve host=$HOST port=$PORT dir=$REPO/build/web"
exec python3 -m http.server "$PORT" --bind "$HOST" --directory build/web
