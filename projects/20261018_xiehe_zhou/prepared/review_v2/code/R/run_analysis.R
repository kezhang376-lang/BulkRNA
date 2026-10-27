#!/usr/bin/env Rscript
# 默认仅检查，不运行。执行需第三个参数 --execute，且 runtime 无阻断项。
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 2L || !args[2] %in% c("--check-only", "--execute")) {
  stop("Usage: Rscript run_analysis.R <bundle/runtime.json> --check-only|--execute", call. = FALSE)
}
entry <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])
source(file.path(dirname(normalizePath(entry)), "common.R"))
for (name in c("qc.R", "differential_expression.R", "enrichment.R")) source(file.path(dirname(normalizePath(entry)), name))
runtime_file <- normalizePath(args[1], mustWork = TRUE)
bundle <- dirname(runtime_file)
runtime <- read_json(runtime_file)
if (length(runtime$blockers)) stopf("Prepared bundle is blocked: %s", paste(unlist(runtime$blockers), collapse = "; "))
cfg <- runtime$config
samples <- read_metadata(file.path(bundle, "samples.tsv"), "\t")
contrasts <- read_metadata(file.path(bundle, "contrasts.tsv"), "\t")
validate_metadata(samples, contrasts)
need(c("DESeq2", "edgeR", "ggplot2", "pheatmap"))
if (cfg$analysis$go_enrichment || cfg$analysis$gsea) need(c("clusterProfiler", "AnnotationDbi", "enrichplot", cfg$enrichment$orgdb))
counts_file <- if (cfg$input$type == "counts") cfg$paths$counts_file else
  file.path(runtime$run_root, "shell", "counts", "raw_counts.tsv")
counts <- read_counts(counts_file, samples)
if (nrow(samples) < 3L) stopf("v1 requires >=3 samples for QC and model checks")
# 在任何结果写入前验证过滤和模型；完整模型验证也在 DE 模块执行。
filtered <- filter_counts(counts, cfg$filtering, samples, cfg$deseq2$design)
if (any(colSums(filtered$counts) == 0)) stopf("Zero library after filtering")
formula <- as.formula(cfg$deseq2$design)
if (!all(all.vars(formula) %in% names(samples))) stopf("Missing design columns")
mm <- model.matrix(formula, samples)
if (qr(mm)$rank < ncol(mm) || nrow(mm) <= ncol(mm)) stopf("Invalid design matrix")
if (args[2] == "--check-only") {
  message("R input/package/model checks passed; no analysis performed.")
  quit(status = 0)
}
out <- file.path(runtime$run_root, "analysis")
if (!dir.create(out, recursive = TRUE, showWarnings = FALSE)) stopf("Analysis output exists or is not writable: %s", out)
write_json(list(status = "running", started = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(out, "status.json"))
log_connection <- file(file.path(out, "analysis.log"), open = "wt")
sink(log_connection, split = TRUE)
sink(log_connection, type = "message")
tryCatch({
  writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo_start.txt"))
  file.copy(runtime_file, file.path(out, "runtime.json"), overwrite = FALSE)
  write.csv(data.frame(gene_id = rownames(counts), kept = filtered$keep), file.path(out, "filtering.csv"), row.names = FALSE)
  write_matrix(filtered$counts, file.path(out, "filtered_counts.tsv"))
  if (cfg$analysis$sample_qc) run_sample_qc(counts, samples, file.path(out, "qc"))
  if (cfg$analysis$differential_expression) run_deseq2(filtered$counts, samples, contrasts, cfg$deseq2, file.path(out, "de"))
  if (cfg$analysis$go_enrichment || cfg$analysis$gsea) run_enrichment(contrasts, runtime, file.path(out, "de"), file.path(out, "enrichment"))
  writeLines(capture.output(sessionInfo()), file.path(out, "sessionInfo_end.txt"))
  write_json(list(status = "succeeded", finished = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(out, "status.json"))
}, error = function(e) {
  message("Analysis failed: ", conditionMessage(e))
  write_json(list(status = "failed", error = conditionMessage(e), finished = format(Sys.time(), tz = "UTC", usetz = TRUE)), file.path(out, "status.json"))
  stop(e)
}, finally = {
  sink(type = "message")
  sink()
  close(log_connection)
})
