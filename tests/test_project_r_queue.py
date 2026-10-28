"""Tests for this project's shared-storage dependency waiter; no real jobs."""
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("project_queue", ROOT / "projects/20261027_xiehe_zhou/orchestration/queue_R_after_shell.py")
queue = importlib.util.module_from_spec(spec)
spec.loader.exec_module(queue)


class QueueTests(unittest.TestCase):
    def fixture(self, root):
        bundle = root / "v2.0.0_20261028_run01"
        bundle.mkdir()
        runtime = {"run_root": str(root / "results" / bundle.name)}
        (bundle / "runtime.json").write_text(json.dumps(runtime))
        out = Path(runtime["run_root"]) / "bam_count_data"
        for folder in ("counts", "qc/multiqc", "bam"):
            (out / folder).mkdir(parents=True, exist_ok=True)
        (out.parent / "launcher").mkdir()
        (out / "runtime.json").write_bytes((bundle / "runtime.json").read_bytes())
        (out / "status.json").write_text('{"status":"succeeded"}')
        ids = ["sample" + str(i) for i in range(6)]
        (bundle / "samples.tsv").write_text("sample_id\tgroup\n" + "".join(x + "\tG\n" for x in ids))
        (out / "counts/raw_counts.tsv").write_text("gene_id\t" + "\t".join(ids) + "\ng1\t1\t1\t1\t1\t1\t1\n")
        (out / "qc/assignment_summary.tsv").write_text("sample_id\tassigned_units\n" + "".join(x + "\t1\n" for x in ids))
        (out / "qc/multiqc/multiqc_report.html").write_text("fixture")
        for sid in ids:
            (out / "bam" / sid).mkdir()
            for suffix in (".Aligned.sortedByCoord.out.bam", ".Aligned.sortedByCoord.out.bam.bai"):
                (out / "bam" / sid / (sid + suffix)).write_text("fixture")
            (out / "qc" / (sid + ".fastp.json")).write_text('{"summary":{"after_filtering":{"total_reads":10}}}')
            (out / "qc" / (sid + ".star.json")).write_text('{"Number of input reads":"5"}')
        return bundle, runtime, out

    def test_audit_rejects_mismatched_counts_or_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle, runtime, out = self.fixture(Path(tmp))
            self.assertEqual(queue.audit_shell(bundle, runtime)["genes"], 1)
            (out / "counts/raw_counts.tsv").write_text("gene_id\twrong\ng1\t1\n")
            with self.assertRaisesRegex(ValueError, "sample order"):
                queue.audit_shell(bundle, runtime)
            (out / "runtime.json").write_text("{}")
            with self.assertRaisesRegex(ValueError, "snapshot differs"):
                queue.audit_shell(bundle, runtime)

    def test_failed_shell_never_launches_r(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle, runtime, out = self.fixture(Path(tmp))
            (out / "status.json").write_text('{"status":"failed"}')
            with patch.object(queue.subprocess, "run") as launch:
                with self.assertRaisesRegex(ValueError, "Shell failed"):
                    queue.worker(bundle, runtime)
                launch.assert_not_called()
            self.assertEqual(json.loads((out.parent / "launcher/r.queue.status.json").read_text())["status"], "failed")

    def test_successful_dependency_starts_r_once_and_does_not_claim_completion(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle, runtime, out = self.fixture(Path(tmp))
            folder = out.parent / "launcher"
            def fake_launch(argv, **kwargs):
                self.assertEqual(argv[-3:], ["r", str(bundle / "runtime.json"), "--execute"])
                (folder / "r.launch.json").write_text('{"pid":456}')
                return SimpleNamespace(returncode=0, stdout="fixture", stderr="")
            with patch.object(queue, "context"), patch.object(queue.subprocess, "run", side_effect=fake_launch) as launch:
                queue.worker(bundle, runtime)
                self.assertEqual(launch.call_count, 1)
            self.assertEqual(json.loads((folder / "r.queue.status.json").read_text())["status"], "r_launched_not_completed")
            self.assertTrue((folder / "r.dependency_audit.json").exists())

    def test_timeout_does_not_launch_or_restart_jobs(self):
        with tempfile.TemporaryDirectory() as tmp:
            bundle, runtime, out = self.fixture(Path(tmp))
            (out / "status.json").unlink()
            with patch.object(queue.time, "monotonic", side_effect=[0, queue.MAX_WAIT_SECONDS + 1]), \
                 patch.object(queue.subprocess, "run") as launch:
                with self.assertRaises(TimeoutError):
                    queue.worker(bundle, runtime)
                launch.assert_not_called()


if __name__ == "__main__":
    unittest.main()
