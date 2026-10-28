# BulkRNA portable project bundle

Pipeline: 2.0.0
Output layout: 2.0
Project: xiehe_zhouyisheng_20261027
Run: v2.0.0_20261028_run01
Results root: /home/zhangke/RNA-seq/20261028_xiehe_zhou/results/v2.0.0_20261028_run01

This folder is self-contained. Copy/extract it as a whole; do not edit its frozen files. No Windows R/Python or repository checkout is required on the Pods.
Required Linux account: zhangke
Python3 is required on both Pods. Root/wrong-account execution is rejected. Switch account before calling the entrypoints.

## Stage 1: Shell Pod
```bash
cd /absolute/path/to/this/bundle
bash run_shell.sh --check-only
# Only after launch authorization:
bash run_shell.sh --execute
```
The launcher uses configured environment.shell_path_prepend. fastp uses the legacy config's pinned executable, not the PATH version.

## Stage 2: R Pod (same shared bundle and result paths)
```bash
cd /absolute/path/to/this/bundle
bash run_R.sh --environment-only
# After Shell succeeds and counts exist:
bash run_R.sh --check-only
# Only after launch authorization:
bash run_R.sh --execute
```

Run stages sequentially on their designated Pods. The package does not create or modify Pods, switch identities, transfer large files, or restart partial runs.
Existing stage output directories are rejected. If a stage fails, inspect logs/status; do not delete outputs and retry blindly. No fingerprint resume is implemented.
For long, authorized runs, use bash start_shell.sh --execute on the Shell Pod, then bash start_R.sh --execute on the R Pod AFTER Shell succeeds. These launch detached processes and write per-stage locks/PID/logs under results_root/launcher; launch success does not mean completion. Do not call them before authorization.

## Outputs
bam_count_data/clean, bam_count_data/bam, bam_count_data/counts/raw_counts.tsv, bam_count_data/qc, bam_count_data/logs, bam_count_data/status.json
gene_expr_data/qc, gene_expr_data/gene_diff_expr, gene_expr_data/enrichment, gene_expr_data/report.html, gene_expr_data/analysis.log, gene_expr_data/status.json

All outputs are under output_dir/run_id, without an extra runs directory. Bundle directory name must equal run_id.

## Validation
validation/ contains separate small-data compatibility checks. They require a NEW validation directory and do not run the full six-sample analysis.

## Scope
PE fastp/STAR/featureCounts, sample QC, pairwise DESeq2 Wald, GO ORA/GSEA, optional MultiQC. KEGG, LRT, WGCNA, mode B/C orchestration and resume are not included.

MANIFEST.sha256.json verifies package contents before launch; changing any frozen file requires generating a new package.
