#!/usr/bin/env python3
"""Upload only a small code archive into a NEW directory as the configured user.
No Pod changes, overwrites, recursive deletion or analysis execution.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts/shell"))
from layout import validate_runtime_layout

RECEIVER = r'''
import hashlib,io,json,os,pathlib,pwd,sys,tarfile
destination=pathlib.Path(sys.argv[1])
account,expected=sys.argv[2:4]
if os.geteuid()==0 or pwd.getpwuid(os.geteuid()).pw_name!=account:
 raise SystemExit("Wrong/root account; refusing upload")
if not destination.is_absolute() or destination.exists():
 raise SystemExit("Destination must be a NEW absolute directory")
data=sys.stdin.buffer.read(32*1024*1024+1)
if len(data)>32*1024*1024 or hashlib.sha256(data).hexdigest()!=expected:
 raise SystemExit("Archive size/checksum invalid")
with tarfile.open(fileobj=io.BytesIO(data),mode="r:gz") as archive:
 members=archive.getmembers()
 if len(members)>300 or sum(x.size for x in members)>100*1024*1024:
  raise SystemExit("Not a small code-only bundle")
 for member in members:
  path=pathlib.PurePosixPath(member.name)
  if not member.isfile() or path.is_absolute() or ".." in path.parts:
   raise SystemExit("Unsafe archive member")
 destination.mkdir(parents=True,exist_ok=False)
 for member in members:
  target=destination/member.name
  target.parent.mkdir(parents=True,exist_ok=True)
  with target.open("xb") as f:
   f.write(archive.extractfile(member).read())
manifest=json.loads((destination/"MANIFEST.sha256.json").read_text())
for relative,digest in manifest["files"].items():
 target=(destination/relative).resolve()
 if destination.resolve() not in target.parents or hashlib.sha256(target.read_bytes()).hexdigest()!=digest:
  raise SystemExit("Extracted package checksum invalid")
print(json.dumps({"status":"uploaded_verified","destination":str(destination),"uid":os.geteuid(),"archive_sha256":expected,"files":len(members)}))
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("bundle")
    parser.add_argument("archive")
    parser.add_argument("destination")
    args = parser.parse_args()
    runtime = json.loads((Path(args.bundle) / "runtime.json").read_text(encoding="utf-8"))
    validate_runtime_layout(runtime)
    if Path(args.bundle).name != runtime["run_id"] or Path(args.archive).name != runtime["run_id"] + ".tar.gz":
        raise ValueError("Bundle directory and archive name must match run_id")
    k = runtime["config"]["kubernetes"]
    destination = args.destination
    # 只允许项目根下workflow目录，不能把代码包解压进原始输入/结果目录。
    project_root = Path(runtime["config"]["paths"]["input_dir"]).parent.as_posix()
    if not destination.startswith(project_root + "/workflow/") or "/../" in destination:
        raise ValueError("Destination must be under the project's workflow directory")
    if destination != project_root + "/workflow/" + runtime["run_id"]:
        raise ValueError("Server bundle directory must be workflow/run_id")
    data = Path(args.archive).read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    command = ["kubectl", "--context", k["context"], "--namespace", k["namespace"],
               "exec", "-i", k["shell_pod"]]
    if k.get("shell_container"):
        command += ["-c", k["shell_container"]]
    command += ["--", "runuser", "-u", k["account"], "--", "python3", "-c", RECEIVER,
                destination, k["account"], digest]
    result = subprocess.run(command, input=data, capture_output=True)
    if result.stdout:
        print(result.stdout.decode("utf-8", errors="replace"))
    if result.stderr:
        print(result.stderr.decode("utf-8", errors="replace"))
    if result.returncode:
        raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
