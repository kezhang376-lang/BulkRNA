"""Result layout v2. Frozen v1 bundles continue to use their own unchanged code."""
from datetime import datetime
from pathlib import Path
import re

SHELL_DIR = "bam_count_data"
R_DIR = "gene_expr_data"
DE_DIR = "gene_diff_expr"
LAYOUT_VERSION = "2.0"


def validate_runtime_layout(runtime):
    if runtime.get("output_layout_version") != LAYOUT_VERSION:
        raise ValueError("Unsupported output layout; use the original frozen code for V1 runs")
    version = runtime.get("pipeline_version", "")
    run_id = runtime.get("run_id", "")
    if not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", version):
        raise ValueError("Invalid pipeline_version")
    match = re.fullmatch(r"v" + re.escape(version) + r"_([0-9]{8})_run([0-9]{2,})", run_id)
    if not match or int(match[2]) == 0:
        raise ValueError("run_id must be v<version>_<YYYYMMDD>_run<sequence>, e.g. v2.0.0_20261027_run01")
    try:
        datetime.strptime(match[1], "%Y%m%d")
    except ValueError as error:
        raise ValueError("Invalid run_id calendar date") from error
    output_dir = runtime.get("config", {}).get("paths", {}).get("output_dir")
    if not isinstance(output_dir, str) or not output_dir:
        raise ValueError("Missing paths.output_dir")
    expected = Path(output_dir) / run_id
    actual = Path(runtime.get("run_root", ""))
    if actual != expected or ".." in actual.parts:
        raise ValueError("run_root must be output_dir/run_id, without an extra runs directory")
    return actual
