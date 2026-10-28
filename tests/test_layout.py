"""Layout/naming regression checks; no remote connection or biological tools."""
import importlib.util
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts/shell"))
from layout import validate_runtime_layout
import launch_stage
import start_stage

spec = importlib.util.spec_from_file_location("package_bundle", ROOT / "workflow/orchestrator/package_bundle.py")
packager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packager)


def fixture(root):
    run_id = "v2.0.0_20261027_run01"
    return {"pipeline_version": "2.0.0", "output_layout_version": "2.0", "run_id": run_id,
            "run_root": str(root / "results" / run_id), "blockers": [],
            "config": {"paths": {"output_dir": str(root / "results")},
                       "kubernetes": {"account": "fixture"}}}


class LayoutTests(unittest.TestCase):
    def test_new_layout_rejects_old_runtime_and_wrong_output_root(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            runtime = fixture(root)
            self.assertEqual(validate_runtime_layout(runtime), root / "results" / runtime["run_id"])
            for marker in (None, "1.0-review"):
                with self.assertRaisesRegex(ValueError, "original frozen code"):
                    validate_runtime_layout(dict(runtime, output_layout_version=marker))
            for path in (root / "results/runs" / runtime["run_id"], root / "other" / runtime["run_id"]):
                with self.assertRaisesRegex(ValueError, "output_dir/run_id"):
                    validate_runtime_layout(dict(runtime, run_root=str(path)))

    def test_run_names_validate_version_date_and_positive_sequence(self):
        with tempfile.TemporaryDirectory() as temp:
            base = fixture(Path(temp))
            for name in ("v1_test6_20261027_retry01", "v1.0.0_20261027_run01", "v2.0.0_20260230_run01",
                         "v2.0.0_20261027_run00", "v2.0.0_20261027_run1", "../v2.0.0_20261027_run01"):
                with self.subTest(name=name), self.assertRaises(ValueError):
                    validate_runtime_layout(dict(base, run_id=name))

    def test_packaging_requires_same_name_and_keeps_runtime_fingerprint(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            runtime = fixture(root)
            bundle = root / runtime["run_id"]
            bundle.mkdir()
            (bundle / "runtime.json").write_text(json.dumps(runtime))
            archive = root / (runtime["run_id"] + ".tar.gz")
            with self.assertRaisesRegex(ValueError, "match run_id"):
                packager.package(bundle, root / "wrong.tar.gz")
            self.assertFalse((bundle / "MANIFEST.sha256.json").exists())
            packager.package(bundle, archive)
            launch_stage.verify_bundle(bundle.resolve())
            with tarfile.open(archive) as tar:
                frozen = json.load(tar.extractfile("runtime.json"))
            self.assertEqual(frozen["run_root"], runtime["run_root"])

    def test_launcher_refuses_existing_new_stage_directories_before_spawn(self):
        for stage, directory in (("shell", "bam_count_data"), ("r", "gene_expr_data")):
            with self.subTest(stage=stage), tempfile.TemporaryDirectory() as temp:
                root = Path(temp)
                runtime = fixture(root)
                bundle = root / runtime["run_id"]
                bundle.mkdir()
                path = bundle / "runtime.json"
                path.write_text(json.dumps(runtime))
                (Path(runtime["run_root"]) / directory).mkdir(parents=True)
                with patch.object(start_stage, "verify_bundle"), patch.object(start_stage, "verify_account"), \
                     patch.object(start_stage.subprocess, "run"), patch.object(start_stage.subprocess, "Popen") as spawn, \
                     patch.object(sys, "argv", ["start_stage.py", stage, str(path), "--execute"]):
                    with self.assertRaisesRegex(ValueError, "no restart/overwrite"):
                        start_stage.main()
                    spawn.assert_not_called()


if __name__ == "__main__":
    unittest.main()
