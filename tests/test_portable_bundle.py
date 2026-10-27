import contextlib
import hashlib
import io
import json
import os
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/shell"))
import launch_stage
import start_stage


class PortableTests(unittest.TestCase):
    def test_manifest_rejects_changed_file_and_escape(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp).resolve()
            data = root / "runtime.json"
            data.write_text("{}")
            manifest = {"files": {"runtime.json": hashlib.sha256(data.read_bytes()).hexdigest()}}
            (root / "MANIFEST.sha256.json").write_text(json.dumps(manifest))
            launch_stage.verify_bundle(root)
            data.write_text('{"changed":true}')
            with self.assertRaisesRegex(ValueError, "checksum"):
                launch_stage.verify_bundle(root)
            manifest["files"] = {"../outside": "bad"}
            (root / "MANIFEST.sha256.json").write_text(json.dumps(manifest))
            with self.assertRaisesRegex(ValueError, "Invalid/missing"):
                launch_stage.verify_bundle(root)

    def test_explicit_environment_and_rscript(self):
        with tempfile.TemporaryDirectory() as tmp, patch.dict(os.environ, {"PATH": "/base"}):
            launch_stage.configure_environment({"environment": {"shell_path_prepend": [tmp]}}, "shell")
            self.assertEqual(os.environ["PATH"].split(os.pathsep)[0], tmp)
            with patch.object(launch_stage.shutil, "which", return_value="/usr/bin/Rscript"):
                self.assertEqual(launch_stage.configure_environment({"environment": {"rscript": "/usr/bin/Rscript"}}, "r"), "/usr/bin/Rscript")

    def test_detached_launch_lock_without_starting_a_real_process(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            runtime = root / "runtime.json"
            runtime.write_text(json.dumps({"run_root": str(root / "outputs"), "config": {"kubernetes": {"account": "fixture"}}}))
            argv = ["start_stage.py", "shell", str(runtime), "--execute"]
            with patch.object(start_stage, "verify_bundle"), patch.object(start_stage, "verify_account"), \
                    patch.object(start_stage.subprocess, "run") as preflight, \
                    patch.object(start_stage.subprocess, "Popen", return_value=SimpleNamespace(pid=12345)) as process, \
                    patch.object(sys, "argv", argv), contextlib.redirect_stdout(io.StringIO()):
                start_stage.main()
                self.assertIn("--check-only", preflight.call_args.args[0])
                self.assertTrue(process.call_args.kwargs["start_new_session"])
                with self.assertRaises(FileExistsError):
                    start_stage.main()
                self.assertEqual(process.call_count, 1)
                state = json.loads((root / "outputs/launcher/shell.launch.json").read_text())
                self.assertEqual(state["status"], "launched_not_completed")


if __name__ == "__main__":
    unittest.main()
