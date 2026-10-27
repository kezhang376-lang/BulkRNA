#!/usr/bin/env bash
set -Eeuo pipefail
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${bundle_dir}/code/shell/launch_stage.py" r "${bundle_dir}/runtime.json" "${1:---environment-only}"
