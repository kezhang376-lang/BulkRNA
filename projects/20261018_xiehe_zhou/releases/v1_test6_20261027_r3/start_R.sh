#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 1 && "$1" == "--execute" ]] || { echo "Explicit --execute required" >&2; exit 2; }
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 -B "${bundle_dir}/code/shell/start_stage.py" r "${bundle_dir}/runtime.json" --execute
