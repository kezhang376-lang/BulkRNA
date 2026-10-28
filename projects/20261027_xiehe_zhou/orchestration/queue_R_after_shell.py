"""Project-specific detached R dependency waiter. No kubectl or credentials.

Waits on shared Shell status, audits inputs, then calls the unchanged R launcher.
Never restarts Shell/R, changes science settings, or claims R has completed.
"""
import argparse
import csv
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time

MAX_WAIT_SECONDS = 48 * 60 * 60
POLL_SECONDS = 30


def now():
    return datetime.now(timezone.utc).isoformat()


def write_state(path, data):
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(data, indent=2), encoding="utf-8")
    temp.replace(path)


def audit_shell(bundle, runtime):
    out = Path(runtime["run_root"]) / "bam_count_data"
    if json.loads((out / "status.json").read_text())["status"] != "succeeded":
        raise ValueError("Shell has not succeeded")
    if (out / "runtime.json").read_bytes() != (bundle / "runtime.json").read_bytes():
        raise ValueError("Shell runtime snapshot differs from this bundle")
    with (bundle / "samples.tsv").open(encoding="utf-8-sig", newline="") as stream:
        ids = [row["sample_id"] for row in csv.DictReader(stream, delimiter="\t")]
    if len(ids) != 6 or len(set(ids)) != 6:
        raise ValueError("This project waiter requires the reviewed six unique samples")
    matrix = out / "counts/raw_counts.tsv"
    totals = [0] * len(ids)
    genes = set()
    with matrix.open(encoding="utf-8", newline="") as stream:
        rows = csv.reader(stream, delimiter="\t")
        if next(rows) != ["gene_id", *ids]:
            raise ValueError("Counts sample order differs from frozen metadata")
        for row in rows:
            if len(row) != 7 or not row[0] or row[0] in genes or not all(x.isdecimal() for x in row[1:]):
                raise ValueError("Invalid/duplicate gene or noninteger counts")
            genes.add(row[0])
            totals = [a + int(b) for a, b in zip(totals, row[1:])]
    if not genes or not all(totals):
        raise ValueError("Empty matrix or zero library")
    with (out / "qc/assignment_summary.tsv").open(encoding="utf-8", newline="") as stream:
        assignment = list(csv.DictReader(stream, delimiter="\t"))
    if [row["sample_id"] for row in assignment] != ids or [int(row["assigned_units"]) for row in assignment] != totals:
        raise ValueError("Assigned fragment totals differ from counts")
    for sid in ids:
        for suffix in (".Aligned.sortedByCoord.out.bam", ".Aligned.sortedByCoord.out.bam.bai"):
            if (out / "bam" / sid / (sid + suffix)).stat().st_size == 0:
                raise ValueError("Empty BAM/index")
        fastp = json.loads((out / "qc" / (sid + ".fastp.json")).read_text())["summary"]
        star = json.loads((out / "qc" / (sid + ".star.json")).read_text())
        if int(star["Number of input reads"]) * 2 != int(fastp["after_filtering"]["total_reads"]):
            raise ValueError("STAR input differs from fastp paired output")
    if (out / "qc/multiqc/multiqc_report.html").stat().st_size == 0:
        raise ValueError("Empty MultiQC report")
    return {"checked_utc": now(), "status": "shell_dependency_verified", "genes": len(genes),
            "samples": ids, "column_totals": totals,
            "raw_counts_sha256": hashlib.sha256(matrix.read_bytes()).hexdigest(),
            "note": "BAM/index presence checked; Shell previously ran quickcheck/index. Not a biological QC verdict."}


def dependency_status(path):
    if not path.exists():
        return "not_started"
    state = json.loads(path.read_text())["status"]
    if state not in ("running", "succeeded", "failed"):
        raise ValueError("Unknown Shell status")
    return state


def context(bundle):
    bundle = bundle.resolve()
    sys.path.insert(0, str(bundle / "code/shell"))
    from launch_stage import verify_bundle
    from shell_stage import verify_account
    from layout import validate_runtime_layout
    runtime = json.loads((bundle / "runtime.json").read_text())
    verify_account(runtime["config"])
    verify_bundle(bundle)
    validate_runtime_layout(runtime)
    if bundle.name != runtime["run_id"]:
        raise ValueError("Bundle name differs from run_id")
    return bundle, runtime


def worker(bundle, runtime):
    folder = Path(runtime["run_root"]) / "launcher"
    status_file = folder / "r.queue.status.json"
    started = time.monotonic()
    write_state(status_file, {"status": "waiting_for_shell", "pid": os.getpid(), "started_utc": now(),
                              "max_wait_seconds": MAX_WAIT_SECONDS})
    try:
        while True:
            state = dependency_status(Path(runtime["run_root"]) / "bam_count_data/status.json")
            if state == "failed":
                raise ValueError("Shell failed; R will not be started")
            if state == "succeeded":
                break
            if time.monotonic() - started > MAX_WAIT_SECONDS:
                raise TimeoutError("Shell wait exceeded 48 hours; no R started")
            time.sleep(POLL_SECONDS)
        context(bundle)  # Recheck frozen files and identity after waiting.
        audit = audit_shell(bundle, runtime)
        write_state(folder / "r.dependency_audit.json", audit)
        result = subprocess.run([sys.executable, "-B", str(bundle / "code/shell/start_stage.py"),
                                 "r", str(bundle / "runtime.json"), "--execute"],
                                capture_output=True, text=True)
        print(result.stdout, flush=True)
        print(result.stderr, file=sys.stderr, flush=True)
        if result.returncode:
            raise ValueError("R launcher checks/start failed; see r.queue.log")
        launch = json.loads((folder / "r.launch.json").read_text())
        write_state(status_file, {"status": "r_launched_not_completed", "finished_utc": now(),
                                  "r_pid": launch["pid"], "dependency_audit": str(folder / "r.dependency_audit.json")})
    except BaseException as error:
        write_state(status_file, {"status": "failed", "finished_utc": now(), "error": str(error)})
        raise


def submit(bundle, runtime):
    # Does not require counts yet; confirms R dependencies load before queuing.
    subprocess.run([sys.executable, "-B", str(bundle / "code/shell/launch_stage.py"),
                    "r", str(bundle / "runtime.json"), "--environment-only"], check=True)
    root = Path(runtime["run_root"])
    if (root / "gene_expr_data").exists() or (root / "launcher/r.lock").exists():
        raise ValueError("R already started; refusing duplicate queue")
    folder = root / "launcher"
    folder.mkdir(parents=True, exist_ok=True)
    with (folder / "r.queue.lock").open("x") as stream:
        stream.write("Dependency queue lock; inspect state, never restart blindly.\n")
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    with (folder / "r.queue.log").open("xb") as log:
        process = subprocess.Popen([sys.executable, "-B", str(Path(__file__).resolve()), str(bundle),
                                    "--worker", "--execute"], stdin=subprocess.DEVNULL, stdout=log,
                                   stderr=subprocess.STDOUT, start_new_session=True, close_fds=True, env=env)
    state = {"status": "queue_launched_not_completed", "pid": process.pid, "started_utc": now(),
             "bundle": str(bundle), "max_wait_seconds": MAX_WAIT_SECONDS}
    write_state(folder / "r.queue.launch.json", state)
    print(json.dumps(state, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle", type=Path)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--submit", action="store_true")
    modes.add_argument("--worker", action="store_true")
    parser.add_argument("--execute", action="store_true", required=True)
    args = parser.parse_args()
    bundle, runtime = context(args.bundle)
    (submit if args.submit else worker)(bundle, runtime)
