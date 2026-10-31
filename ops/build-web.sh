#!/usr/bin/env bash
# Exports the game to build/web/index.html (needs Godot 4.7.2 and its export templates).
set -euo pipefail
cd "$(dirname "$0")/.."
# logs/ is for launchd, which opens the plist's log path before ops/serve.sh runs, and is not in git.
mkdir -p build/web logs
godot --headless --path . --export-release "Web" build/web/index.html
