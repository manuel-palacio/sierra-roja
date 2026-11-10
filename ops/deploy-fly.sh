#!/usr/bin/env bash
# Builds the web export and deploys it to Fly.io as the app named in fly.toml (needs the fly CLI,
# logged in). One machine, stopped while nobody is playing and started by the next visit.
set -euo pipefail
cd "$(dirname "$0")/.."
ops/build-web.sh
fly deploy --ha=false
