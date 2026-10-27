#!/usr/bin/env python3
"""Shell Pod stage, Python >=3.9, standard library only. No remote operations.

Commands use argument arrays (never shell=True). A fresh run output is required;
resume/overwrite and mode C are deliberately not implemented in review v1.
"""
import argparse
import csv
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import subprocess
import sys
from datetime import datetime, timezone


def stamp():
    return datetime.now(timezone.utc).isoformat()


def verify_account(config):
    """Verify effective Linux identity; never change user or fall back to root."""
    account = config.get("kubernetes", {}).get("account")
    if not isinstance(account, str) or not re.fullmatch(r"[a-z_][a-z0-9_-]*", account) or account == "root":
        raise ValueError("kubernetes.account must specify a non-root Linux account")
    if sys.platform != "linux":
        raise ValueError("Pod account verification requires Linux")
    import pwd
    target = pwd.getpwnam(account)
    uid = os.geteuid()
    if target.pw_uid == 0 or uid == 0:
        raise ValueError("Root execution is forbidden; switch to the configured account before launching")
    if uid != target.pw_uid or pwd.getpwuid(uid).pw_name != account:
        raise ValueError(f"Wrong Pod account; expected {account} (UID {target.pw_uid})")


def atomic_json(path, value):
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    temp.replace(path)


def read_table(path):
    with open(path, encoding="utf-8-sig", newline="") as stream:
        return list(csv.DictReader(stream, delimiter="\t"))


def write_table(path, header, rows):
    with open(path, "x", encoding="utf-8", newline="") as stream:
        writer = csv.writer(stream, delimiter="\t", lineterminator="\n")
        writer.writerow(header)
        writer.writerows(rows)


def require_file(path):
    path = Path(path)
    if not path.is_file() or path.stat().st_size == 0:
        raise ValueError(f"Missing or empty file: {path}")
    return path


def resolve_fastp(config):
    """A string extra_args is a strict legacy key/value file, not CLI text."""
    setting = config["fastp"]["extra_args"]
    expected = config["fastp"].get("expected_version")
    if isinstance(setting, list) and all(isinstance(x, str) for x in setting):
        return {"mode": "arguments", "executable": "fastp", "args": setting,
                "expected_version": expected}
    if not isinstance(setting, str) or not Path(setting).is_absolute():
        raise ValueError("fastp.extra_args must be a string array or an absolute config-file path")
    path = require_file(setting)
    if path.stat().st_size > 65536:
        raise ValueError("Legacy fastp config exceeds 64 KiB")
    raw = path.read_bytes()
    values = {}
    for number, line in enumerate(raw.decode("utf-8-sig").splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        pair = line.split(None, 1)
        if len(pair) != 2 or not pair[1].strip() or pair[0] in values:
            raise ValueError(f"Invalid/duplicate fastp config entry at line {number}")
        values[pair[0]] = pair[1].strip()
    options = ["adapter_sequence", "adapter_sequence_r2", "trim_front1", "trim_front2",
               "qualified_quality_phred", "unqualified_percent_limit", "average_qual", "length_required"]
    required = {"fastp", *options}
    if set(values) != required:
        raise ValueError(f"Legacy fastp config keys differ: missing={sorted(required-set(values))}, unknown={sorted(set(values)-required)}")
    executable = Path(values["fastp"])
    if not executable.is_absolute():
        raise ValueError("Legacy fastp executable must be an absolute path")
    require_file(executable)
    if not os.access(executable, os.X_OK):
        raise ValueError(f"Configured fastp is not executable: {executable}")
    for key in ("adapter_sequence", "adapter_sequence_r2"):
        if not re.fullmatch(r"[ACGTNacgtn]+|auto", values[key]):
            raise ValueError(f"Invalid adapter value in legacy fastp config: {key}")
    for key in options[2:]:
        if not re.fullmatch(r"[0-9]+", values[key]):
            raise ValueError(f"Nonnegative integer required for {key}")
    if int(values["unqualified_percent_limit"]) > 100 or int(values["length_required"]) < 1:
        raise ValueError("Invalid percentage or minimum length in fastp config")
    args = [token for key in options for token in ("--" + key, values[key])]
    return {"mode": "legacy_config", "executable": str(executable), "args": args,
            "expected_version": expected, "source_path": str(path), "values": values,
            "source_sha256": hashlib.sha256(raw).hexdigest(), "_source_bytes": raw}


def fastq_path(value, root):
    path = Path(value)
    return path if path.is_absolute() else Path(root) / path


def command(argv, logfile, commands_file):
    with open(commands_file, "a", encoding="utf-8") as stream:
        stream.write(json.dumps({"utc": stamp(), "argv": [str(x) for x in argv]}) + "\n")
    with open(logfile, "ab") as stream:
        subprocess.run([str(x) for x in argv], stdout=stream, stderr=subprocess.STDOUT, check=True)


def featurecounts_to_matrix(source, expected_bams, sample_ids, destination, summary_source, qc_destination):
    """Keep exact sample IDs and verify featureCounts header paths/order/counts."""
    with open(source, encoding="utf-8") as stream:
        rows = csv.reader((line for line in stream if not line.startswith("#")), delimiter="\t")
        header = next(rows)
        if header[:6] != ["Geneid", "Chr", "Start", "End", "Strand", "Length"]:
            raise ValueError("Unexpected featureCounts metadata columns")
        if header[6:] != [str(x) for x in expected_bams]:
            raise ValueError("featureCounts BAM columns differ from manifest")
        seen = set()
        totals = [0] * len(sample_ids)
        with open(destination, "x", encoding="utf-8", newline="") as out:
            writer = csv.writer(out, delimiter="\t", lineterminator="\n")
            writer.writerow(["gene_id", *sample_ids])
            for row in rows:
                if len(row) != len(header) or not row[0] or row[0] in seen:
                    raise ValueError("Malformed featureCounts row or duplicate gene ID")
                seen.add(row[0])
                if not all(value.isdecimal() for value in row[6:]):
                    raise ValueError("Counts must be nonnegative integers, not fractional values")
                values = list(map(int, row[6:]))
                totals = [a + b for a, b in zip(totals, values)]
                writer.writerow([row[0], *values])
        if not seen or any(x == 0 for x in totals):
            raise ValueError("Empty count matrix or zero sample library")
    with open(summary_source, encoding="utf-8") as stream:
        reader = csv.reader(stream, delimiter="\t")
        header = next(reader)
        if header[1:] != [str(x) for x in expected_bams]:
            raise ValueError("featureCounts summary columns differ")
        categories = {row[0]: list(map(int, row[1:])) for row in reader}
    if "Assigned" not in categories or any(len(x) != len(sample_ids) for x in categories.values()):
        raise ValueError("Invalid featureCounts summary")
    rows = []
    for i, sample in enumerate(sample_ids):
        processed = sum(values[i] for values in categories.values())
        assigned = categories["Assigned"][i]
        rows.append([sample, processed, assigned, assigned / processed if processed else 0])
    write_table(qc_destination, ["sample_id", "processed_units", "assigned_units", "assigned_fraction"], rows)


def parse_star(path):
    with open(path, encoding="utf-8") as stream:
        pairs = [line.split("|", 1) for line in stream if "|" in line]
    values = {key.strip(): value.strip() for key, value in pairs}
    required = ["Number of input reads", "Uniquely mapped reads number", "Uniquely mapped reads %"]
    if any(key not in values for key in required):
        raise ValueError(f"Incomplete STAR Log.final.out: {path}")
    return values


def preflight(runtime, samples):
    cfg = runtime["config"]
    if runtime.get("blockers"):
        raise ValueError("Prepared bundle is blocked: " + "; ".join(runtime["blockers"]))
    verify_account(cfg)
    if cfg["input"]["type"] != "fastq":
        raise ValueError("Shell stage requires input.type=fastq")
    if not all(cfg["analysis"][key] for key in ("fastp", "star", "featurecounts")):
        raise ValueError("v1 FASTQ stage requires all fastp/STAR/featureCounts steps")
    fastp = resolve_fastp(cfg)
    versions = {}
    tools = {"fastp": ["--version"], "STAR": ["--version"],
             "featureCounts": ["-v"], "samtools": ["--version"]}
    if cfg["analysis"].get("multiqc", False):
        tools["multiqc"] = ["--version"]
    for tool, args in tools.items():
        executable = fastp["executable"] if tool == "fastp" else tool
        if not shutil.which(executable):
            raise ValueError(f"Missing executable: {tool}")
        proc = subprocess.run([executable, *args], capture_output=True, text=True)
        # Some featureCounts versions print version to stderr with nonzero exit.
        text = proc.stdout + proc.stderr
        if not text.strip():
            raise ValueError(f"Cannot determine version: {tool}")
        if tool == "fastp" and fastp["expected_version"] is not None:
            match = re.search(r"\bfastp\s+([0-9]+\.[0-9]+\.[0-9]+)", text)
            if proc.returncode != 0 or not match or match[1] != fastp["expected_version"]:
                raise ValueError(f"Configured fastp version differs from expected {fastp['expected_version']}: {text.strip()}")
        versions[tool] = text.strip()
    help_proc = subprocess.run(["featureCounts", "-h"], capture_output=True, text=True)
    if "--countReadPairs" not in help_proc.stdout + help_proc.stderr:
        raise ValueError("v1 requires featureCounts with explicit --countReadPairs support")
    require_file(cfg["references"]["fasta"])
    require_file(cfg["references"]["gtf"])
    for filename in ("Genome", "SA", "SAindex", "genomeParameters.txt"):
        require_file(Path(cfg["references"]["star_index"]) / filename)
    ids = [x["sample_id"] for x in samples]
    if not ids or len(ids) != len(set(ids)):
        raise ValueError("Missing/duplicate sample IDs")
    inputs = []
    for row in samples:
        pair = [require_file(fastq_path(row[key], cfg["paths"]["input_dir"]))
                for key in ("fastq_r1", "fastq_r2")]
        if any(not str(x).endswith(".gz") for x in pair):
            raise ValueError("v1 accepts gzipped paired FASTQ only")
        inputs.extend(str(x.resolve()) for x in pair)
    if len(inputs) != len(set(inputs)):
        raise ValueError("FASTQ path reused by multiple samples or mates")
    if not shutil.which("zcat"):
        raise ValueError("STAR compressed input requires zcat")
    return versions, fastp


def run(runtime_file, execute=False):
    runtime_file = Path(runtime_file).resolve()
    runtime = json.loads(runtime_file.read_text(encoding="utf-8"))
    samples = read_table(runtime_file.parent / "samples.tsv")
    versions, fastp = preflight(runtime, samples)
    if not execute:
        print("Shell input/tool checks passed; no analysis performed.")
        return
    cfg = runtime["config"]
    run_root = Path(runtime["run_root"])
    out = run_root / "shell"
    out.mkdir(parents=True, exist_ok=False)  # Existing/partial runs are not overwritten.
    for name in ("clean", "bam", "counts", "qc", "logs"):
        (out / name).mkdir()
    status = out / "status.json"
    atomic_json(status, {"status": "running", "started": stamp(), "pid": os.getpid()})
    try:
        atomic_json(out / "versions.json", versions)
        atomic_json(out / "fastp.resolved.json", {key: value for key, value in fastp.items() if key != "_source_bytes"})
        if "_source_bytes" in fastp:
            (out / "fastp.config.snapshot").write_bytes(fastp["_source_bytes"])
        shutil.copyfile(runtime_file, out / "runtime.json")
        commands = out / "commands.jsonl"
        input_stats = []
        bams, fastp_qc, star_qc = [], [], []
        for row in samples:
            sid = row["sample_id"]
            pair = [fastq_path(row[key], cfg["paths"]["input_dir"]) for key in ("fastq_r1", "fastq_r2")]
            for path in pair:
                stat = path.stat()
                input_stats.append({"sample_id": sid, "path": str(path), "size_bytes": stat.st_size,
                                    "mtime_ns": stat.st_mtime_ns, "content_hash": None})
            clean = [out / "clean" / f"{sid}_clean_{i}.fq.gz" for i in (1, 2)]
            report = out / "qc" / f"{sid}.fastp.json"
            command([fastp["executable"], "-i", pair[0], "-I", pair[1], "-o", clean[0], "-O", clean[1],
                     "--json", report, "--html", out / "qc" / f"{sid}.fastp.html",
                     "--thread", cfg["resources"]["fastp_threads"], *fastp["args"]],
                    out / "logs" / f"{sid}.fastp.log", commands)
            for path in clean:
                require_file(path)
            stats = json.loads(require_file(report).read_text())
            before, after = (stats["summary"][key] for key in ("before_filtering", "after_filtering"))
            fastp_qc.append([sid, before["total_reads"], after["total_reads"], before["q30_rate"], after["q30_rate"]])
            folder = out / "bam" / sid
            folder.mkdir()
            prefix = str(folder / sid) + "."
            star_args = ["STAR", "--runThreadN", cfg["resources"]["star_threads"], "--genomeDir", cfg["references"]["star_index"],
                     "--readFilesCommand", "zcat", "--readFilesIn", *clean, "--outFileNamePrefix", prefix,
                     "--outSAMtype", "BAM", "SortedByCoordinate", "--outBAMsortingThreadN", cfg["resources"]["star_sort_threads"],
                     "--quantMode", "TranscriptomeSAM", "GeneCounts"]
            if "star_sort_memory_bytes" in cfg["resources"]:
                star_args += ["--limitBAMsortRAM", cfg["resources"]["star_sort_memory_bytes"]]
            command(star_args, out / "logs" / f"{sid}.star.log", commands)
            bam = require_file(prefix + "Aligned.sortedByCoord.out.bam")
            command(["samtools", "quickcheck", "-v", bam], out / "logs" / f"{sid}.bam_check.log", commands)
            command(["samtools", "index", bam], out / "logs" / f"{sid}.bam_index.log", commands)
            bams.append(bam)
            values = parse_star(prefix + "Log.final.out")
            atomic_json(out / "qc" / f"{sid}.star.json", values)
            star_qc.append([sid, values["Number of input reads"], values["Uniquely mapped reads number"], values["Uniquely mapped reads %"]])
        atomic_json(out / "input_file_stats.json", {"identity_policy": "size/mtime only; NOT content identity or resume proof", "files": input_stats})
        write_table(out / "qc" / "fastp_summary.tsv", ["sample_id", "before_reads", "after_reads", "before_q30_fraction", "after_q30_fraction"], fastp_qc)
        write_table(out / "qc" / "star_summary.tsv", ["sample_id", "input_pairs", "unique_pairs", "unique_percent"], star_qc)
        fc = cfg["featurecounts"]
        table = out / "counts" / "featurecounts.txt"
        command(["featureCounts", "-T", cfg["resources"]["featurecounts_threads"], "-p", "--countReadPairs",
                 "-s", {"unstranded": 0, "forward": 1, "reverse": 2}[cfg["input"]["strandedness"]],
                 "-t", fc["feature_type"], "-g", fc["gene_attribute"], "-a", cfg["references"]["gtf"], "-o", table, *bams],
                out / "logs" / "featurecounts.log", commands)
        featurecounts_to_matrix(table, bams, [x["sample_id"] for x in samples], out / "counts" / "raw_counts.tsv",
                                str(table) + ".summary", out / "qc" / "assignment_summary.tsv")
        # 记录实际使用的小型参考元数据，不把大文件 size/mtime 冒充哈希。
        ref = Path(cfg["references"]["star_index"]) / "genomeParameters.txt"
        shutil.copyfile(ref, out / "genomeParameters.txt")
        atomic_json(out / "reference_metadata.json", {"genome_parameters_sha256": hashlib.sha256(ref.read_bytes()).hexdigest(),
                    "reference_identity": "Full FASTA/GTF/index content verification remains a pre-run requirement"})
        if cfg["analysis"].get("multiqc", False):
            command(["multiqc", "--outdir", out / "qc" / "multiqc", "--filename", "multiqc_report.html", out],
                    out / "logs" / "multiqc.log", commands)
            require_file(out / "qc" / "multiqc" / "multiqc_report.html")
        atomic_json(status, {"status": "succeeded", "finished": stamp()})
    except BaseException as error:
        atomic_json(status, {"status": "failed", "finished": stamp(), "error": str(error)})
        raise


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runtime")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--check-only", action="store_true")
    mode.add_argument("--execute", action="store_true")
    args = parser.parse_args()
    try:
        run(args.runtime, args.execute)
    except Exception as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
