# 全部为本地模拟数据，不读取真实 FASTQ，不访问 Kubernetes。
args <- commandArgs(trailingOnly = TRUE)
repo <- normalizePath(if (length(args)) args[1] else ".")
source(file.path(repo, "scripts/R/common.R"))
source(file.path(repo, "scripts/R/qc.R"))
source(file.path(repo, "scripts/R/differential_expression.R"))
source(file.path(repo, "scripts/R/custom_plots.R"))
source(file.path(repo, "scripts/R/enrichment.R"))
source(file.path(repo, "workflow/orchestrator/prepare_project.R"))
need(c("yaml", "jsonlite", "DESeq2", "edgeR", "ggplot2", "pheatmap"))
expect_error <- function(expr, label) {
  got <- tryCatch({ force(expr); FALSE }, error = function(e) TRUE)
  if (!got) stopf("Expected failure: %s", label)
}
tmp <- tempfile("bulkrna_tests_")
dir.create(tmp)
verify_pod_account("zhangke", "Linux", list(uid = 1000, target_uid = 1000, user = "zhangke"))
expect_error(verify_pod_account("root", "Linux"), "root account name")
expect_error(verify_pod_account("zhangke", "Linux", list(uid = 0, target_uid = 1000, user = "root")), "root current UID")
expect_error(verify_pod_account("zhangke", "Linux", list(uid = 1000, target_uid = 0, user = "zhangke")), "root target UID")
expect_error(verify_pod_account("zhangke", "Linux", list(uid = 1001, target_uid = 1000, user = "other")), "wrong account")
samples <- data.frame(sample_id = c("A-1", "A-2", "A-3", "B.1", "B.2", "B.3"), group = rep(c("Control", "Treat"), each = 3))
contrasts <- data.frame(contrast_id = "Treat_vs_Control", treatment = "Treat", control = "Control")
# 测试夹具独立于用户持续编辑的真实项目，不能为跑测试修补用户元数据。
fixture_project <- file.path(tmp, "fixture_project")
dir.create(fixture_project)
fixture_config <- file.path(fixture_project, "config.yaml")
fixture_samples <- file.path(fixture_project, "samples.tsv")
fixture_contrasts <- file.path(fixture_project, "contrasts.tsv")
write.table(samples, fixture_samples, sep = "\t", quote = FALSE, row.names = FALSE)
write.table(contrasts, fixture_contrasts, sep = "\t", quote = FALSE, row.names = FALSE)
initial <- yaml::yaml.load(paste(readLines(file.path(repo, "config/defaults.yaml"), encoding = "UTF-8"), collapse = "\n"), eval.expr = FALSE)
initial$metadata <- list(samples = "samples.tsv", contrasts = "contrasts.tsv", delimiter = "\t")
yaml::write_yaml(initial, fixture_config)
validate_metadata(samples, contrasts)
expect_error(validate_metadata(rbind(samples, samples[1, ]), contrasts), "duplicate samples")
wrong <- contrasts; wrong$treatment <- "Missing"
expect_error(validate_metadata(samples, wrong), "unknown contrast")
set.seed(7)
counts <- matrix(rnbinom(1200 * 6, mu = 80, size = 8), ncol = 6,
                 dimnames = list(paste0("gene", seq_len(1200)), samples$sample_id))
counts[1:100, 4:6] <- counts[1:100, 4:6] * 4L
write_matrix(counts, file.path(tmp, "counts.tsv"))
shuffled <- samples[c(6, 2, 4, 1, 5, 3), ]
aligned <- read_counts(file.path(tmp, "counts.tsv"), shuffled)
stopifnot(identical(colnames(aligned), shuffled$sample_id), identical(as.numeric(aligned[, 1]), as.numeric(counts[, "B.3"])))
bad <- counts; bad[1, 1] <- -1
write_matrix(bad, file.path(tmp, "negative.tsv"))
expect_error(read_counts(file.path(tmp, "negative.tsv"), samples), "negative counts")
bad <- counts; bad[1, 1] <- 0.5
write_matrix(bad, file.path(tmp, "fraction.tsv"))
expect_error(read_counts(file.path(tmp, "fraction.tsv"), samples), "fraction counts")
stopifnot(length(filter_counts(counts, list(method = "none"), samples, "~ group")$keep) == nrow(counts))
schema <- read_json(file.path(repo, "schemas/config.schema.json"))
stopifnot(length(validate_schema(list(unknown = 1), schema)) > 0)
stopifnot(length(validate_schema("0.05", schema$properties$deseq2$properties$fdr)) > 0)
expect_error(yaml::yaml.load("key: 1\nkey: 2\n", eval.expr = FALSE), "duplicate YAML keys")
runtime <- prepare_project(fixture_config, "test_review", file.path(tmp, "blocked_bundle"), repo)
stopifnot(length(runtime$blockers) > 0L, !dir.exists(runtime$run_root))
entry_bytes <- readBin(file.path(tmp, "blocked_bundle/run_shell.sh"), what = "raw", n = 10000L)
stopifnot(!any(entry_bytes == as.raw(13)))
for (bad_mode in c("reuse", "standard_custom")) {
  changed <- runtime$config
  changed$execution$mode <- bad_mode
  yaml::write_yaml(changed, file.path(tmp, "mode.yaml"))
  changed$metadata <- list(samples = fixture_samples, contrasts = fixture_contrasts, delimiter = "\t")
  yaml::write_yaml(changed, file.path(tmp, "mode.yaml"))
  checked <- prepare_project(file.path(tmp, "mode.yaml"), paste0("mode_", bad_mode), file.path(tmp, paste0("bundle_", bad_mode)), repo)
  stopifnot(any(grepl("standard mode only", unlist(checked$blockers))))
}
expect_error(prepare_project(fixture_config, "test_review", file.path(tmp, "blocked_bundle"), repo), "bundle overwrite")
# 完整的合成配置应能通过本地配置验证；这些 /fixture 路径不进行远程验证。
good <- yaml::yaml.load(paste(readLines(file.path(repo, "config/review.example.yaml"), encoding = "UTF-8"), collapse = "\n"), eval.expr = FALSE)
good$metadata <- list(samples = fixture_samples, contrasts = fixture_contrasts, delimiter = "\t")
good$kubernetes$context <- "fixture-context"
good$kubernetes$shell_pod <- "fixture-shell"
good$kubernetes$r_pod <- "fixture-r"
good$kubernetes$account <- "zhangke"
good$paths$input_dir <- "/fixture/inputs"
good$paths$output_dir <- "/fixture/results"
good$input$strandedness <- "reverse"
good$references <- list(fasta = "/fixture/ref.fa", gtf = "/fixture/ref.gtf", star_index = "/fixture/index")
good$resources <- list(fastp_threads = 1L, star_threads = 1L, star_sort_threads = 1L, featurecounts_threads = 1L)
good$analysis$kegg_enrichment <- FALSE # 仅合成测试，不修改真实项目配置或分析范围。
good$fastp$extra_args <- list("--length_required", "30")
good_samples <- samples
good_samples$fastq_r1 <- paste0(good_samples$sample_id, "_1.fq.gz")
good_samples$fastq_r2 <- paste0(good_samples$sample_id, "_2.fq.gz")
write.table(good_samples, file.path(tmp, "good_samples.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
good$metadata$samples <- file.path(tmp, "good_samples.tsv")
yaml::write_yaml(good, file.path(tmp, "good.yaml"))
good_runtime <- prepare_project(file.path(tmp, "good.yaml"), "good_review", file.path(tmp, "good_bundle"), repo)
if (length(good_runtime$blockers)) stop(paste(unlist(good_runtime$blockers), collapse = "\n"))
good$fastp$extra_args <- list("--json", "/fixture/override.json")
yaml::write_yaml(good, file.path(tmp, "unsafe.yaml"))
bad_runtime <- prepare_project(file.path(tmp, "unsafe.yaml"), "unsafe_review", file.path(tmp, "unsafe_bundle"), repo)
stopifnot(any(grepl("Unsupported fastp extra argument", unlist(bad_runtime$blockers))))
cfg <- list(design = "~ group", fdr = 0.05, log2fc_cutoff = 1, fit_type = "mean") # 模拟测试显式方法，不更改项目配置。
expect_error(run_deseq2(counts, samples, contrasts, modifyList(cfg, list(design = "~ group * group")), file.path(tmp, "invalid_design")), "unsupported formula")
confounded <- samples; confounded$batch <- confounded$group
expect_error(run_deseq2(counts, confounded, contrasts, modifyList(cfg, list(design = "~ batch + group")), file.path(tmp, "confounded")), "rank deficiency")
run_sample_qc(counts, shuffled, file.path(tmp, "qc"))
run_deseq2(aligned, shuffled, contrasts, cfg, file.path(tmp, "de"))
result <- read.csv(file.path(tmp, "de/Treat_vs_Control/all_genes.csv"))
stopifnot(nrow(result) == nrow(counts), !anyDuplicated(result$gene_id), median(result$log2FoldChange[match(paste0("gene", 1:100), result$gene_id)]) > 0)
stopifnot(all(c("stat", "lfcSE", "padj", "pvalue", "regulated") %in% names(result)))
manifest <- list.files(file.path(tmp, "de"), recursive = TRUE)
stopifnot(all(c("dds.rds", "Treat_vs_Control/volcano.pdf", "Treat_vs_Control/ma.pdf") %in% manifest))
plot_selected_genes(log2(counts + 1), samples, "missing", file.path(tmp, "custom_empty"))
stopifnot(read_json(file.path(tmp, "custom_empty/status.json"))$status == "no_matched_genes")
plot_selected_genes(log2(counts + 1), samples, c("gene1", "missing"), file.path(tmp, "custom_single"))
expect_error(plot_selected_genes(log2(counts + 1), samples, "gene1", file.path(tmp, "custom_single")), "custom overwrite")
if (requireNamespace("org.Mm.eg.db", quietly = TRUE) && requireNamespace("clusterProfiler", quietly = TRUE)) {
  # 不匹配的合成 ID 必须成为可解释空状态，而不是静默删改 ID。
  run_enrichment(contrasts, list(config = list(analysis = list(gsea = TRUE, go_enrichment = TRUE),
      enrichment = list(orgdb = "org.Mm.eg.db", key_type = "ENSEMBL"))), file.path(tmp, "de"), file.path(tmp, "enrichment_empty"))
  stopifnot(read_json(file.path(tmp, "enrichment_empty/Treat_vs_Control/status.json"))$status == "no_mapped_genes")
}
# 用独立子进程验证 R 入口 check-only 不写结果、execute 完成、重复执行拒绝。
cli_bundle <- file.path(tmp, "cli_bundle")
dir.create(cli_bundle)
write.table(samples, file.path(cli_bundle, "samples.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
write.table(contrasts, file.path(cli_bundle, "contrasts.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
cli <- list(run_root = file.path(tmp, "cli_run"), blockers = list(), config = list(
  input = list(type = "counts"), paths = list(counts_file = file.path(tmp, "counts.tsv")),
  filtering = list(method = "none"), deseq2 = cfg,
  analysis = list(sample_qc = TRUE, differential_expression = TRUE, go_enrichment = FALSE, gsea = FALSE)))
write_json(cli, file.path(cli_bundle, "runtime.json"))
run_cli <- function(mode) {
  output <- suppressWarnings(system2(file.path(R.home("bin"), "Rscript"),
    c("--vanilla", shQuote(file.path(repo, "scripts/R/run_analysis.R")), shQuote(file.path(cli_bundle, "runtime.json")), mode), stdout = TRUE, stderr = TRUE))
  list(code = if (is.null(attr(output, "status"))) 0L else attr(output, "status"), output = output)
}
checked <- run_cli("--check-only")
if (checked$code != 0) stop(paste(checked$output, collapse = "\n"))
stopifnot(!dir.exists(cli$run_root))
executed <- run_cli("--execute")
if (executed$code != 0) stop(paste(executed$output, collapse = "\n"))
stopifnot(read_json(file.path(cli$run_root, "analysis/status.json"))$status == "succeeded")
stopifnot(run_cli("--execute")$code != 0)
cat("PASS: metadata/count/schema/blocked-bundle/mode/LF/design/QC/DE/custom/empty-enrichment/R-entry synthetic checks\n")
cat("Temporary outputs:", tmp, "\n")
