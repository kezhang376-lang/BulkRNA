#!/usr/bin/env bash
set -Eeuo pipefail
bundle_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
exec Rscript --vanilla "${bundle_dir}/code/R/run_analysis.R" "${bundle_dir}/runtime.json" "${1:---check-only}"
