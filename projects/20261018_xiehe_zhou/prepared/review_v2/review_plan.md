# Generated review plan

Run: review_v2
Status: BLOCKED

## Module intent
- fastp: TRUE
- star: TRUE
- featurecounts: TRUE
- sample_qc: TRUE
- differential_expression: TRUE
- go_enrichment: TRUE
- kegg_enrichment: TRUE
- gsea: TRUE
- custom_analysis: FALSE

## Blockers
- config: missing schema_version
- config: missing metadata
- config: missing filtering
- config: missing resources
- config: missing references
- config: missing fastp
- config: missing featurecounts
- config.kubernetes: missing context
- config.input: missing strandedness
- config.deseq2: missing fit_type
- v1 has no fingerprint-verified resume; set resume=false only for an agreed fresh run
- KEGG module not implemented in v1; do not silently disable an intended analysis
- Missing enrichment settings
- Missing actual kubernetes shell_pod
- Missing actual kubernetes r_pod
- Missing actual kubernetes context
- Placeholder paths input_dir
- Placeholder paths output_dir
- Library strandedness is unknown
- samples missing fastq_r1/fastq_r2; filenames must not be guessed
- Missing absolute references fasta
- Missing absolute references gtf
- Missing absolute references star_index

## Notes
- Prepared locally only. No Kubernetes check, upload, or analysis executed.
- Remote storage, capacity, reference identity and scientific design still require review.
- Formal execution requires separate user authorization; launchers default to check-only.
- project.id differs from project folder; verify intended project identity
