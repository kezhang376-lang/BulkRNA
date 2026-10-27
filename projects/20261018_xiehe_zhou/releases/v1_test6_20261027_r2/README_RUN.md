# BulkRNA V1 portable project bundle

Project: xiehe_zhouyisheng_20261018
Run: v1_test6_20261027_r2
Results root: /home/zhangke/RNA-seq/20261027_xiehe_zhou/results/runs/v1_test6_20261027_r2

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
shell/clean, shell/bam, shell/counts/raw_counts.tsv, shell/qc, shell/logs, shell/status.json
analysis/qc, analysis/de, analysis/enrichment, analysis/report.html, analysis/analysis.log, analysis/status.json

All outputs are under the results root above, not the bundle folder.

## Validation
validation/ contains separate small-data compatibility checks. They require a NEW validation directory and do not run the full six-sample analysis.

## Scope
PE fastp/STAR/featureCounts, sample QC, pairwise DESeq2 Wald, GO ORA/GSEA, optional MultiQC. KEGG, LRT, WGCNA, mode B/C orchestration and resume are not included.

MANIFEST.sha256.json verifies package contents before launch; changing any frozen file requires generating a new package.
