#!/usr/bin/env bash
# Exports the game to build/web/index.html (needs Godot 4.7.2 and its export templates).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/web
godot --headless --path . --export-release "Web" build/web/index.html
