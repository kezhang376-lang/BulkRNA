#!/usr/bin/env python3
"""Explicit, detached launch for an authorized full stage; never runs by default."""
import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import subprocess
import sys

sys.dont_write_bytecode = True
from launch_stage import verify_bundle
from shell_stage import verify_account, atomic_json
from layout import SHELL_DIR, R_DIR, validate_runtime_layout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["shell", "r"])
    parser.add_argument("runtime")
    parser.add_argument("--execute", action="store_true", required=True)
    args = parser.parse_args()
    runtime_file = Path(args.runtime).resolve()
    bundle = runtime_file.parent
    runtime = json.loads(runtime_file.read_text())
    validate_runtime_layout(runtime)
    if bundle.name != runtime["run_id"]:
        raise ValueError("Bundle directory name must equal run_id")
    verify_account(runtime["config"])
    verify_bundle(bundle)
    launcher = bundle / "code/shell/launch_stage.py"
    command = [sys.executable, "-B", str(launcher), args.stage, str(runtime_file)]
    subprocess.run(command + ["--check-only"], check=True)
    run_root = Path(runtime["run_root"])
    stage_output = run_root / (SHELL_DIR if args.stage == "shell" else R_DIR)
    if stage_output.exists():
        raise ValueError("Stage output already exists; no restart/overwrite")
    folder = run_root / "launcher"
    folder.mkdir(parents=True, exist_ok=True)
    lock = folder / (args.stage + ".lock")
    with lock.open("x") as stream:
        stream.write("New-run launch lock; inspect state before any retry.\n")
    logfile = folder / (args.stage + ".launcher.log")
    env = os.environ.copy()
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    with logfile.open("xb") as log:
        process = subprocess.Popen(command + ["--execute"], stdin=subprocess.DEVNULL, stdout=log,
            stderr=subprocess.STDOUT, start_new_session=True, close_fds=True, env=env)
    result = {"status": "launched_not_completed", "stage": args.stage, "pid": process.pid,
        "started_utc": datetime.now(timezone.utc).isoformat(), "runtime": str(runtime_file), "log": str(logfile)}
    atomic_json(folder / (args.stage + ".launch.json"), result)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
