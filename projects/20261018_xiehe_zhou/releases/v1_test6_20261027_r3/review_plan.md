# Generated review plan

Run: v1_test6_20261027_r3
Status: LOCAL_CONFIG_VALID_NOT_AUTHORIZED

## Module intent
- fastp: TRUE
- star: TRUE
- featurecounts: TRUE
- sample_qc: TRUE
- differential_expression: TRUE
- go_enrichment: TRUE
- kegg_enrichment: FALSE
- gsea: TRUE
- custom_analysis: FALSE
- multiqc: TRUE

## Blockers
- No local config blockers; remote preflight and scientific review remain.

## Notes
- Prepared locally only. No Kubernetes check, upload, or analysis executed.
- Remote storage, capacity, reference identity and scientific design still require review.
- Formal execution requires separate user authorization; launchers default to check-only.
- Pod Linux account must be zhangke; switch identity before launching. Workers reject root/wrong UID; no automatic account switching is implemented.
- project.id differs from project folder; verify intended project identity
- fastp.extra_args is a legacy parameter file; the worker reads its specified binary and options without shell evaluation. File/version validation occurs on the Pod.
