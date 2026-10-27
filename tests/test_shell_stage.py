"""Synthetic parser/guard tests; never execute biological software or kubectl."""
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("shell_stage", ROOT / "scripts/shell/shell_stage.py")
STAGE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(STAGE)


class ShellTests(unittest.TestCase):
    def legacy_fixture(self, folder):
        binary = folder / "fastp"
        binary.write_text("fixture executable")
        binary.chmod(0o700)
        path = folder / "Illumina_fastp.config"
        path.write_text(f"fastp {binary}\nadapter_sequence AGATCGGAAGAGCACACGTCTGAACTCCAGTCA\nadapter_sequence_r2 AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT\ntrim_front1 0\ntrim_front2 0\nqualified_quality_phred 20\nunqualified_percent_limit 30\naverage_qual 20\nlength_required 20\n")
        cfg = {"fastp": {"extra_args": str(path), "expected_version": "0.21.0"}}
        return cfg, path, binary

    def test_legacy_fastp_file_preserves_binary_and_all_parameters(self):
        with tempfile.TemporaryDirectory() as folder:
            cfg, path, binary = self.legacy_fixture(Path(folder))
            spec = STAGE.resolve_fastp(cfg)
            self.assertEqual(spec["executable"], str(binary))
            self.assertEqual(spec["_source_bytes"], path.read_bytes())
            for key in ("trim_front1", "trim_front2", "average_qual", "length_required", "adapter_sequence", "adapter_sequence_r2"):
                self.assertIn("--" + key, spec["args"])
            self.assertEqual(spec["args"][spec["args"].index("--average_qual") + 1], "20")
            self.assertEqual(spec["expected_version"], "0.21.0")

    def test_legacy_fastp_rejects_unknown_and_duplicate_keys(self):
        with tempfile.TemporaryDirectory() as folder:
            cfg, path, binary = self.legacy_fixture(Path(folder))
            original = path.read_text()
            for extra in ("average_qual 10\n", "json /tmp/override.json\n"):
                path.write_text(original + extra)
                with self.assertRaises(ValueError):
                    STAGE.resolve_fastp(cfg)

    def test_wrong_fastp_version_is_not_accepted(self):
        with tempfile.TemporaryDirectory() as folder:
            cfg, path, binary = self.legacy_fixture(Path(folder))
            cfg.update(input={"type": "fastq"}, analysis={"fastp": True, "star": True, "featurecounts": True})
            proc = SimpleNamespace(stdout="fastp 0.23.4", stderr="", returncode=0)
            with patch.object(STAGE, "verify_account"), patch.object(STAGE.shutil, "which", return_value=str(binary)), patch.object(STAGE.subprocess, "run", return_value=proc) as mock:
                with self.assertRaisesRegex(ValueError, "differs from expected 0.21.0"):
                    STAGE.preflight({"config": cfg, "blockers": []}, [])
                self.assertEqual(mock.call_args.args[0][0], str(binary))

    def test_nonroot_account_guard(self):
        cfg = {"kubernetes": {"account": "zhangke"}}
        fake_pwd = SimpleNamespace(getpwnam=lambda name: SimpleNamespace(pw_uid=1000),
                                   getpwuid=lambda uid: SimpleNamespace(pw_name="zhangke"))
        with patch.object(STAGE.sys, "platform", "linux"), patch.dict(sys.modules, {"pwd": fake_pwd}):
            with patch.object(STAGE.os, "geteuid", return_value=1000, create=True):
                STAGE.verify_account(cfg)
            with patch.object(STAGE.os, "geteuid", return_value=0, create=True):
                with self.assertRaisesRegex(ValueError, "Root execution"):
                    STAGE.verify_account(cfg)
            with patch.object(STAGE.os, "geteuid", return_value=1001, create=True):
                with self.assertRaisesRegex(ValueError, "Wrong Pod account"):
                    STAGE.verify_account(cfg)
            fake_pwd.getpwnam = lambda name: SimpleNamespace(pw_uid=0)
            with patch.object(STAGE.os, "geteuid", return_value=1000, create=True):
                with self.assertRaisesRegex(ValueError, "Root execution"):
                    STAGE.verify_account(cfg)
        for name in (None, "root", "zhangke;id"):
            with self.assertRaisesRegex(ValueError, "non-root Linux account"):
                STAGE.verify_account({"kubernetes": {"account": name}})

    def test_full_stage_with_fake_tools_and_no_overwrite(self):
        # 夹具模拟工具接口，只验证调度/验收，不宣称验证实际生物软件。
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)
            ref = p / "ref"
            ref.mkdir()
            for filename in ("Genome", "SA", "SAindex", "genomeParameters.txt", "ref.fa", "ref.gtf"):
                (ref / filename).write_text("fixture")
            for filename in ("R1.fq.gz", "R2.fq.gz"):
                (p / filename).write_text("fixture")
            (p / "samples.tsv").write_text("sample_id\tgroup\tfastq_r1\tfastq_r2\nA-1\tControl\tR1.fq.gz\tR2.fq.gz\n")
            cfg = {"input": {"type": "fastq", "strandedness": "reverse"},
                   "analysis": {"fastp": True, "star": True, "featurecounts": True},
                   "references": {"fasta": str(ref / "ref.fa"), "gtf": str(ref / "ref.gtf"), "star_index": str(ref)},
                   "paths": {"input_dir": str(p)}, "fastp": {"extra_args": []},
                   "resources": {"fastp_threads": 1, "star_threads": 1, "star_sort_threads": 1, "featurecounts_threads": 1},
                   "featurecounts": {"feature_type": "exon", "gene_attribute": "gene_id"}}
            runtime = {"config": cfg, "blockers": [], "run_root": str(p / "results")}
            (p / "runtime.json").write_text(json.dumps(runtime))
            calls = []

            def fake_command(argv, logfile, commands_file):
                argv = list(map(str, argv))
                calls.append(argv)
                if argv[0] == "fastp":
                    for flag in ("-o", "-O"):
                        Path(argv[argv.index(flag) + 1]).write_text("clean fixture")
                    summary = {"total_reads": 10, "q30_rate": 0.95}
                    Path(argv[argv.index("--json") + 1]).write_text(json.dumps({"summary": {"before_filtering": summary, "after_filtering": summary}}))
                elif argv[0] == "STAR":
                    prefix = argv[argv.index("--outFileNamePrefix") + 1]
                    Path(prefix + "Aligned.sortedByCoord.out.bam").write_text("bam fixture")
                    Path(prefix + "Log.final.out").write_text("Number of input reads | 5\nUniquely mapped reads number | 5\nUniquely mapped reads % | 100%\n")
                elif argv[0] == "featureCounts":
                    out = Path(argv[argv.index("-o") + 1])
                    bam = argv[-1]
                    out.write_text("Geneid\tChr\tStart\tEnd\tStrand\tLength\t" + bam + "\ng1\t1\t1\t2\t+\t2\t5\n")
                    Path(str(out) + ".summary").write_text("Status\t" + bam + "\nAssigned\t5\n")

            class Proc:
                stdout = "fixture --countReadPairs"
                stderr = ""

            with patch.object(STAGE, "verify_account"), patch.object(STAGE.shutil, "which", return_value="/fake/tool"), patch.object(STAGE.subprocess, "run", return_value=Proc()), patch.object(STAGE, "command", side_effect=fake_command):
                STAGE.run(p / "runtime.json", execute=False)
                self.assertFalse((p / "results").exists())
                STAGE.run(p / "runtime.json", execute=True)
                status = p / "results/shell/status.json"
                self.assertEqual(json.loads(status.read_text())["status"], "succeeded")
                fc = next(call for call in calls if call[0] == "featureCounts")
                self.assertIn("--countReadPairs", fc)
                self.assertEqual(fc[fc.index("-s") + 1], "2")
                count_file = p / "results/shell/counts/raw_counts.tsv"
                before = count_file.read_bytes()
                with self.assertRaises(FileExistsError):
                    STAGE.run(p / "runtime.json", execute=True)
                self.assertEqual(before, count_file.read_bytes())

    def test_exact_sample_identity_and_units(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)
            bams = ["/run/bam/A-1.bam", "/run/bam/B.2.bam"]
            source = p / "fc.txt"
            source.write_text("#featureCounts\nGeneid\tChr\tStart\tEnd\tStrand\tLength\t" + "\t".join(bams) +
                              "\ng1\t1\t1\t2\t+\t2\t3\t4\ng2\t1\t3\t4\t+\t2\t5\t6\n")
            summary = p / "fc.summary"
            summary.write_text("Status\t" + "\t".join(bams) + "\nAssigned\t8\t10\nUnassigned_NoFeatures\t2\t0\n")
            STAGE.featurecounts_to_matrix(source, bams, ["A-1", "B.2"], p / "counts.tsv", summary, p / "qc.tsv")
            self.assertEqual((p / "counts.tsv").read_text().splitlines()[0], "gene_id\tA-1\tB.2")
            self.assertIn("A-1\t10\t8\t0.8", (p / "qc.tsv").read_text())
            with self.assertRaises(ValueError):
                STAGE.featurecounts_to_matrix(source, list(reversed(bams)), ["A-1", "B.2"], p / "bad.tsv", summary, p / "badqc.tsv")

    def test_blocked_bundle_does_not_create_results(self):
        with tempfile.TemporaryDirectory() as folder:
            p = Path(folder)
            (p / "samples.tsv").write_text("sample_id\tgroup\nA\tControl\n")
            (p / "runtime.json").write_text(json.dumps({"config": {}, "blockers": ["missing FASTQ"], "run_root": str(p / "results")}))
            with self.assertRaisesRegex(ValueError, "blocked"):
                STAGE.run(p / "runtime.json", execute=True)
            self.assertFalse((p / "results").exists())

    def test_star_fields_are_not_line_number_dependent(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "Log.final.out"
            path.write_text("Extra field | x\nUniquely mapped reads % | 75.00%\n\nNumber of input reads | 100\nUniquely mapped reads number | 75\n")
            self.assertEqual(STAGE.parse_star(path)["Number of input reads"], "100")


if __name__ == "__main__":
    unittest.main()
