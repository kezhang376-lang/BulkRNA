#!/usr/bin/env bash
# 仅为 Linux Shell Pod 的入口；不执行 kubectl，不读取 YAML，不使用 eval。
set -Eeuo pipefail
if [[ $# -ne 2 || ( "$2" != "--check-only" && "$2" != "--execute" ) ]]; then
  printf '%s\n' 'Usage: bash run_shell.sh <bundle/runtime.json> --check-only|--execute' >&2
  exit 2
fi
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "${script_dir}/shell_stage.py" "$1" "$2"
