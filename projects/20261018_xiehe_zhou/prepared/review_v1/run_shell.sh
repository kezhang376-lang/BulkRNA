#!/usr/bin/env bash
set -Eeuo pipefail
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${bundle_dir}/code/shell/run_shell.sh" "${bundle_dir}/runtime.json" "${1:---check-only}"
