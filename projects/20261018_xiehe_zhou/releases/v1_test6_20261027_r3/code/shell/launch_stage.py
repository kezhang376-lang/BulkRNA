#!/usr/bin/env python3
"""Verify a portable bundle and non-root identity, then launch one Pod stage."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import sys

sys.dont_write_bytecode = True
from shell_stage import verify_account


def verify_bundle(bundle):
    manifest = json.loads((bundle / "MANIFEST.sha256.json").read_text(encoding="utf-8"))
    for relative, expected in manifest["files"].items():
        path = (bundle / relative).resolve()
        if bundle not in path.parents or not path.is_file():
            raise ValueError(f"Invalid/missing bundle member: {relative}")
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise ValueError(f"Bundle checksum differs: {relative}; rebuild instead of editing the bundle")


def configure_environment(config, stage):
    env = config.get("environment", {})
    if stage == "shell":
        prepend = env.get("shell_path_prepend", [])
        if not isinstance(prepend, list) or any(not Path(x).is_absolute() or not Path(x).is_dir() for x in prepend):
            raise ValueError("Invalid environment.shell_path_prepend")
        os.environ["PATH"] = os.pathsep.join(prepend + [os.environ.get("PATH", "")])
    if stage == "r":
        rscript = env.get("rscript", "Rscript")
        if not shutil.which(rscript):
            raise ValueError(f"Cannot find configured Rscript: {rscript}")
        return rscript


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stage", choices=["shell", "r"])
    parser.add_argument("runtime")
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check-only", action="store_true")
    modes.add_argument("--environment-only", action="store_true")
    modes.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    mode = "--execute" if args.execute else "--environment-only" if args.environment_only else "--check-only"
    runtime_file = Path(args.runtime).resolve()
    bundle = runtime_file.parent
    verify_bundle(bundle)
    runtime = json.loads(runtime_file.read_text(encoding="utf-8"))
    if runtime.get("blockers"):
        raise ValueError("Bundle has unresolved blockers")
    verify_account(runtime["config"])
    executable = configure_environment(runtime["config"], args.stage)
    os.chdir(bundle)
    os.environ["PYTHONDONTWRITEBYTECODE"] = "1"
    if args.stage == "shell":
        if mode == "--environment-only":
            raise ValueError("Shell stage uses --check-only for its full preflight")
        argv = [sys.executable, str(bundle / "code/shell/shell_stage.py"), str(runtime_file), mode]
    else:
        argv = [executable, "--vanilla", str(bundle / "code/R/run_analysis.R"), str(runtime_file), mode]
    os.execvpe(argv[0], argv, os.environ.copy())


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
