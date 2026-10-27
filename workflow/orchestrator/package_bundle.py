#!/usr/bin/env python3
"""Finalize a prepared directory as an immutable SHA256-verified .tar.gz bundle."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile


def package(bundle, archive):
    bundle = Path(bundle).resolve()
    archive = Path(archive).resolve()
    if bundle in archive.parents:
        raise ValueError("Archive must be outside bundle directory")
    if archive.exists() or (bundle / "MANIFEST.sha256.json").exists():
        raise ValueError("Refusing to overwrite a finalized bundle/archive")
    runtime = json.loads((bundle / "runtime.json").read_text(encoding="utf-8"))
    if runtime.get("blockers"):
        raise ValueError("Cannot release a blocked bundle")
    files = {}
    for path in sorted(bundle.rglob("*")):
        if path.is_symlink():
            raise ValueError(f"Symlink in bundle: {path}")
        if path.is_file():
            files[path.relative_to(bundle).as_posix()] = hashlib.sha256(path.read_bytes()).hexdigest()
    (bundle / "MANIFEST.sha256.json").write_text(json.dumps({"run_id": runtime["run_id"], "files": files}, indent=2), encoding="utf-8")
    with tarfile.open(archive, "x:gz") as tar:
        for path in sorted(bundle.rglob("*")):
            if path.is_file():
                tar.add(path, arcname=path.relative_to(bundle).as_posix(), recursive=False)
    checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix(archive.suffix + ".sha256").write_text(f"{checksum}  {archive.name}\n", encoding="ascii")
    print(json.dumps({"archive": str(archive), "sha256": checksum, "files": len(files) + 1}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle")
    parser.add_argument("archive")
    args = parser.parse_args()
    package(args.bundle, args.archive)
