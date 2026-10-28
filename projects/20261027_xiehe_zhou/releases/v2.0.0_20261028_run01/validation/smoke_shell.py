#!/usr/bin/env python3
"""Separate Shell compatibility test: first 10,000 pairs of ONE sample only."""
import csv
import gzip
import json
from pathlib import Path
import sys

sys.dont_write_bytecode = True
bundle = Path(sys.argv[1]).resolve()
probe = Path(sys.argv[2]).resolve()
sys.path.insert(0, str(bundle / "code/shell"))
from launch_stage import verify_bundle, configure_environment
from shell_stage import verify_account, run, atomic_json

verify_bundle(bundle)
runtime = json.loads((bundle / "runtime.json").read_text())
cfg = runtime["config"]
verify_account(cfg)
configure_environment(cfg, "shell")
if runtime.get("blockers"):
    raise ValueError("Blocked project bundle")
raw_root = Path(cfg["paths"]["input_dir"]).resolve()
if probe == raw_root or raw_root in probe.parents or probe == bundle or bundle in probe.parents:
    raise ValueError("Validation output must be separate from raw data and bundle")
probe.mkdir(parents=True, exist_ok=False)
atomic_json(probe / "status.json", {"status": "running", "kind": "compatibility_only"})
try:
    with (bundle / "samples.tsv").open(newline="") as f:
        row = next(csv.DictReader(f, delimiter="\t"))
    inputs = [Path(row[key]) if Path(row[key]).is_absolute() else raw_root / row[key]
              for key in ("fastq_r1", "fastq_r2")]
    fixture = probe / "fixture"
    fixture.mkdir()
    outputs = [fixture / "probe_1.fq.gz", fixture / "probe_2.fq.gz"]
    pairs = 0
    with gzip.open(inputs[0], "rb") as r1, gzip.open(inputs[1], "rb") as r2, \
            gzip.open(outputs[0], "xb") as w1, gzip.open(outputs[1], "xb") as w2:
        for _ in range(10000):
            first = [r1.readline() for _ in range(4)]
            second = [r2.readline() for _ in range(4)]
            if not first[0] and not second[0]:
                break
            for record in (first, second):
                if not all(record) or not record[0].startswith(b"@") or not record[2].startswith(b"+") or len(record[1].strip()) != len(record[3].strip()):
                    raise ValueError("Malformed FASTQ fixture record")
            def read_id(record):
                name = record[0].split()[0]
                return name[:-2] if name.endswith((b"/1", b"/2")) else name
            if read_id(first) != read_id(second):
                raise ValueError("FASTQ pair IDs differ")
            w1.writelines(first)
            w2.writelines(second)
            pairs += 1
    if pairs == 0:
        raise ValueError("No paired reads")
    sample = {"sample_id": row["sample_id"], "group": row["group"],
              "fastq_r1": str(outputs[0]), "fastq_r2": str(outputs[1])}
    with (probe / "samples.tsv").open("x", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(sample), delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerow(sample)
    cfg["paths"]["input_dir"] = str(fixture)
    cfg["paths"]["output_dir"] = str(probe / "results")
    runtime["run_root"] = str(probe / "results" / runtime["run_id"])
    runtime["compatibility_fixture"] = {"source_sample": row["sample_id"], "pairs": pairs, "source_inputs": list(map(str, inputs))}
    atomic_json(probe / "runtime.json", runtime)
    run(probe / "runtime.json", execute=True)
    atomic_json(probe / "status.json", {"status": "succeeded", "kind": "compatibility_only", "pairs": pairs,
                                        "note": "Not the six-sample analysis; do not use fixture results as biological findings"})
    print("SHELL_COMPATIBILITY_PASS", probe)
except BaseException as error:
    atomic_json(probe / "status.json", {"status": "failed", "kind": "compatibility_only", "error": str(error)})
    raise
